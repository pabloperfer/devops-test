aws_region        = "us-east-1"
repository_name   = "sample-node-app"

cluster_name      = "devops-eks-cluster"
node_group_name   = "devops-node-group"
desired_capacity  = 2
min_size          = 2
max_size          = 3

vpc_id = "vpc-022e0e62d40626eca"

subnet_ids = [
  "subnet-05388a2336534239f",
  "subnet-0c371828f6ba359fb",
  "subnet-06623675610abd37e",
  "subnet-0658ce955d8b30f64",
  "subnet-07dd6a30d288be705"
]
