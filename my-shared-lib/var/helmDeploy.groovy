def call(String release, String chartDir, String repo, String tag, String kubeconfig) {
  withEnv(["AWS_PROFILE=terraform-assume-role", "KUBECONFIG=${kubeconfig}"]) {
    sh """
      helm dependency update ${chartDir} || true
      helm upgrade --install ${release} ${chartDir} \\
        --namespace default --create-namespace \\
        --set image.repository=${repo} \\
        --set image.tag=${tag} \\
        --wait --timeout 5m --atomic
    """
  }
}