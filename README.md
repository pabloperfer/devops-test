DevOps-Test – End-to-End Run Book

This guide explains how you can stand up the complete solution (Terraform → ECR → EKS → Helm) in your own AWS account and Jenkins instance.

⸻

1 · Prerequisites

Component	Tested version	Notes
Terraform CLI	≥ 1.7	installed on the Jenkins agent
Helm CLI	≥ 3.14	
AWS CLI v2	≥ 2.15	must be able to assume an IAM role
Docker	24.x	Docker-in-Docker or host Docker
Jenkins	2.440-LTS	Pipeline plugin enabled
Git	any	

IAM roles

Role	Used by	Minimum policies *
TerraformDeploymentRole	Jenkins pipeline (assumed via STS)	AdministratorAccess for the demo — restrict in prod
IRSA (ALB controller)	Created by Terraform	modules/aws_lb_controller/iam_policy_alb_controller.json

* Trust policy so Jenkins can assume the role:

{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"AWS": "arn:aws:iam::<YOUR-ACCOUNT>:user/<jenkins-user>"},
    "Action": "sts:AssumeRole"
  }]
}


⸻

2 · Clone the repository

git clone https://github.com/pabloperfer/devops-test.git
cd devops-test


⸻

3 · Terraform variables

Edit terraform/dev.tfvars so it matches your AWS environment.

Variable	Example	Description
account_id	123456789012	your AWS account
vpc_id	vpc-0abc1234def567890	existing VPC (public subnets)
subnet_ids	["subnet-0a…","subnet-0b…",…]	six public subnets in ≥ 2 AZs
repository_name	sample-node-app	name of the ECR repo

Subnet tags required by the AWS Load Balancer Controller

kubernetes.io/cluster/<cluster_name> = shared
kubernetes.io/role/elb              = 1


⸻

4 · Jenkins configuration
	1.	AWS credentials
Kind: Secret text
ID: aws-profile-terraform
Content (~/.aws/credentials-style):

[terraform-assume-role]
role_arn       = arn:aws:iam::<account_id>:role/TerraformDeploymentRole
source_profile = default


	2.	Global tools – ensure terraform, helm, aws, docker are in the agent $PATH.
	3.	Pipeline job
Definition: Pipeline script from SCM
Repository: https://github.com/pabloperfer/devops-test.git
Script Path: jenkins/Jenkinsfile
Branch: main.

⸻

5 · First build

Click Build Now. The pipeline will:
	1.	Terraform — provision EKS, ECR, ALB Controller, IRSA…
	2.	NPM tests — run unit tests in app/.
	3.	Docker build — build the image and tag it build-N-timestamp.
	4.	Push to ECR.
	5.	Helm upgrade/install — deploy the chart in helm-chart/.
	6.	Roll-out check — wait until the Deployment is READY 3/3.
	7.	Ingress — the ALB Controller creates an Application Load Balancer.

Verify:

DNS=$(kubectl -n default get ingress sample-node-app \
      -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl -H "Host: sample-app.example.com" "http://$DNS/"
# → Hello from the Node.js app!

The first request may return 503 until the target-group health checks pass (~15 s).

⸻

6 · Tear-down

From Jenkins

Build with Parameters → tick DESTROY → Build.

Manually

export AWS_PROFILE=terraform-assume-role

helm uninstall sample-node-app -n default || true

cd terraform
terraform destroy -auto-approve -var-file=dev.tfvars


⸻

7 · Long-term maintenance ideas

Area	Recommendation
State	add DynamoDB table to S3 backend for state locking
Deployment	promote with helmfile, Argo CD or GitOps instead of direct helm upgrade
Secrets	move to AWS Secrets Manager via the Secrets Store CSI driver
Cost controls	AWS Budgets & SCPs to limit instance/LB types in non-prod
Observability	ship metrics to CloudWatch Prometheus, Grafana or Datadog
Hardening	make the EKS API private and run Jenkins inside the VPC


⸻

Last updated: 2025-06-17