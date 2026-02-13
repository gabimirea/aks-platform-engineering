# AKS1 CNPG Platform

This package documents CloudNativePG on `aks1` managed through Argo CD.

## Scope

- CNPG operator application: `aks1-cnpg-operator`
- CNPG demo database application: `aks1-cnpg-demo`
- PostgreSQL cluster: `cnpg-demo/app-db`

## Current state

- Cluster: `aks1`
- Namespace: `cnpg-demo`
- PostgreSQL instances: `1` (not HA)
- Primary service: `app-db-rw`
- Read service: `app-db-ro`
- Read-only service: `app-db-r`
- Storage class: `default` (`disk.csi.azure.com`, `StandardSSD_ZRS`)

## Related Argo CD apps

- `aks1` (CAPI managed AKS cluster)
- `aks1-cnpg-operator`
- `aks1-cnpg-demo`

## What is documented

- Architecture and resource model
- Access and smoke tests
- Day-2 operations and runbooks
