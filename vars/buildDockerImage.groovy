// Has a third parameter 'dockerfileName' with a default value
def call(String path, String fullImage, String dockerfileName = 'Dockerfile') {
  dir(path) {
    // Add the -f flag to the docker build command to specify the Dockerfile name
    sh "docker build --build-arg BUILDKIT_INLINE_CACHE=1 --platform linux/amd64 --provenance=false -t ${fullImage} -f ${dockerfileName} ."
  }
}