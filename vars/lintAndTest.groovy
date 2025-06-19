def call(String chartDir) {
  sh "yamllint ${chartDir}"
  dir('app') {
    sh 'npm install'
    sh 'npm test'
  }
  sh "helm lint ${chartDir}"
}