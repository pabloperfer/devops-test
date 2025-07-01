# DevOps‑Test — End‑to‑End Run Book

This repository demonstrates a complete delivery workflow for a small Node.js
service.

* **Cloud path** – deploy the same service to AWS.
    * **Infrastructure provisioning** is orchestrated by a Jenkins pipeline using **Terraform**.
    * **Application CI/CD** (build, test, deploy) is managed by GitHub Actions, running on self-hosted runners in EKS (via Actions Runner Controller - ARC).

  
---
## 1 Local deployment with minikube (optional)

Skip this section if you only need the AWS/Jenkins flow.

### 1.1 Requirements

| Tool      | Tested version                                 |
|-----------|-------------------------------------------------|
| Docker    | 24.x                                            |
| minikube  | ≥ 1.30                                         |
| kubectl   | 1.29                                            |
| Helm      | ≥ 3.14                                          |

### 1.2 Steps

1. **Start a local cluster** (if you don’t have one already):

   minikube start --driver=docker

2. **Run the helper script** – it will:
   - build the Docker image  
   - load it into minikube  
   - install / upgrade the Helm chart (ingress disabled for local)

   ./scripts/deploy.sh

3. **Verify locally**:

   - Forward the service:

     kubectl -n default port-forward svc/sample-node-app 8080:80

   - Call it:

     curl http://localhost:8080/
     # → Hello from the Node.js app!

    Or use the alb

    kubectl get ingress sample-node-app -o wide                   
    NAME              CLASS   HOSTS   ADDRESS                                                  PORTS   AGE
    sample-node-app   alb     *       sample-node-app-1711157201.us-east-1.elb.amazonaws.com   80      53m

    ➜  devops-test git:(main) curl http://sample-node-app-1711157201.us-east-1.elb.amazonaws.com
    Hello from the Node.js app!%     

---

## 2 Cloud Deployment: Infrastructure (Jenkins) & Application (GitHub Actions)

### Note on Jenkins Shared Libraries

The Jenkins pipeline used for **infrastructure provisioning** leverages a custom shared library to modularize common CI/CD logic (e.g., Terraform execution).

Jenkins must be configured to load this shared library from the `shared-lib/` folder in this repository.

To configure it:

1.  Go to `Manage Jenkins` → `Configure System` → `Global Pipeline Libraries`.
2.  Add a new library:
    * Name: `shared-lib`
    * Default version: `main`
    * Retrieval method: `Modern SCM`
    * SCM: `Git`
    * Project Repository: `https://github.com/pabloperfer/devops-test.git`
    * Library path: `shared-lib`
3.  In your `Jenkinsfile`, reference it at the top:

    ```groovy
    @Library('shared-lib') _
    ```

### 2.1 Prerequisites

| Component        | Minimum version | Location / Notes                                       |
|------------------|-----------------|--------------------------------------------------------|
| Terraform CLI    | ≥ 1.7           | Installed on the **Jenkins agent** for infra provisioning |
| Helm CLI         | ≥ 3.14          | Installed on the **GitHub Actions self-hosted runner** |
| AWS CLI v2       | ≥ 2.15          | Installed on the **GitHub Actions self-hosted runner**; Jenkins agent also needs it for Terraform |
| Docker           | 24.x            | Docker-in-Docker or host Docker; installed on **GitHub Actions self-hosted runner** |
| Jenkins          | 2.440-LTS       | Pipeline plugin enabled; for infrastructure provisioning |
| Git              | any    


**IAM roles**

| Role                        | Used by          | Minimum policies |
|-----------------------------|------------------|------------------|
| `TerraformDeploymentRole`   | Jenkins pipeline | `AdministratorAccess` for the demo (restrict in production) |
| IRSA (ALB controller)       | Created by Terraform | `modules/aws_lb_controller/iam_policy_alb_controller.json` |

Trust policy so Jenkins can assume the role:


{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::<ACCOUNT_ID>:user/<jenkins-user>"
    },
    "Action": "sts:AssumeRole"
  }]
}

** AWS CLI **

This setup assumes your Jenkins agent machine has an AWS CLI profile named terraform-assume-role, which in turn uses a “base” profile (default) with long-lived keys. This is only for the Jenkins infrastructure provisioning pipeline. GitHub Actions uses OIDC for authentication.


** ~/.aws/credentials **

[default]

aws_access_key_id     = XXXXXXXXXXXXXXXXXXXX

aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

[terraform-assume-role]

role_arn       = arn:aws:iam::xxxxxxxxx:role/TerraformDeploymentRole

source_profile = default

---

**Trust policy for GitHub Actions OIDC Role (example for repository pabloperfer/devops-test):

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:pabloperfer/devops-test:*"
        }
      }
    }
  ]
}


### 2.2 Clone the repository


git clone https://github.com/pabloperfer/devops-test.git
cd devops-test


---

### 2.3 Terraform variables

Edit `terraform/dev.tfvars` so it matches your AWS environment.

| Variable          | Example                          | Description                           |
|-------------------|----------------------------------|---------------------------------------|
| `account_id`      | `123456789012`                   | Your AWS account ID                   |
| `vpc_id`          | `vpc-0abc1234def567890`          | Existing VPC with public subnets      |
| `subnet_ids`      | `["subnet-0a…","subnet-0b…"]`    | Six **public** subnets in ≥ 2 AZs     |
| `repository_name` | `sample-node-app`                | ECR repository name                   |

Subnet tags required by the ALB controller:

 
kubernetes.io/cluster/<cluster_name> = shared
kubernetes.io/role/elb               = 1
 

---


2. **Tools** — make sure `terraform`, `helm`, `aws` and `docker` are in the agent’s `PATH`.

3. **Pipeline job**

| Field       | Value                                                    |
|-------------|----------------------------------------------------------|
| Definition  | Pipeline script from SCM                                 |
| Repository  | `https://github.com/pabloperfer/devops-test.git`         |
| Script Path | `jenkins/Jenkinsfile`                                    |
| Branch      | `main`                                                   |

---

### 2.4 Jenkins Setup

Configure a new Jenkins Pipeline job:

| Field       | Value                                                |
|-------------|------------------------------------------------------|
| Definition  | Pipeline script from SCM                             |
| Repository  | `https://github.com/pabloperfer/devops-test.git`     |
| Script Path | `jenkins/Jenkinsfile`                                |
| Branch      | `main`                                               |

### 2.5 Infrastructure Provisioning (Jenkins)

Trigger **Build Now** in your Jenkins job. The pipeline performs:

1.  **Terraform Apply** — creates EKS, ECR, OIDC provider for GitHub Actions, and deploys the Actions Runner Controller (ARC) and the AWS Load Balancer Controller to EKS.

### 2.6 Application Deployment (GitHub Actions)

Trigger the `Deploy Application to EKS` workflow manually from the GitHub Actions UI (via `workflow_dispatch`). This workflow, running on your self-hosted runner, performs:

1.  **Checkout repository**
2.  **Configure AWS Credentials** using OIDC to assume `IAM_ROLE_ARN`.
3.  **Set Image Tag and ECR URI** dynamically.
4.  **Lint and Test Application** (yamllint, npm tests, helm lint).
5.  **Build and Push Docker Image to ECR**.
6.  **Configure kubectl for EKS**.
7.  **Deploy Application with Helm** (`upgrade --install` the chart, atomic, waits up to 5 min).

**Validate the result:**

```bash
DNS=$(kubectl -n default get ingress sample-node-app   -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -H "Host: sample-app.example.com" "http://$DNS/"
# → Hello from the Node.js app!
 

The first request may return **503** until the ALB target‑group health
checks pass (≈ 15 s).

---

### 2.5 Tear‑down

*With Jenkins* — build with parameter **`DESTROY=true`**.  
*Manually*:

export AWS_PROFILE=terraform-assume-role

helm uninstall sample-node-app -n default || true
cd terraform
terraform destroy -auto-approve -var-file=dev.tfvars
 

---

### Helm Secret Management

The application Helm chart includes a Kubernetes Secret template (e.g., templates/secret.yaml) that defines the structure for injecting sensitive data like the database password into the runtime environment. The actual sensitive values are not stored in the Git repository.

Instead, at deployment time, the database password (for the demo) is securely passed from GitHub Actions' encrypted repository secrets (${{ secrets.DB_PASS_SECRET }}). This value is then injected into the Kubernetes Secret template via a Helm argument (e.g., --set secret.DB_PASSWORD=...). Helm subsequently creates or updates this Kubernetes Secret in the cluster. The application pods then consume this Kubernetes Secret, typically via environment variables or mounted files, to access the password at runtime.

For production, the recommended approach is to leverage OIDC-assumed roles within GitHub Actions to fetch secrets dynamically from AWS Secrets Manager, which are then mounted into application pods using the Secrets Store CSI Driver. This ensures secrets are never hardcoded or passed directly through the CI/CD pipeline, and are managed with robust encryption, rotation, and IAM-level audit trails.

## 3 Ideas for future hardening

| Area           | Recommendation                                                          |
|----------------|-------------------------------------------------------------------------|
| Terraform state| Add DynamoDB table for state locking                                    |
| Deployment     | Promote with Helmfile / Argo CD (GitOps) instead of direct Helm upgrades|
| Secrets        | Mount from AWS Secrets Manager via Secrets Store CSI driver             |
| Cost           | Use AWS Budgets & SCPs to limit instance / ALB types in non‑prod        |
| Observability  | Send ALB + pod metrics to CloudWatch / Prometheus                       |
| Hardening      | Make the EKS API private, run Jenkins inside the VPC                    |

---

_Last updated: 2025‑06‑30_
