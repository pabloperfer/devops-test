def call(String repo, String fullImage, String region) {
  sh """
    aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${repo}
    docker push ${fullImage}
  """
}