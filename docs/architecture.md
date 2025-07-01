<!-- docs/architecture.md -->

# Architecture Overview

> **Note**
> For *initial infrastructure setup and deployment orchestration*.automation 
> resides in a single Jenkins pipeline* (`jenkins/Jenkinsfile`)
> **GitHub Actions** is used for CI/CD workflows and leverages self-hosted runners 
> managed by the Actions Runner Controller (ARC).
> We use two Terraform projects to avoid circular dependencies during the jenkins execution
> one for the EKS and rest for addons.
---

## 1 High-Level Flow

1.  Developer pushes to Git ➜ **GitHub Actions workflow starts on a self-hosted runner**
2.  **GitHub Actions workflow stages**: **lint → test → Docker build/push → Deploy (Helm)**
    * **Initial Infrastructure Provisioning**: A separate **Jenkins pipeline** manages the 
    provisioning and updates of the core infrastructure (EKS, ECR, ARC deployment).
3.  **Terraform** (managed by Jenkins) provisions or updates
    * Amazon ECR (immutable tags)
    * Amazon EKS (cluster, node group, OIDC, etc.)
    * **Actions Runner Controller (ARC) deployment and associated resources**
    * AWS Load Balancer Controller via Helm + IRSA
4.  App Image is pushed to **ECR** with a unique immutable tag (by GitHub Actions)
5.  `helm upgrade --install --atomic --wait` deploys to EKS (by GitHub Actions)
6.  ALB Controller reconciles `Ingress`, creating an ALB
7.  End-users reach the service through `sample-app.example.com`

---


## 2 Security Considerations

| Area | Approach | Rationale |
|------|----------|-----------|
| **AWS credentials (Jenkins)** | Jenkins assumes `TerraformDeploymentRole` via STS (`AWS_PROFILE=terraform-assume-role`) for infra provisioning. | No long-lived keys on disk for infra. |
| **AWS credentials (GitHub Actions)** | **OpenID Connect (OIDC)** configured for GitHub Actions ➜ Self-hosted runners assume specific IAM roles for AWS interactions (e.g., ECR push, EKS deploy). | Least privilege, no long-lived keys in GitHub. |
| **Cluster access** | `enable_cluster_creator_admin_permissions = true` (EKS module) for Jenkins' initial provisioning role. **ARC runners interact with EKS via OIDC-assumed roles**. | Only provisioning role becomes cluster-admin initially. Runners use specific, scoped permissions. |
| **IRSA** | ALB controller SA annotated with a dedicated IAM role limited to `AWSLoadBalancerControllerIAMPolicy`. | Least-privilege controller permissions. |
| **Secrets** | **Demo uses GitHub repository secrets injected into a Kubernetes `Secret` via Helm; production could also mount from AWS Secrets Manager via Secrets Store CSI Driver.** | Encryption, rotation, IAM-level audit trail, separation of concerns. |


---

## 3  Container Image Strategy

* **Immutable ECR tags** (`imageTagMutability = IMMUTABLE`).  
* Tag format: `<BUILD_NUM>-<UTC_YYYYmmddHHMMSS>` (e.g. `78-20250617133526`).  
* Enables deterministic rollbacks and easy promotion by tag copy.
* **Custom ARC Runner Image**: The `summerwind/actions-runner` base image is extended via a Dockerfile to include necessary tools like AWS CLI, Helm, Node.js, and yamllint. This custom image is pushed to ECR and used by the `RunnerDeployment`.


---

## 4  Infrastructure as Code

### 4.1  Terraform Layout
terraform/
├── backend.tf
├── dev.tfvars
├── main.tf              
├── variables.tf
└── modules/
    ├── ecr/
    ├── eks/

terraform-addons/
├── backend.tf
├── dev.tfvars
├── main.tf              
├── variables.tf
└── modules/
    └── aws_lb_controller/

* Remote state: S3 bucket `devops-terraform-state-pabloperez`  
  (we'd add a DynamoDB lock table in team environments).

### 4.2 Module Responsibilities

| Root Configuration | Module | Responsibility |
|--------------------|--------|----------------|
| `terraform/`       | **ecr** | ECR Repository, lifecycle policy (expire untagged > 30 d) |
| `terraform/`       | **eks** | EKS Cluster, managed node group, OIDC, node SGs |
| `terraform/`       | **arc_runner_controller** | Deployment of the Actions Runner Controller, `RunnerDeployment` for custom runners, and associated IAM roles for OIDC. |
| `terraform-addons/`| **aws_lb_controller** | Helm deployment of the AWS Load Balancer Controller, IRSA role, policy |

---

## 5  Jenkins Pipeline (Helm-First)

* Declarative pipeline (`jenkins/Jenkinsfile`), replayable end-to-end.
* Key stages: lint → unit-test → **Terraform (for infra, including ARC deployment if done via Terraform)**.
* Parameter `DESTROY=true` fully tears down Terraform stack.

### Shared Library Design

The pipeline uses a Jenkins Shared Library defined in `shared-lib/vars/` to separate key CI/CD logic 
into reusable steps.

Each core stage (e.g., Docker build, Terraform apply,...) is implemented as a Groovy script. 
This helps maintain a clean Jenkinsfile and enables better reuse across pipelines.

In production scenarios, the shared library would likely be extracted into a standalone Git repository 
and versioned independently.

---

## 6  Ingress & AWS Load Balancer Controller

* Ingress is templated in the Helm chart (`templates/ingress.yaml`).  
* Listen-ports annotation must be JSON and therefore quoted:  
  `alb.ingress.kubernetes.io/listen-ports: "[{\"HTTP\":80}]"`.

---

## 7  Integrating in an Existing Organisation

1. **State isolation**: one remote state bucket per env (dev / staging / prod).  
2. **Account separation**: production EKS in its own AWS account; Jenkins
   assumes a distinct role for prod.  
3. **Git branching / promotion**: PR merge ➜ dev; tag ➜ staging; signed tag ➜ prod.  
4. **Observability**: enable Container Insights and ship ALB + pod metrics
   to Prometheus / Grafana.  
5. **Policy as code**: Gatekeeper or Kyverno to block unsafe manifests
   (e.g. wild-card `Ingress`, `latest` images).

---

## 8  Long-Term Maintenance

| Topic | Recommendation |
|-------|----------------|
| **EKS upgrades** | Pin `cluster_version`; automate minor upgrades quarterly using blue/green node groups. |
| **Cost control** | Enable Compute Optimizer; schedule idle ALB cleanup. |
| **Back-ups** | Versioned state files + ECR scan reports to Glacier. |
| **Security reviews** | Run `tfsec` / `kics` in PRs; rotate role trust annually. |
| **Disaster recovery** | Re-provision from state + Helm; pull images from ECR (immutable). |

---

## TLS and Production Traffic

The demo exposes the application on **HTTP :80** for speed of testing.  
In production:

* Use **AWS Certificate Manager (ACM)** to provision a certificate.
* ALB listeners: `443` (HTTPS, default) and `80` → `443` redirect.
* Automate certificate attachment either directly in the Ingress
  annotations or via cert-manager if self-managed certificates are
  preferred.
* Point your DNS record (Route 53) to the ALB hostname.

This satisfies modern security requirements while keeping operational
overhead low.

---

## Helm Secret Management

The application Helm chart includes a **Kubernetes Secret template** (e.g., `templates/secret.yaml`) that defines the structure for injecting sensitive data like the database password into the runtime environment. The actual sensitive values are *not* stored in the Git repository.

Instead, at deployment time, the database password (for the demo) is securely passed from **GitHub Actions' encrypted repository secrets** (`${{ secrets.DB_PASS_SECRET }}`). This value is then injected into the Kubernetes Secret template via a Helm argument (e.g., `--set secret.DB_PASSWORD=...`). Helm subsequently *creates or updates* this Kubernetes Secret in the cluster. The application pods then consume this Kubernetes Secret, typically via environment variables or mounted files, to access the password at runtime.

For production, the recommended approach is to leverage OIDC-assumed roles within GitHub Actions to fetch secrets dynamically from AWS Secrets Manager, which are then mounted into application pods using the Secrets Store CSI Driver. This ensures secrets are never hardcoded or passed directly through the CI/CD pipeline, and are managed with robust encryption, rotation, and IAM-level audit trails.

---

