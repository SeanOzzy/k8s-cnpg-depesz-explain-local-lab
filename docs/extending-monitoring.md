# TODO: Preview: Adding Prometheus + Grafana

> **Status**: This document is a forward-looking design guide. The implementation will be published as the TODO: blog post.

---

## What we're adding

TODO: adds observability to the same kind cluster without modifying any existing manifests. We'll use the Kustomize overlay pattern introduced in Part 1 to layer in:

1. **Prometheus** - scrapes CNPG's built-in metrics endpoint
2. **Grafana** - pre-loaded with the official CNPG dashboard
3. **Alerting rules** - fires on replication lag, connection saturation, and WAL stall

---

## CNPG's built-in metrics

CloudNativePG ships a `postgres_exporter`-compatible metrics endpoint on every instance pod at port `9187`. No sidecar, no additional installation - it's baked in.

Metrics categories exposed:

```
# PostgreSQL activity
cnpg_pg_stat_activity_count{datname, state, wait_event_type}
cnpg_pg_stat_database_*

# Replication
cnpg_pg_replication_*
cnpg_pg_replication_slots_*

# WAL
cnpg_pg_wal_buffers_full_total
cnpg_pg_wal_bytes_written_total

# Background writer
cnpg_pg_stat_bgwriter_*

# Tables (per database)
cnpg_pg_stat_user_tables_*
cnpg_pg_statio_user_tables_*

# CNPG-specific
cnpg_collector_up
cnpg_collector_postgres_version
cnpg_collector_last_collection_error
```

---

## Planned overlay structure

```
k8s/overlays/monitoring/
├── kustomization.yaml
├── namespace.yaml                     # monitoring namespace
├── prometheus/
│   ├── clusterrole.yaml               # needs pod/endpoint list permissions
│   ├── clusterrolebinding.yaml
│   ├── serviceaccount.yaml
│   ├── configmap-prometheus.yaml      # scrape_configs targeting explain namespace
│   ├── deployment.yaml
│   ├── pvc.yaml                       # retain metrics across restarts
│   └── service.yaml
└── grafana/
    ├── configmap-datasource.yaml      # auto-provision Prometheus datasource
    ├── configmap-dashboard.yaml       # CNPG official dashboard JSON
    ├── deployment.yaml
    └── service.yaml
```

This overlay will be applied *on top of* the Part 1 dev or prod overlay:

```bash
# Hypothetical TODO: deploy command
kustomize build k8s/overlays/monitoring | kubectl apply -f -
```

---

## Scrape config (preview)

```yaml
scrape_configs:
  - job_name: cnpg-instances
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: [explain]
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_cnpg_io_cluster]
        action: keep
        regex: pg-explain
      - source_labels: [__meta_kubernetes_pod_container_port_number]
        action: keep
        regex: "9187"
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: instance
```

---

## Alerting rules (preview)

```yaml
groups:
  - name: cnpg-explain
    rules:
      - alert: CNPGReplicationLagHigh
        expr: cnpg_pg_replication_slots_restart_lsn > 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Replication slot {{ $labels.slot_name }} has lag"

      - alert: CNPGConnectionSaturation
        expr: |
          cnpg_pg_stat_activity_count{state="active"}
          / cnpg_pg_settings_max_connections > 0.8
        for: 5m
        labels:
          severity: critical

      - alert: CNPGInstanceDown
        expr: cnpg_collector_up == 0
        for: 1m
        labels:
          severity: critical
```

---

## Grafana dashboard

We'll use the official CNPG Grafana dashboard from the [cloudnative-pg/grafana-dashboards](https://github.com/cloudnative-pg/grafana-dashboards) repository. This gives you:

- Instance health overview (primary/standby status)
- WAL write throughput over time
- Active connection breakdown by state
- Replication lag timeline
- Cache hit ratio
- Autovacuum activity

The dashboard JSON will be baked into a `ConfigMap` and auto-provisioned via Grafana's `/etc/grafana/provisioning/dashboards` mechanism.

---

## ETA

The TODO: post and implementation will follow once the Part 1 feedback cycle completes. Watch the repository for the `feat/monitoring` branch.
