#!/usr/bin/env bash

#
# Local deployment helper (Minikube)
# ----------------------------------
# This script automates the process of deploying the 'sample-node-app'
# to a local Minikube cluster. It's designed for quick local testing and
# development iterations, simulating the Kubernetes deployment process.
#
# Key functionalities include:
#  • Building the Docker image directly into Minikube’s Docker daemon,
#    avoiding the need for a remote registry for local testing.
#  • Ensuring a Minikube cluster is running (starts it if necessary).
#  • Deploying or upgrading the Helm chart with specific overrides
#    for local development (e.g., disabling Ingress, setting local image pull policy).
#  • Providing instructions for local access via port-forwarding.
#

set -euo pipefail # Strict mode:
                  # -e: Exit immediately if a command exits with a non-zero status.
                  # -u: Treat unset variables as an error.
                  # -o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status, or zero if all commands exit successfully.


# Define script and project root directories for path consistency.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Define application specific variables.

APP="sample-node-app"
TAG="local"
IMAGE="${APP}:${TAG}"
CHART_DIR="${ROOT_DIR}/helm-chart"
NS="default"   # Kubernetes namespace for deployment.

# Simple logging function for better script output readability.
log() { printf '=> %s\n' "$*"; }

# 1) Check prerequisites: Ensures all necessary CLI tools are installed.
# This prevents the script from failing later due to missing dependencies.
for bin in docker minikube kubectl helm; do
  command -v "$bin" >/dev/null 2>&1 || {   # This command checks if $bin (e.g., docker, minikube) is an executable command available in the system's PATH. If it finds the command, it prints its path to standard output and exits with 0. If it doesn't find it, it prints nothing to standard output, prints an error message to standard error, and exits with a non-zero status (failure).
    echo "ERROR: '$bin' not in PATH"; exit 1; }
done

# 2) Ensure a Minikube context: Checks if the current kubectl context is 'minikube'.
# If not, it starts Minikube using the Docker driver (a common and efficient choice for local K8s).
CTX="$(kubectl config current-context 2>/dev/null || true)"
if [[ "$CTX" != "minikube" ]]; then
  log "Starting minikube (docker driver)..."
  minikube start --driver=docker
fi

# 3) Use Minikube’s Docker daemon for local development.
# By running `eval "$(minikube docker-env)"`, subsequent `docker` commands
# interact with Minikube's internal Docker daemon, allowing built images
# to be directly available within the Minikube cluster without pushing to a registry.log "Configuring Docker to build inside minikube..."
#The eval command takes the output of minikube docker-env (which are a set of export commands for environment variables) and applies them directly to the current shell session. 
eval "$(minikube docker-env)"

# 4) Build the image
log "Building image ${IMAGE} into minikube..."
docker build --platform linux/amd64 \
  -t "${IMAGE}" "${ROOT_DIR}/app"

# 5) Helm deploy: Deploys or upgrades the Helm chart.
# Specific `--set` arguments are used to override default values for local testing:
# - `ingress.enabled=false`: Disables the Ingress resource, as we'll use port-forwarding for local access.
# - `image.repository`, `image.tag`: Points to the locally built Docker image.
# - `image.pullPolicy=IfNotPresent`: Prevents Kubernetes from trying to pull the image from a remote registry,
#   relying on the image already present in Minikube's Docker daemon.
HELM_ARGS=(
  --namespace "${NS}" --create-namespace
  --set image.repository="${APP}"
  --set image.tag="${TAG}"
  --set image.pullPolicy=IfNotPresent # Ensures Kubernetes looks for the image locally first.
  --set ingress.enabled=false
)

log "Deploying Helm release '${APP}'..."

# `helm dependency update`: Ensures chart dependencies are up-to-date.
helm dependency update "${CHART_DIR}" >/dev/null || true

# `helm upgrade --install`: Performs a Helm upgrade if the release exists, or an install if not.
# `--wait`: Waits for all components to be ready.
# `--timeout 5m`: Sets a timeout for the deployment.
# `--atomic`: If the upgrade fails, automatically rolls back to the previous successful release.

helm upgrade --install "${APP}" "${CHART_DIR}" \
  "${HELM_ARGS[@]}" \
  --wait --timeout 5m --atomic

# 6) Success!
log "Deployment ready. Pods:"
kubectl -n "${NS}" get pods -l app.kubernetes.io/instance="${APP}"

cat <<EOF

Test locally:

  kubectl -n ${NS} port-forward svc/${APP} 8080:80
  open http://localhost:8080/

EOF