#!/usr/bin/env bash
#
# Local one-liner deploy
# ----------------------
# * Builds the sample image locally (no AWS/ECR)
# * Creates a kind cluster if kubectl has no current context
# * Installs / upgrades the Helm chart so pods use that local image
# * Prints a port-forward command you can curl
#
# Requirements: docker, kubectl, helm   (kind is optional)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

APP_NAME="sample-node-app"
IMAGE_TAG="local"
FULL_IMAGE="${APP_NAME}:${IMAGE_TAG}"

CHART_DIR="${ROOT_DIR}/helm-chart"
RELEASE="${APP_NAME}"
NAMESPACE="default"

log() { printf '[INFO] %s\n' "$*"; }
err() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

# 1) Verify required tools
for bin in docker helm kubectl; do
  command -v "$bin" >/dev/null 2>&1 || err "'$bin' not found in PATH."
done

# 2) Create a kind cluster if kubectl has no context
if ! kubectl config current-context >/dev/null 2>&1; then
  if command -v kind >/dev/null 2>&1; then
    log "No kube-context detected; creating kind cluster 'dev'"
    kind create cluster --name dev
  else
    err "kubectl not configured and 'kind' not installed."
  fi
fi

# 3) Build the Docker image
log "Building Docker image ${FULL_IMAGE}"
docker build --platform linux/amd64 -t "$FULL_IMAGE" "${ROOT_DIR}/app"

# 4) If using kind, load the image into the cluster
if kubectl config current-context | grep -q '^kind-'; then
  KIND_NAME="$(kubectl config current-context | cut -d'-' -f2-)"
  log "Loading image into kind node '${KIND_NAME}'"
  kind load docker-image "$FULL_IMAGE" --name "$KIND_NAME"
fi

# 5) Helm install / upgrade
log "Installing or upgrading Helm release '${RELEASE}'"
helm dependency update "$CHART_DIR" >/dev/null || true

helm upgrade --install "$RELEASE" "$CHART_DIR" \
  --namespace "$NAMESPACE" --create-namespace \
  --set image.repository="$APP_NAME" \
  --set image.tag="$IMAGE_TAG" \
  --wait --timeout 5m --atomic

# 6) Show result & how to test
log "Deployment ready:"
kubectl -n "$NAMESPACE" get deploy "$RELEASE" -o wide

cat <<EOF

To hit the service locally, run in another terminal:

  kubectl -n $NAMESPACE port-forward svc/$RELEASE 8080:80
  curl http://localhost:8080/

EOF