// vars/createRunnerDeployment.groovy

def call(Map config) {
  // Define required parameters
  def imageUri = config.imageUri
  def repository = config.repository

  // Use a Groovy multiline string to build the manifest
  def manifest = """
  apiVersion: actions.summerwind.dev/v1alpha1
  kind: RunnerDeployment
  metadata:
    name: gha-runner-deployment
    namespace: actions-runner-system
  spec:
    replicas: 1
    template:
      spec:
        repository: "${repository}"
        image: "${imageUri}"
        labels:
          - self-hosted
  """

  // Use a sh step to apply the manifest
  sh "echo '''${manifest}''' | kubectl apply -f -"
}