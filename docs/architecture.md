<!-- docs/architecture.md -->

# Architecture Overview

> **Note**  
> For demonstration purposes *all automation resides in a single Jenkins
> pipeline* (`jenkins/Jenkinsfile`).  
> In production I would separate concerns—infra, CI, and CD—into distinct
> repositories and pipelines(either multibranch pipeline or different 
> standalone pipelines), adopt GitOps (Argo CD / Flux) for release
> management, and handle secrets exclusively with AWS Secrets Manager.

---

## 1  High-Level Flow

1. Developer pushes to Git ➜ Jenkins job starts  
2. Jenkins stages: **lint → test → Docker build/push → Terraform → Helm**  
3. **Terraform** provisions or updates  
   - Amazon ECR (immutable tags)  
   - Amazon EKS (cluster, node group, OIDC, etc.)  
   - AWS Load Balancer Controller via Helm + IRSA  
4. Image is pushed to **ECR** with a unique immutable tag  
5. `helm upgrade --install --atomic --wait` deploys to EKS  
6. ALB Controller reconciles `Ingress`, creating a public ALB  
7. End-users reach the service through `sample-app.example.com`

---

## 2  Security Considerations

| Area | Approach | Rationale |
|------|----------|-----------|
| **AWS credentials** | Jenkins assumes `TerraformDeploymentRole` via STS (`AWS_PROFILE=terraform-assume-role`). | No long-lived keys on disk. |
| **Cluster access** | `enable_cluster_creator_admin_permissions = true` (EKS module). | Only the provisioning role becomes cluster-admin. |
| **IRSA** | ALB controller SA annotated with a dedicated IAM role limited to `AWSLoadBalancerControllerIAMPolicy`. | Least-privilege controller permissions. |
| **Secrets** | Demo uses a Kubernetes `Secret`; production should mount from AWS Secrets Manager via Secrets Store CSI Driver. | Encryption, rotation, IAM-level audit trail. |

---

## 3  Container Image Strategy

* **Immutable ECR tags** (`imageTagMutability = IMMUTABLE`).  
* Tag format: `<BUILD_NUM>-<UTC_YYYYmmddHHMMSS>` (e.g. `78-20250617133526`).  
* Enables deterministic rollbacks and easy promotion by tag copy.

---

## 4  Infrastructure as Code

### 4.1  Terraform Layout
terraform/
├── backend.tf
├── dev.tfvars
├── main.tf              # root module
├── variables.tf
└── modules/
├── ecr/
├── eks/
└── aws_lb_controller/

* Remote state: S3 bucket `devops-terraform-state-pabloperez`  
  (add a DynamoDB lock table in team environments).

### 4.2  Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| **ecr** | Repository, lifecycle policy (expire untagged > 30 d) |
| **eks** | Cluster, managed node group, OIDC, node SGs |
| **aws_lb_controller** | Helm release, IRSA role, policy |

---

## 5  Jenkins Pipeline (Helm-First)

* Declarative pipeline (`jenkins/Jenkinsfile`), replayable end-to-end.  
* Key stages: lint → unit-test → Docker → Terraform → Helm.  
* `helm upgrade --install … --atomic --wait --timeout 5m` ensures an
  all-or-nothing deployment.  
* Parameter `DESTROY=true` fully tears down both Helm release and
  Terraform stack.

### Shared Library Design

The pipeline uses a Jenkins Shared Library defined in `shared-lib/vars/` to separate key CI/CD logic 
into reusable steps.

Each core stage (e.g., Docker build, Terraform apply, Helm deploy) is implemented as a Groovy script. 
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
