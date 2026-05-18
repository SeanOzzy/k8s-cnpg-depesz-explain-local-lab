#!/usr/bin/env bash
# deploy.sh
# Builds the kustomize overlay and applies it to the cluster.
# Usage: ./scripts/deploy.sh [dev|prod]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLUSTER_NAME="explain-cluster"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[deploy]${NC} $*"; }
warn()  { echo -e "${YELLOW}[deploy]${NC} $*"; }
error() { echo -e "${RED}[deploy]${NC} $*" >&2; exit 1; }

ENV="${1:-dev}"
OVERLAY_DIR="${REPO_ROOT}/k8s/overlays/${ENV}"

[[ -d "${OVERLAY_DIR}" ]] || error "Unknown environment '${ENV}'. Available: dev, prod"

# Ensure we're talking to the right cluster
kubectl config use-context "kind-${CLUSTER_NAME}" 2>/dev/null \
  || error "Cannot switch to context kind-${CLUSTER_NAME}. Run ./scripts/bootstrap.sh first."

info "Building kustomize overlay: ${ENV}"

# Dry-run validation first
info "Validating manifests..."
kustomize build "${OVERLAY_DIR}" | kubectl apply --dry-run=client -f - \
  || error "Validation failed — check the output above"

# Apply
info "Applying manifests..."
kustomize build "${OVERLAY_DIR}" | kubectl apply -f -

# Wait for the CNPG cluster to become healthy
info "Waiting for CloudNativePG cluster to become ready..."
"${SCRIPT_DIR}/wait-for-cluster.sh"

# Wait for the app deployment
info "Waiting for explain-app deployment..."
kubectl rollout status deployment/explain-app \
  -n explain \
  --timeout=120s

echo ""
info "Deploy complete (env=${ENV})."
info "  Run: ./scripts/port-forward.sh"
info "  Then open: http://localhost:8080"
