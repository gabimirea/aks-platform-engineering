# AKS1 CNPG Platform

This package documents CloudNativePG on `aks1` managed through Argo CD.

## Scope

- CNPG operator application: `aks1-cnpg-operator`
- CNPG database applications: `aks1-cnpg-demo`, `aks1-cnpg-dev`, `aks1-cnpg-uat`, `aks1-cnpg-prod`
- PostgreSQL cluster: `app-db` per namespace (`cnpg-demo`, `cnpg-dev`, `cnpg-uat`, `cnpg-prod`)

## Environment layout

- Cluster: `aks1`
- Overlays:
  - `overlays/demo` -> `cnpg-demo`
  - `overlays/dev` -> `cnpg-dev`
  - `overlays/uat` -> `cnpg-uat`
  - `overlays/prod` -> `cnpg-prod`
- Instance profile:
  - demo: `1`
  - dev: `1`
  - uat: `2`
  - prod: `3`

## Related Argo CD apps

- `aks1` (CAPI managed AKS cluster)
- `aks1-cnpg-operator`
- `aks1-cnpg-demo`
- `aks1-cnpg-dev`
- `aks1-cnpg-uat`
- `aks1-cnpg-prod`

## What is documented

- Architecture and resource model
- Access and smoke tests
- Day-2 operations and runbooks
