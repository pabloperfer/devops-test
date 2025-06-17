Note: In this demo, all automation is centralized in a single Jenkins pipeline defined in [jenkins/Jenkinsfile].
This design choice was made deliberately for illustration and ease of evaluation.

In a real-world setup, I would recommend:
	•	Separate pipelines and repositories for infrastructure (Terraform) and application delivery (CI/CD).
	•	Use of GitOps tools (e.g., Argo CD or Flux) to manage Kubernetes manifests and Helm releases declaratively.
	•	Image build and chart publishing done by CI, while CD is triggered by image/tag updates—not by direct Helm install from Jenkins.
	•	Secrets handled by AWS Secrets Manager via the Secrets Store CSI Driver, not hardcoded or passed via Kubernetes Secret manifests.


# Architecture Overview


## 1. High-Level Flow

1. **Developer push** → Git repository  
2. **Jenkins** checkout → run pipeline (Build, Test, Terraform, Helm)  
3. **Terraform**  
   - Creates / updates **ECR** repository  
   - Provisions **EKS** cluster, node group, OIDC provider, etc.  
   - Deploys **AWS Load Balancer Controller** (Helm) with IRSA  
4. **Docker** image built → pushed to **ECR** with immutable tag  
5. **Helm upgrade --install** chart → EKS (`--atomic --wait`)  
6. **ALB Controller** reconciles `Ingress` → creates public ALB  
7. User reaches the service through `sample-app.example.com`

---

## 2. Security Considerations

| Area | Approach | Rationale |
|------|----------|-----------|
| **AWS credentials** | Jenkins assumes the **`TerraformDeploymentRole`** via STS (`AWS_PROFILE=terraform-assume-role`). | No long-lived keys stored on disk or in Jenkins. |
| **Cluster access** | `enable_cluster_creator_admin_permissions = true` (Terraform EKS module) grants cluster-admin only to the role that created the cluster. | Narrowest possible admin surface. |
| **IRSA** | The ALB controller service-account is annotated with the ARN of an IAM role that has the minimum policies required (`AWSLoadBalancerControllerIAMPolicy`). | Follows AWS best practice for controller permissions. |
| **Secrets** | Demo uses a Kubernetes `Secret`; production should mount secrets from **AWS Secrets Manager** via the **Secrets Store CSI Driver**. | Encryption at rest, rotation, fine-grained IAM control. |

---

## 3. Container Image Strategy

* **Immutable tags** in ECR (`imageTagMutability = IMMUTABLE`).  
* Tag format:  <build_num>-<UTC_YYYYmmddHHMMSS>
* Enables deterministic rollbacks and easy promotion (e.g. “copy tag to prod”).

---

## 4. Infrastructure as Code

### 4.1 Terraform Layout
terraform/
├── main.tf          # Root module: calls ECR, EKS, ALB-controller modules
├── variables.tf
├── backend.tf
├── dev.tfvars       # Env-specific overrides
└── modules/
    ├── ecr/
    ├── eks/
    └── aws_lb_controller/

    * **Remote state** → S3 bucket `devops-terraform-state-pabloperez` (+ versioning).  
* (Optional) add DynamoDB lock table for concurrency in team CI.

### 4.2 Modules
| Module | Responsibility |
|--------|----------------|
| **ecr** | Repository + lifecycle (expire untagged > 30 d) |
| **eks** | Cluster, managed node group, OIDC, node SGs |
| **aws_lb_controller** | Helm release + IRSA role + policy |

---

## 5. Jenkins Pipeline (Helm-first)

* Declarative; single source of truth in **`jenkins/Jenkinsfile`**.  
* Key stages: lint → unit-test → Docker build/push → Terraform → Helm.  
* **`helm upgrade --install … --atomic --wait --timeout 5m`** guarantees
  all-or-nothing deploys; a failed rollout auto-rolls back.  
* **`DESTROY=true`** parameter fully tears down Helm release + Terraform.

---

## 6. Ingress & ALB Controller

* Ingress manifest lives in the Helm chart (`templates/ingress.yaml`).  
* Annotation **`alb.ingress.kubernetes.io/listen-ports: "[{\"HTTP\":80}]"`** is JSON (must be quoted).  

## 7. Operating in an Existing Organisation

1. **State isolation** – use a separate S3 state bucket per environment (dev / staging / prod).  
2. **Account separation** – prod EKS lives in a dedicated AWS account; Jenkins assumes a *different* role for prod.  
3. **Git branching** – `main` → dev; PR merge with tag triggers promotion to staging/prod via separate pipeline.  
4. **Observability** – enable CloudWatch Container Insights; export ALB and pod metrics to Prometheus/Grafana.  
5. **Policy as code** – use OPA Gatekeeper (or Kyverno) to prevent un-scoped `Ingress`, `LoadBalancer` services, etc.  

---

## 8. Long-Term Maintenance Notes

* **EKS Upgrades** – Terraform variable `cluster_version` pinned; automate minor upgrades quarterly with blue/green node groups.  
* **Cost control** – enable AWS Compute Optimizer & Rightsizing; idle ALB cleanup job.  
* **Backups** – store daily state file versions + ECR scan reports in Glacier.  
* **Security reviews** – rotate `TerraformDeploymentRole` trust relationships yearly; run `tfsec`/`kics` in PR checks.  
* **Disaster recovery** – recreate cluster from state + Helm chart; images pulled from ECR (immutable).

---

