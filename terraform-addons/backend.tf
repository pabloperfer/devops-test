terraform {
  backend "s3" {
    bucket = "devops-terraform-state-pabloperez"
    key    = "devops-test-addons/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}
