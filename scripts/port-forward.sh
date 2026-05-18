#!/usr/bin/env bash
# port-forward.sh
# Forwards the explain-app service to localhost:8080.
# Uses the NodePort that kind already exposes, so this is mainly a UX wrapper
# that also validates the cluster is reachable before printing the URL.

set -euo pipefail

CLUSTER_NAME="explain-cluster"
APP_URL="http://localhost:8080"

GREEN='\033[0;32m'; NC='\033[0m'
info() { echo -e "${GREEN}[port-forward]${NC} $*"; }

kubectl config use-context "kind-${CLUSTER_NAME}" 2>/dev/null \
  || { echo "Cannot find context kind-${CLUSTER_NAME}. Run ./scripts/bootstrap.sh first." >&2; exit 1; }

# The NodePort 30080 → host 8080 mapping is set in kind-config.yaml.
# For environments where NodePort isn't available (e.g. CI), fall back to port-forward.
NODE_PORT=$(kubectl get svc explain-app -n explain \
  -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")

if [[ "${NODE_PORT}" == "30080" ]]; then
  info "App is available at ${APP_URL} (via kind NodePort)"
  info "The NodePort mapping is already active — no port-forward process needed."
  info ""
  info "  Tip: If the page doesn't load, wait a few seconds and try again."
  info "  The explain-app pod may still be starting up."
else
  info "NodePort not found (NodePort=${NODE_PORT:-unset}) — using kubectl port-forward"
  info "Forwarding service/explain-app :8080 → localhost:8080"
  info "Press Ctrl+C to stop."
  kubectl port-forward svc/explain-app 8080:80 -n explain
fi

echo ""
info "Open: ${APP_URL}"
