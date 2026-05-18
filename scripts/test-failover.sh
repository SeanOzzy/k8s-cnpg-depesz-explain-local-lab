#!/usr/bin/env bash
# test-failover.sh
# Demonstrates CNPG self-healing by deleting the current primary pod and
# watching the operator promote a standby.
#
# Uses the cnpg.io/instanceRole=primary label selector to find the primary —
# this is correct regardless of which ordinal currently holds that role.

set -euo pipefail

NAMESPACE="${NAMESPACE:-explain}"
CLUSTER="${CLUSTER:-pg-explain}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[failover]${NC} $*"; }
step()  { echo -e "${CYAN}[failover]${NC} $*"; }
warn()  { echo -e "${YELLOW}[failover]${NC} $*"; }

#  Pre-flight 
kubectl get cluster "${CLUSTER}" -n "${NAMESPACE}" &>/dev/null \
  || { echo "CNPG Cluster '${CLUSTER}' not found in namespace '${NAMESPACE}'."; exit 1; }

step "=== Before failover ==="
kubectl get pods -n "${NAMESPACE}" \
  -l "cnpg.io/cluster=${CLUSTER}" \
  -o wide \
  --show-labels 2>/dev/null | grep -v "^$"
echo ""

# Find the primary by its CNPG role label 
# CNPG sets cnpg.io/instanceRole=primary on whichever pod is currently primary.
# This is more reliable than assuming pod ordinal 1 is always primary.
PRIMARY_POD=$(kubectl get pods -n "${NAMESPACE}" \
  -l "cnpg.io/cluster=${CLUSTER},cnpg.io/instanceRole=primary" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [[ -z "${PRIMARY_POD}" ]]; then
  warn "Could not find a pod with label cnpg.io/instanceRole=primary."
  warn "Falling back to cluster status currentPrimary field..."
  PRIMARY_POD=$(kubectl get cluster "${CLUSTER}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.currentPrimary}' 2>/dev/null || true)
fi

if [[ -z "${PRIMARY_POD}" ]]; then
  echo "ERROR: Cannot identify the primary pod. Is the cluster healthy?" >&2
  kubectl describe cluster "${CLUSTER}" -n "${NAMESPACE}" | grep -A5 "Status:"
  exit 1
fi

info "Current primary: ${PRIMARY_POD}"
info "Deleting it now to trigger CNPG failover..."
echo ""

kubectl delete pod -n "${NAMESPACE}" "${PRIMARY_POD}"

step "=== Waiting for cluster to recover (up to 5 minutes) ==="
step "Watch what happens: in another terminal run:"
step "  kubectl get pods -n ${NAMESPACE} -w"
echo ""

# Poll until a new primary is elected and the cluster is healthy
TIMEOUT=300
INTERVAL=5
deadline=$(( $(date +%s) + TIMEOUT ))

while true; do
  [[ $(date +%s) -ge ${deadline} ]] && { echo "Timed out waiting for recovery." >&2; exit 1; }

  NEW_PRIMARY=$(kubectl get cluster "${CLUSTER}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.currentPrimary}' 2>/dev/null || echo "")
  READY=$(kubectl get cluster "${CLUSTER}" -n "${NAMESPACE}" \
    -o jsonpath='{.status.readyInstances}' 2>/dev/null || echo "0")

  if [[ -n "${NEW_PRIMARY}" ]] && [[ "${NEW_PRIMARY}" != "${PRIMARY_POD}" ]] && [[ "${READY}" -ge 1 ]]; then
    break
  fi

  warn "Waiting... currentPrimary=${NEW_PRIMARY:-unknown} readyInstances=${READY}"
  sleep "${INTERVAL}"
done

echo ""
step "=== After failover ==="
kubectl get pods -n "${NAMESPACE}" \
  -l "cnpg.io/cluster=${CLUSTER}" \
  -o wide 2>/dev/null
echo ""

info "Failover complete."
info "  Old primary : ${PRIMARY_POD}"
info "  New primary : ${NEW_PRIMARY}"
info ""
info "The pg-explain-rw Service now points to ${NEW_PRIMARY}."
info "The app experienced a brief connection interruption and nothing else."
