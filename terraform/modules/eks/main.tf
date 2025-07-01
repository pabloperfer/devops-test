module "eks_cluster" {
  # Defines the source of the community EKS module and pins it to a specific version
  # for reproducible infrastructure builds.
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.1"

  # Allows public access to the Kubernetes API server endpoint.
  # For production, this should ideally be restricted.
  cluster_endpoint_public_access = true

  #------------------------------------------------
  # Core Cluster Configuration
  #------------------------------------------------
  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids

  #------------------------------------------------
  # EKS Managed Node Group Configuration
  # This block defines a group of EC2 instances that will serve as worker nodes.
  #------------------------------------------------
  eks_managed_node_groups = {
    # Defines a default node group.
    default = {
      node_group_name = var.node_group_name
      instance_types  = ["t3.medium"]

      # --- This is the corrected line ---
      # The argument for the desired number of nodes is 'desired_size'.
      # We are mapping it to the 'var.desired_capacity' variable from your module's input.
      desired_size = var.desired_capacity

      # Defines the minimum and maximum number of nodes for auto-scaling.
      min_size = var.min_size
      max_size = var.max_size
    }
  }

  #-------------------------------------------------------------------
  # Cluster Access Management
  #-------------------------------------------------------------------
  # This setting automatically grants cluster-admin privileges to the IAM role
  # that created the cluster (in this case, your Terraform role).
  # This is a convenient way to ensure initial access.
  enable_cluster_creator_admin_permissions = true

  # The 'access_entries' block is the modern way to manage cluster access in EKS.
  # It replaces the older 'aws-auth-cm' ConfigMap.
  access_entries = {
    # Grants cluster-admin access to a specific IAM user named 'pablo'.
    pablo_user = {
      principal_arn = "arn:aws:iam::679349556244:user/pablo"

      # Associates the user with the built-in AmazonEKSClusterAdminPolicy.
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

  #-------------------------------------------------------------------
  # Global Tagging
  #-------------------------------------------------------------------
  # Applies a consistent set of tags to all resources created by this module.
  tags = var.tags
}