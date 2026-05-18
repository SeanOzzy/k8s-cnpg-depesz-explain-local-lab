#!/usr/bin/env bash
# bootstrap.sh
# Creates the kind cluster and installs the CloudNativePG operator.
# Safe to re-run: checks if the cluster already exists before creating it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

#  versions 
CNPG_VERSION="${CNPG_VERSION:-1.23.1}"
CLUSTER_NAME="explain-cluster"

#  colours 
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[bootstrap]${NC} $*"; }
warn()  { echo -e "${YELLOW}[bootstrap]${NC} $*"; }
error() { echo -e "${RED}[bootstrap]${NC} $*" >&2; exit 1; }

#  preflight checks 
# Check if any ports that this app requires are already in use
for ports in 8080 9000 3000 5432; do
  if lsof -i :"$ports" &>/dev/null; then
    error "Port $ports is already in use. Please free it before running this script."
    exit 1
  fi
done

# Ensure we have all the required tools installed
for cmd in docker kind kubectl kustomize; do
  command -v "$cmd" &>/dev/null || error "Required tool not found: $cmd"
done

docker info &>/dev/null || error "Docker daemon is not running"

#  kind cluster 
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  warn "kind cluster '${CLUSTER_NAME}' already exists — skipping creation"
else
  info "Creating kind cluster '${CLUSTER_NAME}'..."
  kind create cluster \
    --name "${CLUSTER_NAME}" \
    --config "${REPO_ROOT}/kind-config.yaml" \
    --wait 90s
  info "Cluster created."
fi

# Set kubectl context
kubectl cluster-info --context "kind-${CLUSTER_NAME}" &>/dev/null \
  || error "Cannot reach cluster context kind-${CLUSTER_NAME}"
kubectl config use-context "kind-${CLUSTER_NAME}"

#  CloudNativePG operator 
CNPG_MANIFEST="https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-${CNPG_VERSION%.*}/releases/cnpg-${CNPG_VERSION}.yaml"

info "Installing CloudNativePG operator v${CNPG_VERSION}..."
kubectl apply --server-side -f "${CNPG_MANIFEST}"

info "Waiting for CNPG controller to become ready (up to 3 minutes)..."
kubectl rollout status deployment/cnpg-controller-manager \
  -n cnpg-system \
  --timeout=180s

info "Verifying CRDs..."
kubectl get crd clusters.postgresql.cnpg.io &>/dev/null \
  || error "CNPG CRD not found — operator installation may have failed"

echo ""
info "Bootstrap complete."
info "  Cluster context : kind-${CLUSTER_NAME}"
info "  CNPG version    : ${CNPG_VERSION}"
echo ""
info "Next step: ./scripts/deploy.sh dev"
