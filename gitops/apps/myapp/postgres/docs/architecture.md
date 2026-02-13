# Architecture

## Control plane

- Argo CD runs on `gitops-aks`.
- Argo CD cluster registry includes destination cluster `aks1`.
- Application `aks1-cnpg-operator` deploys the CNPG operator to `aks1/cnpg-system`.
- Applications `aks1-cnpg-demo`, `aks1-cnpg-dev`, `aks1-cnpg-uat`, and `aks1-cnpg-prod` deploy PostgreSQL `Cluster` resources to their target namespaces.

## Data plane

- CNPG operator namespace: `cnpg-system`
- PostgreSQL namespaces: `cnpg-demo`, `cnpg-dev`, `cnpg-uat`, `cnpg-prod`
- Cluster resource per namespace: `postgresql.cnpg.io/v1, kind=Cluster, name=app-db`
- Pod naming: `<cluster>-<instanceIndex>`, current: `app-db-1`

## Services

- `app-db-rw`: read-write endpoint (primary)
- `app-db-ro`: read-only endpoint
- `app-db-r`: read endpoint

## Storage

- PVCs (examples): `cnpg-demo/app-db-1`, `cnpg-dev/app-db-1`, `cnpg-uat/app-db-1`, `cnpg-prod/app-db-1`
- StorageClass: `default`
- Provisioner: `disk.csi.azure.com`
- SKU: `StandardSSD_ZRS`
- Requested size: `10Gi`

## HA posture

Current overlays use:

- demo: `instances: 1`
- dev: `instances: 1`
- uat: `instances: 2`
- prod: `instances: 3`

For HA, use at least:

- `instances: 2` for basic failover
- `instances: 3` for stronger quorum/failure tolerance
