# Architecture

## Control plane

- Argo CD runs on `gitops-aks`.
- Argo CD cluster registry includes destination cluster `aks1`.
- Application `aks1-cnpg-operator` deploys the CNPG operator to `aks1/cnpg-system`.
- Application `aks1-cnpg-demo` deploys the PostgreSQL `Cluster` resource to `aks1/cnpg-demo`.

## Data plane

- CNPG operator namespace: `cnpg-system`
- PostgreSQL namespace: `cnpg-demo`
- Cluster resource: `postgresql.cnpg.io/v1, kind=Cluster, name=app-db`
- Pod naming: `<cluster>-<instanceIndex>`, current: `app-db-1`

## Services

- `app-db-rw`: read-write endpoint (primary)
- `app-db-ro`: read-only endpoint
- `app-db-r`: read endpoint

## Storage

- PVC: `cnpg-demo/app-db-1`
- StorageClass: `default`
- Provisioner: `disk.csi.azure.com`
- SKU: `StandardSSD_ZRS`
- Requested size: `10Gi`

## HA posture

Current manifest uses `instances: 1`, so this is a single-instance deployment.

For HA, use at least:

- `instances: 2` for basic failover
- `instances: 3` for stronger quorum/failure tolerance
