def call(String release, String kubeconfig, String region) {
  withEnv(["AWS_PROFILE=terraform-assume-role"]) {
  

    // Step 1: Destroy the addons FIRST.
    dir('terraform-addons') {
      sh 'terraform init'
      sh 'terraform destroy -auto-approve -var-file=dev.tfvars'
    }

    // Step 2: Destroy the main EKS infrastructure LAST.
    dir('terraform') {
      sh 'terraform init'
      sh 'terraform destroy -auto-approve -var-file=dev.tfvars'
    }
  }
}