# terraform-addons/variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
}



variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the cluster is deployed."
  type        = string
}
variable "aws_profile" {
  description = "AWS CLI named profile to use"
  type        = string
  default     = "terraform-assume-role" 
}

# Add these two variable declarations
variable "oidc_provider_arn" {
  description = "The ARN of the EKS OIDC provider."
  type        = string
}

variable "oidc_provider" {
  description = "The URL of the EKS OIDC provider."
  type        = string
}
