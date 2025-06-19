def call(String path, String fullImage) {
  dir(path) {
    sh "docker build --build-arg BUILDKIT_INLINE_CACHE=1 --platform linux/amd64 --provenance=false -t ${fullImage} ."
  }
}