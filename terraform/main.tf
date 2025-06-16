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


module "aws_lb_controller" {
  source = "./modules/aws_lb_controller"

  cluster_name     = module.eks.cluster_name
  vpc_id           = var.vpc_id
  aws_region       = var.aws_region
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_ca       = base64decode(module.eks.cluster_certificate_authority_data)
  token            = data.aws_eks_cluster_auth.default.token
  oidc_provider     = module.eks.oidc_provider
  oidc_provider_arn = module.eks.oidc_provider_arn
  providers = {
    helm = helm
  }
}
