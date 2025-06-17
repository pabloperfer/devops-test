# DevOps‑Test — End‑to‑End Run Book

This repository demonstrates a complete delivery workflow for a small Node.js
service.

* **Local path** – run everything on your laptop with Docker, kind and Helm  
* **Cloud path** – build, test and deploy the same service to AWS through a
  Jenkins pipeline that orchestrates **Terraform → ECR → EKS → Helm**
  
  check logs folder for proof of execution.

---
## 1 Local deployment with kind (optional)

Skip this section if you only need the AWS/Jenkins flow.

### 1.1 Requirements

| Tool    | Tested version                                 |
|---------|-------------------------------------------------|
| Docker  | 24.x                                            |
| kind    | latest (`go install sigs.k8s.io/kind@latest`)  |
| kubectl | 1.29                                            |
| Helm    | ≥ 3.14                                          |

### 1.2 Steps

1. **Create a local cluster** (if you don’t have one already):

   kind create cluster --name dev

2. **Run the helper script** – it will:
   - build the Docker image  
   - load it into kind  
   - install / upgrade the Helm chart

   ./scripts/deploy.sh

3. **Verify locally:**

   - Forward the service:

     kubectl -n default port-forward svc/sample-node-app 8080:80

   - Call it:

     curl http://localhost:8080/
     # → Hello from the Node.js app!

---

## 2 Full Jenkins → AWS deployment

### 2.1 Prerequisites

| Component        | Minimum version | Notes                                          |
|------------------|-----------------|------------------------------------------------|
| Terraform CLI    | ≥ 1.7           | Installed on the Jenkins agent                 |
| Helm CLI         | ≥ 3.14          |                                                |
| AWS CLI v2       | ≥ 2.15          | Must be able to assume an IAM role             |
| Docker           | 24.x            | Docker‑in‑Docker or host Docker                |
| Jenkins          | 2.440‑LTS       | Pipeline plugin enabled                        |
| Git              | any             |                                                |

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


---

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

### 2.4 Configure Jenkins

1. **AWS credentials**  
   *Kind*: Secret text  
   *ID*: `aws-profile-terraform`

    
   [terraform-assume-role]
   role_arn       = arn:aws:iam::<ACCOUNT_ID>:role/TerraformDeploymentRole
   source_profile = default
    

2. **Tools** — make sure `terraform`, `helm`, `aws` and `docker` are in the agent’s `PATH`.

3. **Pipeline job**

| Field       | Value                                                    |
|-------------|----------------------------------------------------------|
| Definition  | Pipeline script from SCM                                 |
| Repository  | `https://github.com/pabloperfer/devops-test.git`         |
| Script Path | `jenkins/Jenkinsfile`                                    |
| Branch      | `main`                                                   |

---

### 2.5 First build

Trigger **Build Now**. The pipeline performs:

1. **Terraform** — creates EKS, ECR, OIDC provider, ALB controller, …  
2. **Node tests** — runs `npm test` in `app/`.  
3. **Docker** — builds and tags `build-<N>-<timestamp>`.  
4. **Push** — uploads the image to ECR.  
5. **Helm** — `upgrade --install` the chart (atomic, waits up to 5 min).  
6. **Roll‑out wait** — deployment reaches **READY 3/3**.  
7. **Ingress** — ALB controller creates a public ALB.

Validate the result:

DNS=$(kubectl -n default get ingress sample-node-app   -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl -H "Host: sample-app.example.com" "http://$DNS/"
# → Hello from the Node.js app!
 

The first request may return **503** until the ALB target‑group health
checks pass (≈ 15 s).

---

### 2.6 Tear‑down

*With Jenkins* — build with parameter **`DESTROY=true`**.  
*Manually*:

export AWS_PROFILE=terraform-assume-role

helm uninstall sample-node-app -n default || true
cd terraform
terraform destroy -auto-approve -var-file=dev.tfvars
 

---

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

_Last updated: 2025‑06‑17_
