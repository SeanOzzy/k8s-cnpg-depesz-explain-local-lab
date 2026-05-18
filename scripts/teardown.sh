#!/usr/bin/env bash
# teardown.sh
# Removes the kind cluster entirely (including all PVCs and data).
# Run this when you want a clean slate.

set -euo pipefail

CLUSTER_NAME="explain-cluster"

YELLOW='\033[1;33m'; RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[teardown]${NC} $*"; }
warn()  { echo -e "${YELLOW}[teardown]${NC} $*"; }

warn "This will DELETE the kind cluster '${CLUSTER_NAME}' and all data in it."
read -r -p "Are you sure? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  info "Deleting cluster '${CLUSTER_NAME}'..."
  kind delete cluster --name "${CLUSTER_NAME}"
  info "Cluster deleted."
else
  warn "Cluster '${CLUSTER_NAME}' not found — nothing to delete."
fi

info "Teardown complete."
info "To start fresh: ./scripts/bootstrap.sh"
