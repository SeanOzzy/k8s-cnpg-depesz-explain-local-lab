# Architecture: cnpg-depesz-explain-local-lab

## Why CloudNativePG instead of a plain StatefulSet?

Running Postgres in Kubernetes with a hand-rolled `StatefulSet` is entirely possible, but you end up owning a lot of sharp edges:

- **Failover**: If the primary pod dies, nothing promotes the standby automatically. You write the logic yourself or use `pg_ctl`/`repmgr`/`Patroni`.
- **Credential rotation**: Postgres superuser passwords in `Secret` objects, manually synced.
- **WAL management**: Archiving to object storage, base backup scheduling - bespoke scripts.
- **Schema bootstrapping**: `initdb` lifecycle, extension creation, initial user grants - all custom `initContainers`.

CloudNativePG (CNPG) is a CNCF-sandbox operator that encodes all of this as a single CRD: `Cluster`. The operator runs a control loop that continuously reconciles the desired state (defined in your `cluster.yaml`) against the actual state in the cluster.

### What the operator manages for you

```
                    ┌─────────────────────────┐
                    │  CNPG Controller Manager │
                    │  (Deployment in          │
                    │   cnpg-system ns)        │
                    └────────────┬────────────┘
                                 │ watches
                    ┌────────────▼────────────┐
                    │  Cluster CRD            │
                    │  (your cluster.yaml)    │
                    └────────────┬────────────┘
                                 │ reconciles
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌────────▼────────┐   ┌──────────▼──────────┐  ┌────────▼────────┐
│  StatefulSet    │   │  Services (rw/ro/r)  │  │  Secrets        │
│  (1 pod/inst.)  │   │                      │  │  (credentials)  │
└────────┬────────┘   └──────────────────────┘  └─────────────────┘
         │
┌────────▼────────┐
│  Pods           │
│  pg-explain-1   │ ← primary
│  pg-explain-2   │ ← hot standby (streaming replication)
└────────┬────────┘
         │
┌────────▼────────┐
│  PVCs           │
│  (1 per pod)    │ ← data survives pod restarts
└─────────────────┘
```

The StatefulSet is an implementation detail - **you never patch it directly**. All changes go through the `Cluster` CRD, and the operator applies them safely (e.g., rolling restarts for parameter changes that require it).

---

## Self-healing mechanics

CNPG uses a lease-based primary election. Each instance runs a sidecar (`instance manager`) that:

1. Holds a Kubernetes `Lease` object while it is primary.
2. Continuously checks `pg_is_in_recovery()` to detect unexpected demotion.
3. On primary failure, the operator selects the replica with the highest LSN and calls `pg_promote()` on it.
4. Updates the `pg-explain-rw` Service selector to point to the new primary.

From the application's perspective, a short connection interruption (typically 10–30s in a local kind cluster) is all that's visible. The `pg-explain-rw` DNS name stays constant.

---

## Kustomize overlay pattern

```
k8s/
├── base/          ← canonical resource definitions, no environment specifics
│   ├── namespace/
│   ├── postgres/  ← Cluster CRD, Secret
│   └── app/       ← Deployment, Service
└── overlays/
    ├── dev/       ← patches: 1 app replica, NodePort, relaxed resource limits
    └── prod/      ← patches: 2 app replicas, ClusterIP, tight resource limits
```

Each overlay's `kustomization.yaml` references `../../base` as its resource and applies `patches`. This means:

- The base is always the source of truth.
- Per-environment changes are expressed as minimal strategic merge patches.
- Adding TODO:'s monitoring is a new overlay that references the same base - zero changes to existing files.

---

## Storage design

CNPG creates one `PersistentVolumeClaim` per Postgres instance, named `{cluster}-{ordinal}`. In a kind cluster, these are backed by the local Docker filesystem via the `standard` StorageClass (using `rancher/local-path-provisioner`).

```
pg-explain-1 pod  ───►  PVC: pg-explain-1  ───►  /var/lib/postgresql/data
pg-explain-2 pod  ───►  PVC: pg-explain-2  ───►  /var/lib/postgresql/data
```

If a pod is deleted (by you or by a node failure), Kubernetes reschedules it and the same PVC is remounted. The data is never lost unless you explicitly delete the PVC.

In a real cloud deployment, you'd swap the StorageClass for `gp3` (EKS), `pd-ssd` (GKE), or `managed-premium` (AKS) - the CNPG config doesn't change.

---

## Security considerations for a production extension

This repo is designed for local learning. Before moving to production:

1. **Secrets**: Replace `secret.yaml` with an External Secrets Operator integration (AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault).
2. **TLS**: Enable CNPG's built-in cert-manager integration for in-cluster Postgres TLS (`spec.certificates`).
3. **Network policies**: Add `NetworkPolicy` resources to restrict the app namespace from reaching anything other than the CNPG services.
4. **Non-root image**: The provided Dockerfile already runs as a non-root user; verify with `kubectl exec -- id`.
5. **WAL archiving**: For real durability, configure `spec.backup.barmanObjectStore` to archive WAL to S3/GCS.

---

## TODO: preview: Monitoring

The CNPG operator exposes a Prometheus `/metrics` endpoint on each instance pod at port 9187. The metrics include:

- `cnpg_pg_stat_activity_count` - connection counts by state
- `cnpg_pg_replication_slots_restart_lsn` - per-slot replication lag
- `cnpg_pg_wal_*` - WAL write/sync throughput
- Standard `pg_stat_bgwriter`, `pg_stat_user_tables` metrics

TODO: adds a `monitoring` overlay with:

```
k8s/overlays/monitoring/
├── kustomization.yaml
├── prometheus/
│   ├── deployment.yaml
│   ├── configmap-scrape.yaml
│   └── service.yaml
├── grafana/
│   ├── deployment.yaml
│   ├── configmap-dashboard.yaml
│   └── service.yaml
└── cnpg-pod-monitor.yaml   ← PodMonitor CRD (if using Prometheus Operator)
```
