#!/usr/bin/env bash
# fetch-upstream.sh
# Clones or updates the explain.depesz.com source into app/docker/src/
# Run this once before `make build` (or `docker build`).
#
# Keeping the clone outside the Dockerfile means:
#   - Docker layer cache works across rebuilds
#   - Builds work offline after the first fetch
#   - You can pin to a specific commit for reproducibility

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/../app/docker/src/explain.depesz.com"
UPSTREAM_URL="${UPSTREAM_URL:-https://gitlab.com/depesz/explain.depesz.com.git}"
UPSTREAM_REF="${UPSTREAM_REF:-master}"

mkdir -p "$(dirname "${SRC_DIR}")"

if [[ -d "${SRC_DIR}/.git" ]]; then
  echo "Updating existing checkout (ref: ${UPSTREAM_REF})..."
  git -C "${SRC_DIR}" fetch origin
  git -C "${SRC_DIR}" checkout "${UPSTREAM_REF}"
  git -C "${SRC_DIR}" pull --ff-only
else
  echo "Cloning ${UPSTREAM_URL} (ref: ${UPSTREAM_REF})..."
  git clone --branch "${UPSTREAM_REF}" "${UPSTREAM_URL}" "${SRC_DIR}"
fi

COMMIT=$(git -C "${SRC_DIR}" rev-parse --short HEAD)
echo ""
echo "Source ready at: ${SRC_DIR}"
echo "Commit          : ${COMMIT}"
echo ""
echo "Review the upstream LICENSE before publishing a derived image:"
echo "  ${SRC_DIR}/LICENSE"
echo ""
echo "Next: make build"
