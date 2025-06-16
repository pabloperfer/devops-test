// vars/helmDeploy.groovy

// Remove the 'extraArgs' and add a specific parameter for the credential ID
def call(String release, String chartDir, String repo, String tag, String kubeconfig, String dbPasswordCredentialId) {
  withEnv(["AWS_PROFILE=terraform-assume-role", "KUBECONFIG=${kubeconfig}"]) {
    // Use withCredentials to securely inject the password
    withCredentials([string(credentialsId: dbPasswordCredentialId, variable: 'DB_PASSWORD_SECRET')]) {
      sh """
        helm dependency update ${chartDir} || true
        helm upgrade --install ${release} ${chartDir} \\
          --namespace default --create-namespace \\
          --set image.repository=${repo} \\
          --set image.tag=${tag} \\
          --wait --timeout 5m --atomic \\
          --set-string secret.DB_PASSWORD="\${DB_PASSWORD_SECRET}"
      """
    }
  }
}