# CloudNativePG GitOps Layout for `aks1`

This folder documents a concrete GitOps blueprint to run PostgreSQL on a dedicated CAPZ-managed AKS cluster (`aks1`) using CloudNativePG (CNPG).

This is a file layout and operating guide only. Files are prepared to be applied later through Argo CD, but creating these files alone does not deploy anything.

## Architecture Intent

- Management cluster: `gitops-aks` (Argo CD control plane)
- Workload DB cluster: `aks1` (created by CAPZ)
- DB operator: CNPG (installed on `aks1`)
- DB workload: CNPG `Cluster` (demo `app-db`) on `aks1`

Flow:
1. `clusters` app (in `gitops-aks`) applies CAPZ manifests under `gitops/clusters/capz`.
2. `aks1-appset` creates Argo `Application` `aks1`, which creates the `aks1` Kubernetes cluster.
3. `AKS1-CNPG-Operator-ArgoApp` installs CNPG operator into `aks1`.
4. `AKS1-CNPG-Demo-ArgoApp` applies CNPG `Cluster` manifests from `gitops/apps/myapp/postgres/overlays/demo` into `aks1`.

## Files in This Blueprint

### Cluster provisioning (CAPZ)

- `gitops/clusters/capz/aks1-appset.yaml`
  - New CAPZ ApplicationSet for cluster `aks1`
  - Uses same identity/subscription annotation templating as existing `aks0` pattern
  - Sets `cluster.labels.environment: db`
  - Includes CAPZ drift ignore rules used in this repo

### Argo apps for DB platform on `aks1`

- `gitops/apps/myapp/AKS1-CNPG-Operator-ArgoApp.yaml`
  - Argo `Application` targeting destination cluster `aks1`
  - Installs CNPG Helm chart (`cloudnative-pg`) in namespace `cnpg-system`
  - Has sync wave `"0"` so operator installs before DB resources

- `gitops/apps/myapp/AKS1-CNPG-Demo-ArgoApp.yaml`
  - Argo `Application` targeting destination cluster `aks1`
  - Deploys manifests from `gitops/apps/myapp/postgres/overlays/demo`
  - Namespace target: `cnpg-demo`
  - Has sync wave `"1"` so it runs after operator app

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

## Rollout Order (When You Decide to Deploy)

Recommended sequence:
1. Apply/sync `gitops/clusters/capz/aks1-appset.yaml` and wait until `aks1` cluster is ready.
2. Ensure `aks1` destination cluster is registered in Argo CD on `gitops-aks`.
3. Apply/sync `AKS1-CNPG-Operator-ArgoApp.yaml`.
4. Wait for CNPG operator pods/webhook to be healthy.
5. Apply/sync `AKS1-CNPG-Demo-ArgoApp.yaml`.
6. Verify CNPG `Cluster` and PostgreSQL pod health.

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
  - `aks1-appset.yaml`:
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

Target cluster (`aks1`) CNPG resources:
- `kubectl --context <aks1-context> -n cnpg-system get pods`
- `kubectl --context <aks1-context> -n cnpg-demo get cluster,po,svc,secrets`
- `kubectl --context <aks1-context> -n cnpg-demo describe cluster app-db`

## Rollback / Cleanup Strategy

- Remove `AKS1-CNPG-Demo-ArgoApp.yaml` to remove demo DB resources.
- Remove `AKS1-CNPG-Operator-ArgoApp.yaml` after all CNPG-managed DB resources are gone.
- Remove `aks1-appset.yaml` if you want to decommission the `aks1` cluster.
- Ensure Argo finalizers and prune settings match your deletion expectations.
