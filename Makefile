# Mocking up a Makefile for the pg-explain-k8s lab. This will be a living document, evolving as I build out the lab and figure out the best way to structure it. For now, it's a starting point to help me organize my thoughts and tasks.
SHELL := /usr/bin/env bash

CLUSTER_NAME  ?= explain-cluster
CNPG_VERSION  ?= 1.23.1
APP_IMAGE     ?= pg-explain-app:latest
NAMESPACE     ?= explain
ENV           ?= dev

.DEFAULT_GOAL := help

.PHONY: help bootstrap up install-cnpg deploy wait-app \
        build load port-forward port-forward-db \
        status test-failover teardown

# Print help
help:
	@echo ""
	@echo "  pg-explain-k8s — local Kubernetes + CloudNativePG lab"
	@echo ""
	@echo "  Quick start:"
	@echo "    make bootstrap       Create cluster + install CNPG operator"
	@echo "    make build           Build the app container image"
	@echo "    make load            Load image into kind"
	@echo "    make deploy          Apply kustomize overlay (ENV=dev|prod)"
	@echo "    make port-forward    Open http://localhost:8080"
	@echo ""
	@echo "  Individual targets:"
	@echo "    make up              Create kind cluster only"
	@echo "    make install-cnpg    Install CloudNativePG operator only"
	@echo "    make status          Show cluster + pod status"
	@echo "    make test-failover   Delete primary pod, watch recovery"
	@echo "    make port-forward-db Forward Postgres to localhost:5432"
	@echo "    make teardown        Delete the kind cluster"
	@echo ""
	@echo "  Variables (override on command line):"
	@echo "    ENV=$(ENV)   CNPG_VERSION=$(CNPG_VERSION)   APP_IMAGE=$(APP_IMAGE)"
	@echo ""

# 
# Full bootstrap: build the kind cluster, cluster + operator in one shot
bootstrap: up install-cnpg
	@echo ""
	@echo "INFO: Bootstrap complete."
	@echo "INFO: Next steps run: make build && make load && make deploy"

#  Create kind cluster 
up:
	@if kind get clusters 2>/dev/null | grep -q '^$(CLUSTER_NAME)$$'; then \
	  echo "INFO: Cluster '$(CLUSTER_NAME)' already exists — skipping"; \
	else \
	  echo "INFO: Creating kind cluster '$(CLUSTER_NAME)'..."; \
	  kind create cluster --name $(CLUSTER_NAME) --config kind-config.yaml --wait 90s; \
	fi
	kubectl config use-context kind-$(CLUSTER_NAME)

#  CNPG operator ────────────────────────────────────────────────────────────
CNPG_MINOR   := $(shell echo $(CNPG_VERSION) | cut -d. -f1-2)
CNPG_MANIFEST := https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-$(CNPG_MINOR)/releases/cnpg-$(CNPG_VERSION).yaml

install-cnpg:
	kubectl apply --server-side -f $(CNPG_MANIFEST)
	kubectl rollout status deployment/cnpg-controller-manager \
	  -n cnpg-system --timeout=180s
	@kubectl get crd clusters.postgresql.cnpg.io &>/dev/null \
	  || (echo "ERROR: CNPG CRD not registered" && exit 1)
	@echo "CNPG v$(CNPG_VERSION) installed."

#  Build app image 
build:
# Confirm local source exists before building, to avoid wasting time on a failed build
	@if [ -d ./app/docker/src/explain.depesz.com/ ]; then \
	  echo "INFO: Building app image from local source..."; \
	else \
	  echo "ERROR: Local source not found. Run ./scripts/fetch-upstream.sh first" && exit 1; \
	fi
	docker build -t $(APP_IMAGE) ./app/docker
	@echo "INFO: Built image: $(APP_IMAGE)"
	@echo "INFO: You can view the image details using: docker images $(APP_IMAGE)"
	@echo "INFO: Next steps run: make load && make deploy"

load:
	kind load docker-image $(APP_IMAGE) --name $(CLUSTER_NAME)

#  Deploy  and apply kustomize overlay
deploy:
	@echo "Deploying overlay: $(ENV)"
	kustomize build k8s/overlays/$(ENV) | kubectl apply -f -
	./scripts/wait-for-cluster.sh
	kubectl rollout status deployment/explain-app -n $(NAMESPACE) --timeout=600s
	@echo ""
	@echo "INFO: Deployed. Run: make port-forward"

#  Configure port forwarding to the app and database 
port-forward:
	@echo "Forwarding explain-app → http://localhost:8080  (Ctrl+C to stop)"
	kubectl port-forward svc/explain-app 8080:80 -n $(NAMESPACE)

port-forward-db:
	@echo "INFO: Forwarding Postgres primary → localhost:5432  (Ctrl+C to stop)"
	kubectl port-forward svc/pg-explain-rw 5432:5432 -n $(NAMESPACE)

#  Display status of the cluster, CNPG cluster, and pods 
status:
	@echo "=== CNPG Cluster ==="
	kubectl get cluster pg-explain -n $(NAMESPACE) 2>/dev/null \
	  || echo "  (cluster not deployed yet)"
	@echo ""
	@echo "=== Nodes ==="
	kubectl get nodes -o wide 2>/dev/null \
	  || echo "  (cluster not created yet)"
	@echo ""
	@echo "=== Pods ==="
	kubectl get pods -n $(NAMESPACE) -o wide 2>/dev/null \
	  || echo "  (namespace not found)"
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -n $(NAMESPACE) 2>/dev/null \
	  || echo "  (namespace not found)"

test-failover:
	./scripts/test-failover.sh

#  Teardown the cluster when done
teardown:
	./scripts/teardown.sh
