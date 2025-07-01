terraform {
  required_providers {
    # You may not need helm or kubernetes here anymore if all those
    # resources were moved to the terraform-addons directory.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}