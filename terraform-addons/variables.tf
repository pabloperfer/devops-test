# terraform-addons/variables.tf

variable "aws_region" {
  description = "The AWS region where resources are deployed."
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
