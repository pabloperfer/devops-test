module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.repository_name
}

module "eks" {
  source           = "./modules/eks"
  cluster_name     = var.cluster_name
  node_group_name  = var.node_group_name
  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size
  vpc_id           = var.vpc_id
  subnet_ids       = var.subnet_ids
  aws_region       = var.aws_region
}
