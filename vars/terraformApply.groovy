def call(String path, String tfvarsFile) {
  dir(path) {
    sh 'terraform init'
    sh "terraform plan -var-file=${tfvarsFile}"
    sh "terraform apply -auto-approve -var-file=${tfvarsFile}"
  }
}