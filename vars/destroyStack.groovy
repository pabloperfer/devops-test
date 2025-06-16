def call(String release, String kubeconfig, String region) {
  withEnv(["AWS_PROFILE=terraform-assume-role"]) {
    sh """
      aws eks update-kubeconfig --region ${region} --name devops-eks-cluster --kubeconfig ${kubeconfig} || true
      helm uninstall ${release} -n default || true
    """
    dir('terraform') {
      sh 'terraform init'
      sh 'terraform destroy -auto-approve -var-file=dev.tfvars'
    }
  }
}