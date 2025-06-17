module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.0"

  cluster_endpoint_public_access  = true   

  ########################################
  # Required inputs
  ########################################
  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  ########################################
  # One managed node-group (example)
  ########################################
  eks_managed_node_groups = {
    default = {
      node_group_name  = var.node_group_name
      desired_capacity = var.desired_capacity
      min_size         = var.min_size
      max_size         = var.max_size
      instance_types   = ["t3.medium"]
    }
  }

  #####################################################################
  # **This single switch automatically maps the role that created
  #    the cluster (TerraformDeploymentRole) as cluster-admin.**
  #####################################################################
  enable_cluster_creator_admin_permissions = true

 access_entries = {
    # ── Grant kubectl admin to your IAM user ──
    pablo_user = {
      principal_arn = "arn:aws:iam::679349556244:user/pablo"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
  #####################################################################
  # Global tags
  #####################################################################
  tags = var.tags
}