variable "cluster_name"       { type = string }
variable "node_group_name"    { type = string }
variable "aws_region"    { type = string }
variable "desired_capacity"   { type = number }
variable "min_size"           { type = number }
variable "max_size"           { type = number }
variable "vpc_id"             { type = string }
variable "subnet_ids"         { type = list(string) }
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}