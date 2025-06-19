def call(String region, String kubeconfig) {
  withEnv(["AWS_PROFILE=terraform-assume-role"]) {
    sh """
      aws eks update-kubeconfig \
        --region ${region} \
        --name devops-eks-cluster \
        --kubeconfig ${kubeconfig}
    """
  }
}