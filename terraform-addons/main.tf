# terraform-addons/main.tf


# This data source uses the cluster's OIDC issuer URL
data "aws_iam_openid_connect_provider" "oidc_provider" {
  url = data.aws_eks_cluster.default.identity[0].oidc[0].issuer
}

# This module installs the AWS Load Balancer Controller.
module "aws_lb_controller" {
  source = "./modules/aws_lb_controller"

  # Pass the necessary variables to the module.
  cluster_name = var.cluster_name
  vpc_id       = var.vpc_id
  aws_region   = var.aws_region
  
  # Pass the OIDC data fetched by the data sources above.
  oidc_provider     = replace(data.aws_eks_cluster.default.identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_arn = data.aws_iam_openid_connect_provider.oidc_provider.arn

}

