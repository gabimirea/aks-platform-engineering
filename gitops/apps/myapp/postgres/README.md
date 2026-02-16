# CloudNativePG GitOps Layout for `aks0`

This folder documents a concrete GitOps blueprint to run PostgreSQL on a dedicated CAPZ-managed AKS cluster (`aks0`) using CloudNativePG (CNPG).

This is a file layout and operating guide only. Files are prepared to be applied later through Argo CD, but creating these files alone does not deploy anything.

## Architecture Intent

- Management cluster: `gitops-aks` (Argo CD control plane)
- Workload DB cluster: `aks0` (created by CAPZ)
- DB operator: CNPG (installed on `aks0`)
- DB workload: CNPG `Cluster` (`app-db`) across `demo`, `dev`, `uat`, and `prod` overlays on `aks0`
- Demo app cluster: `aks1` (separate workload cluster for demo applications)

Flow:
1. `clusters` app (in `gitops-aks`) applies CAPZ manifests under `gitops/clusters/capz`.
2. `aks-appset` creates Argo `Application` `aks0`, which creates the `aks0` Kubernetes cluster.
3. `AKS1-CNPG-Operator-ArgoApp` (legacy filename) installs CNPG operator into `aks0`.
4. `AKS1-CNPG-Demo-ArgoApp` (legacy filename) applies CNPG `Cluster` manifests from `gitops/apps/myapp/postgres/overlays/demo` into `aks0`.
5. `AKS1-CNPG-Dev-ArgoApp`, `AKS1-CNPG-UAT-ArgoApp`, and `AKS1-CNPG-Prod-ArgoApp` (legacy filenames) apply environment overlays for `cnpg-dev`, `cnpg-uat`, and `cnpg-prod`.

## Files in This Blueprint

### Cluster provisioning (CAPZ)

- `gitops/clusters/capz/aks0/aks-appset.yaml`
  - CAPZ ApplicationSet for cluster `aks0`
  - Uses identity/subscription annotation templating from cluster metadata
  - Sets `cluster.labels.environment: db`
  - Includes CAPZ drift ignore rules used in this repo

### Argo apps for DB platform on `aks0`

- `gitops/apps/myapp/AKS1-CNPG-Operator-ArgoApp.yaml`
  - Argo `Application` targeting destination cluster `aks0`
  - Installs CNPG Helm chart (`cloudnative-pg`) in namespace `cnpg-system`
  - Has sync wave `"0"` so operator installs before DB resources

- `gitops/apps/myapp/AKS1-CNPG-Demo-ArgoApp.yaml`
  - Argo `Application` targeting destination cluster `aks0`
  - Deploys manifests from `gitops/apps/myapp/postgres/overlays/demo`
  - Namespace target: `cnpg-demo`
  - Has sync wave `"1"` so it runs after operator app

- `gitops/apps/myapp/AKS1-CNPG-Dev-ArgoApp.yaml`
  - Deploys manifests from `gitops/apps/myapp/postgres/overlays/dev`
  - Namespace target: `cnpg-dev`

- `gitops/apps/myapp/AKS1-CNPG-UAT-ArgoApp.yaml`
  - Deploys manifests from `gitops/apps/myapp/postgres/overlays/uat`
  - Namespace target: `cnpg-uat`

- `gitops/apps/myapp/AKS1-CNPG-Prod-ArgoApp.yaml`
  - Deploys manifests from `gitops/apps/myapp/postgres/overlays/prod`
  - Namespace target: `cnpg-prod`

### CNPG demo manifests

- `gitops/apps/myapp/postgres/overlays/demo/kustomization.yaml`
  - Kustomize entrypoint listing the CNPG demo resources

- `gitops/apps/myapp/postgres/overlays/demo/namespace.yaml`
  - Namespace `cnpg-demo`

- `gitops/apps/myapp/postgres/overlays/demo/secret-superuser.yaml`
  - `kubernetes.io/basic-auth` secret for PostgreSQL superuser
  - Placeholder password (must be replaced)

- `gitops/apps/myapp/postgres/overlays/demo/secret-app.yaml`
  - `kubernetes.io/basic-auth` secret for application user
  - Placeholder password (must be replaced)

- `gitops/apps/myapp/postgres/overlays/demo/cluster.yaml`
  - CNPG `Cluster` named `app-db`
  - PostgreSQL image `ghcr.io/cloudnative-pg/postgresql:16`
  - Single instance (`instances: 1`) for demo
  - Bootstraps database `app`, owner `app`
  - Uses above secrets for superuser/app credentials

### Environment overlays

- `gitops/apps/myapp/postgres/overlays/dev`
  - Inherits from `overlays/demo`
  - Namespace: `cnpg-dev`
  - Default sizing: `instances: 1`, `storage: 10Gi`

- `gitops/apps/myapp/postgres/overlays/uat`
  - Inherits from `overlays/demo`
  - Namespace: `cnpg-uat`
  - Default sizing: `instances: 2`, `storage: 20Gi`

- `gitops/apps/myapp/postgres/overlays/prod`
  - Inherits from `overlays/demo`
  - Namespace: `cnpg-prod`
  - Default sizing: `instances: 3`, `storage: 100Gi`

## Rollout Order (When You Decide to Deploy)

Recommended sequence:
1. If CAPZ optional cluster onboarding is enabled in your environment, apply `gitops/clusters/capz/optional/aks1-argo-applicationset.yaml` on the management cluster.
2. Apply/sync `gitops/clusters/capz/aks0/aks-appset.yaml` and wait until `aks0` cluster is ready.
3. Ensure `aks0` destination cluster is registered in Argo CD on `gitops-aks`.
4. Apply/sync `AKS1-CNPG-Operator-ArgoApp.yaml`.
5. Wait for CNPG operator pods/webhook to be healthy.
6. Apply/sync `AKS1-CNPG-Demo-ArgoApp.yaml`.
7. Verify CNPG `Cluster` and PostgreSQL pod health.

## Customization Points

Before production use, update at least:
- Secrets:
  - `secret-superuser.yaml`
  - `secret-app.yaml`
- CNPG sizing and HA:
  - `cluster.yaml`:
    - `instances`
    - `storage.size`
    - image tag/version
    - backup and monitoring sections
- AKS cluster shape:
  - `gitops/clusters/capz/aks0/aks-appset.yaml`:
    - region, Kubernetes version, VM SKU, pool config

## Security and Operations Notes

- Do not keep real DB passwords in Git.
  - Replace secrets with your standard secret pattern (e.g., External Secrets/Key Vault integration).
- `instances: 1` is demo-only.
  - Use multi-instance for HA in real environments.
- Add backup strategy explicitly for production (object store + retention policy).
- Add `PodMonitor`/metrics and alerts for DB operations.

## Verification Commands (Later, When Deploying)

Management cluster (`gitops-aks`) Argo:
- `kubectl -n argocd get applications`
- `kubectl -n argocd get applicationsets`

Target cluster (`aks0`) CNPG resources:
- `kubectl --context <aks0-context> -n cnpg-system get pods`
- `kubectl --context <aks0-context> -n cnpg-demo get cluster,po,svc,secrets`
- `kubectl --context <aks0-context> -n cnpg-demo describe cluster app-db`

## Rollback / Cleanup Strategy

- Remove `AKS1-CNPG-Demo-ArgoApp.yaml` to remove demo DB resources.
- Remove `AKS1-CNPG-Operator-ArgoApp.yaml` after all CNPG-managed DB resources are gone.
- Remove `gitops/clusters/capz/aks0/aks-appset.yaml` if you want to decommission the `aks0` cluster.
- Ensure Argo finalizers and prune settings match your deletion expectations.
