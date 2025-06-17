#!/usr/bin/env bash
#
# Local deployment helper (Minikube)
# ----------------------------------
#  • Builds the Docker image into Minikube’s Docker daemon
#  • Starts Minikube on the Docker driver if no context exists
#  • Deploys/upgrades the Helm chart (with local image & no ALB)
#  • Prints a port‐forward snippet for testing
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

APP="sample-node-app"
TAG="local"
IMAGE="${APP}:${TAG}"
CHART_DIR="${ROOT_DIR}/helm-chart"
NS="default"

# simple logger
log() { printf '=> %s\n' "$*"; }

# 1) Check prerequisites
for bin in docker minikube kubectl helm; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "ERROR: '$bin' not in PATH"; exit 1; }
done

# 2) Ensure a Minikube context
CTX="$(kubectl config current-context 2>/dev/null || true)"
if [[ "$CTX" != "minikube" ]]; then
  log "Starting minikube (docker driver)..."
  minikube start --driver=docker
fi

# 3) Use Minikube’s Docker daemon
log "Configuring Docker to build inside minikube..."
eval "$(minikube docker-env)"

# 4) Build the image
log "Building image ${IMAGE} into minikube..."
docker build --platform linux/amd64 \
  -t "${IMAGE}" "${ROOT_DIR}/app"

# 5) Helm deploy (disable ingress, use local pull policy)
HELM_ARGS=(
  --namespace "${NS}" --create-namespace
  --set image.repository="${APP}"
  --set image.tag="${TAG}"
  --set image.pullPolicy=IfNotPresent
  --set ingress.enabled=false
)

log "Deploying Helm release '${APP}'..."
helm dependency update "${CHART_DIR}" >/dev/null || true
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