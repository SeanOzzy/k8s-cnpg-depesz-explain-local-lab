#!/usr/bin/env bash
# wait-for-cluster.sh
# Waits for the CloudNativePG Cluster resource to report a healthy primary.
# Exits 0 on success, 1 on timeout.
#
# Strategy:
#   1. `kubectl wait --for=condition=Ready` — fast path, clean exit when supported
#   2. Status polling loop — fallback that reads CNPG's own .status fields,
#      more portable across operator versions

set -euo pipefail

NAMESPACE="${NAMESPACE:-explain}"
CLUSTER_NAME="${CLUSTER_NAME:-pg-explain}"
TIMEOUT="${TIMEOUT:-300}"   # seconds
INTERVAL=5

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[wait-cluster]${NC} $*"; }
warn()  { echo -e "${YELLOW}[wait-cluster]${NC} $*"; }
error() { echo -e "${RED}[wait-cluster]${NC} $*" >&2; exit 1; }

info "Waiting for CNPG Cluster '${CLUSTER_NAME}' in namespace '${NAMESPACE}'..."

# Wait for the resource to exist first (initdb takes a moment to start)
deadline=$(( $(date +%s) + TIMEOUT ))
until kubectl get cluster "${CLUSTER_NAME}" -n "${NAMESPACE}" &>/dev/null; do
  [[ $(date +%s) -ge ${deadline} ]] && error "Timed out waiting for Cluster resource to appear."
  warn "Cluster resource not created yet — waiting..."
  sleep "${INTERVAL}"
done

# Fast path: kubectl wait --for=condition=Ready 
# CNPG sets a Ready condition once the cluster is healthy. This is the cleanest
# approach but requires the operator version to populate the condition.
if kubectl wait \
     --for=condition=Ready \
     "cluster/${CLUSTER_NAME}" \
     -n "${NAMESPACE}" \
     --timeout="${TIMEOUT}s" 2>/dev/null; then
  primary=$(kubectl get cluster "${CLUSTER_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.currentPrimary}' 2>/dev/null || echo "unknown")
  info "Cluster is Ready. Primary: ${primary}"
  exit 0
fi

warn "kubectl wait --for=condition=Ready did not succeed — falling back to status polling"

# ── Fallback: poll .status fields ─────────────────────────────────────────────
deadline=$(( $(date +%s) + TIMEOUT ))
while true; do
  [[ $(date +%s) -ge ${deadline} ]] && error "Timed out after ${TIMEOUT}s."

  phase=$(kubectl get cluster "${CLUSTER_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  ready=$(kubectl get cluster "${CLUSTER_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.readyInstances}' 2>/dev/null || echo "0")
  primary=$(kubectl get cluster "${CLUSTER_NAME}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.currentPrimary}' 2>/dev/null || echo "")

  warn "phase=${phase:-unknown}  readyInstances=${ready:-0}  currentPrimary=${primary:-none}"

  if [[ -n "${primary}" ]] && [[ "${ready}" -ge 1 ]]; then
    info "Cluster is healthy. Primary: ${primary} | Ready: ${ready}"
    exit 0
  fi

  sleep "${INTERVAL}"
done
