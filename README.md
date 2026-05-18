# cnpg-depesz-explain-local-lab

**Running explain.depesz.com on Kubernetes (locally, for free) with CloudNativePG**

A companion repository for the blog series:

- **Part 1** (this post): Local Kubernetes with kind, CloudNativePG for self-healing stateful PostgreSQL, and a containerised deployment of [explain.depesz.com](https://gitlab.com/depesz/explain.depesz.com).
- **TODO:** *(coming)*: Prometheus + Grafana monitoring and alerting on top of the same stack.

---

## What you'll build

```
┌─────────────────────────────────────────────────────────────┐
│  kind cluster ("explain-cluster")                           │
│                                                             │
│  ┌──────────────────────┐   ┌──────────────────────────┐   │
│  │  explain-app         │   │  CloudNativePG           │   │
│  │  Deployment          │──▶│  Cluster "pg-explain"    │   │
│  │  (depesz/explain)    │   │  ├─ Primary (rw)         │   │
│  │                      │   │  └─ Replica  (ro)        │   │
│  └──────────────────────┘   └──────────────────────────┘   │
│                                      │                      │
│                              PersistentVolumeClaim          │
│                              (survives pod restarts)        │
└─────────────────────────────────────────────────────────────┘
         │
    kind port-forward / NodePort
         │
    http://localhost:8080
```

### Why these tools?

| Tool | Why |
|---|---|
| **kind** | Kubernetes-in-Docker — no VM, no cloud cost, full k8s API |
| **CloudNativePG** | Postgres-native operator: self-healing, WAL archiving, switchover, PVC-backed storage |
| **Kustomize** | Layered config without Helm complexity; base + overlay pattern makes the TODO: extension trivial |
| **explain.depesz.com** | The de facto standard for visualising `EXPLAIN ANALYZE` output |

---

## Prerequisites

```bash
# macOS
brew install kind kubectl kustomize

# Linux (adjust arch as needed)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x kind && sudo mv kind /usr/local/bin/

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

Verify:
```bash
kind version       # >= 0.23
kubectl version --client
kustomize version  # >= 5.x
docker info        # Docker daemon must be running
```

---

## Quick start

```bash
git clone https://github.com/SeanOzzy/cnpg-depesz-explain-local-lab
cd cnpg-depesz-explain-local-lab

# 1. Create the cluster and install the CNPG operator
make bootstrap

# 2. Fetch the upstream app source, build and load the image into kind
./scripts/fetch-upstream.sh
make build
make load

# 3. Deploy everything
make deploy          # defaults to ENV=dev

# 4. Open the app
make port-forward
# → http://localhost:8080
```

All `make` targets are self-documenting — run `make` with no arguments to see the full list.
The `scripts/` wrappers remain available if you prefer to call them directly.

---

## Repository layout

```
cnpg-depesz-explain-local-lab/
├── README.md                    ← you are here
├── Makefile                     ← primary interface: make bootstrap / deploy / test-failover
├── docs/
│   ├── architecture.md          ← deep-dive on design decisions
│   └── extending-monitoring.md  ← preview of TODO:
├── scripts/
│   ├── bootstrap.sh             ← create kind cluster + install CNPG operator
│   ├── fetch-upstream.sh        ← clone explain.depesz.com source before docker build
│   ├── deploy.sh                ← kustomize build + kubectl apply
│   ├── port-forward.sh          ← convenience wrapper
│   ├── teardown.sh              ← full cleanup
│   ├── wait-for-cluster.sh      ← poll CNPG cluster readiness
│   └── test-failover.sh         ← delete primary pod, watch CNPG recover
├── app/
│   └── docker/
│       ├── Dockerfile           ← containerises explain.depesz.com (Perl/Plack)
│       ├── plack-app.psgi       ← PSGI entry-point wrapping the CGI app
│       ├── .dockerignore
│       └── src/                 ← populated by scripts/fetch-upstream.sh (git-ignored)
│           └── explain.depesz.com/
├── k8s/
│   ├── base/
│   │   ├── namespace/
│   │   │   └── namespace.yaml
│   │   ├── postgres/
│   │   │   ├── cluster.yaml     ← CloudNativePG Cluster CRD
│   │   │   ├── secret.yaml      ← superuser + app credentials
│   │   │   └── kustomization.yaml
│   │   ├── app/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       ├── dev/
│       │   └── kustomization.yaml   ← 1 replica, NodePort, debug log level
│       └── prod/
│           └── kustomization.yaml   ← 2 replicas, ClusterIP, resource limits
└── .github/
    └── workflows/
        └── lint.yaml            ← kustomize build lint on PR
```

---

## Step-by-step walkthrough

### 1. Bootstrapping the cluster

`scripts/bootstrap.sh` does three things:

1. Creates a kind cluster from `kind-config.yaml` (exposes port 8080 on your host)
2. Installs the CloudNativePG operator via its published manifest
3. Waits for the operator pod to become `Ready`

```bash
./scripts/bootstrap.sh
```

CloudNativePG installs a set of CRDs into the cluster — most importantly `clusters.postgresql.cnpg.io`. The operator watches for objects of that type and does the actual work of bootstrapping Postgres, managing WAL, handling failover, etc.

### 2. The CloudNativePG `Cluster` resource

`k8s/base/postgres/cluster.yaml` is the heart of this setup. Key fields:

```yaml
spec:
  instances: 2           # primary + 1 hot-standby
  storage:
    size: 1Gi            # PVC per instance — survives pod restarts
  postgresql:
    parameters:
      shared_buffers: "128MB"
      max_connections: "100"
  bootstrap:
    initdb:
      database: explain
      owner: explain_app
      secret:
        name: pg-explain-app-secret
```

The operator creates a `StatefulSet` under the hood, but you **never touch the StatefulSet directly** — the operator reconciles it. If you delete a pod, it comes back. If the primary fails, the operator promotes the standby automatically.

### 3. Service discovery

CNPG creates two `Services` for your cluster automatically:

| Service | DNS name | Use |
|---|---|---|
| Read/Write | `pg-explain-rw.explain.svc` | Primary — app writes here |
| Read-Only | `pg-explain-ro.explain.svc` | Replicas — useful for reporting |
| Any | `pg-explain-r.explain.svc` | Any alive instance |

The app `Deployment` references `pg-explain-rw` via environment variables derived from the CNPG-generated `Secret`.

### 4. The application container

`app/docker/Dockerfile` builds explain.depesz.com from source:

```dockerfile
FROM perl:5.38-slim
# ... installs CPAN deps, clones the app, wires DATABASE_URL
```

The app reads `DATABASE_URL` from an env var. We inject this from the Kubernetes `Secret` that CNPG creates (format: `postgresql://user:pass@host/db`).

### 5. Deploying

```bash
./scripts/deploy.sh dev     # uses k8s/overlays/dev
./scripts/deploy.sh prod    # uses k8s/overlays/prod
```

Internally this runs:
```bash
kustomize build k8s/overlays/${ENV} | kubectl apply -f -
```

### 6. Self-healing demo

```bash
# Watch pods in another terminal
kubectl get pods -n explain -w

# Run the failover script — it identifies the current primary by its
# cnpg.io/instanceRole=primary label (correct regardless of pod ordinal),
# deletes it, then waits for the operator to elect a new primary.
make test-failover

# Or call the script directly
./scripts/test-failover.sh
```

---

## Extending to TODO: (Monitoring)

The overlay pattern makes this straightforward. TODO: will add a `monitoring` overlay that patches in:

- `PodMonitor` for CNPG's built-in Prometheus metrics endpoint
- A Prometheus `Deployment` with a `ConfigMap` for scrape config
- A Grafana `Deployment` pre-loaded with the official [CNPG Grafana dashboard](https://github.com/cloudnative-pg/grafana-dashboards)
- `PrometheusRule` resources for alerting on replication lag, connection count, and WAL write throughput

Preview in `docs/extending-monitoring.md`.

---

## Troubleshooting

```bash
# CNPG operator logs
kubectl logs -n cnpg-system deploy/cnpg-controller-manager --tail=50

# Cluster status
kubectl describe cluster -n explain pg-explain

# App pod logs
kubectl logs -n explain deploy/explain-app

# Connect directly to Postgres
kubectl exec -n explain -it pg-explain-1 -- psql -U explain_app explain
```

---

## Licence

MIT. The explain.depesz.com application itself is BSD-3-Clause (Hubert Lubaczewski).
