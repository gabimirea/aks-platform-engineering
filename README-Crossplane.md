# Crossplane Baseline Install for `gitops-aks`

This document describes how to install the current Crossplane-based baseline from scratch and land on the same control-plane state observed on `gitops-aks` on March 5, 2026.

The target baseline is:

- Control-plane cluster context: `gitops-aks`
- Infrastructure provider: `crossplane`
- Argo CD bootstrapped by Terraform
- All current control-plane addon `ApplicationSet` resources installed
- Crossplane XRDs, `Composition`s, and Azure `ProviderConfig` installed
- Backstage installed
- `portal-services` installed

## Baseline State

After a successful install, the live control-plane should contain these Argo CD `ApplicationSet` objects in `argocd`:

- `cluster-addons`
- `addons-argocd`
- `addons-argo-events`
- `addons-argo-rollouts`
- `addons-argo-workflows`
- `addons-cert-manager`
- `addons-cluster-api`
- `addons-crossplane`
- `addons-crossplane-azure-upbound`
- `addons-crossplane-helm`
- `addons-crossplane-kubernetes`
- `addons-kargo`
- `addons-kyverno`
- `clusters`

It should also contain these Argo CD `Application` objects in `argocd`:

- `cluster-addons`
- `addon-gitops-aks-argo-cd`
- `addon-gitops-aks-argo-events`
- `addon-gitops-aks-argo-rollouts`
- `addon-gitops-aks-argo-workflows`
- `addon-gitops-aks-cert-manager`
- `addon-gitops-aks-crossplane`
- `addon-gitops-aks-crossplane-azure-upbound`
- `addon-gitops-aks-crossplane-helm`
- `addon-gitops-aks-crossplane-kubernetes`
- `addon-gitops-aks-kargo`
- `backstage`
- `clusters`
- `portal-services`

Crossplane baseline resources should exist:

- CRDs:
  - `vmclaims.kubernetes.example.com`
  - `aksclusterclaims.kubernetes.example.com`
- `Composition`s:
  - `linux-vm-with-network`
  - `aks-with-virtual-network`
- Azure `ProviderConfig`:
  - `default`

Expected namespaces:

- `argocd`
- `crossplane-system`
- `backstage`
- `cert-manager`
- `argo-events`
- `argo-rollouts`
- `argo-workflows`
- `kargo`
- `workload`

## Source of Truth

These files define the current baseline:

- Terraform bootstrap:
  - `terraform/main.tf`
  - `terraform/bootstrap/addons.yaml`
- Control-plane addon manifests consumed by `cluster-addons`:
  - `gitops/bootstrap/control-plane/addons/oss/*.yaml`
  - `gitops/bootstrap/control-plane/addons/azure/*.yaml`
  - `gitops/bootstrap/control-plane/addons/backstage/app.yaml`
- Crossplane repo-managed baseline:
  - `gitops/bootstrap/control-plane/addons/oss/clusters-argo-applicationset.yaml`
  - `gitops/clusters/crossplane/kustomization.yaml`
  - `gitops/clusters/crossplane/core/kustomization.yaml`
  - `gitops/clusters/crossplane/addons/kustomization.yaml`
- Portal services app:
  - `gitops/apps/infra/portal-services-argoapp.yaml`

## Install Order

### 1. Provision the control-plane cluster with Terraform

From the repository root:

```powershell
cd terraform
terraform init -upgrade
terraform apply `
  -var gitops_addons_org=https://github.com/gabimirea `
  -var infrastructure_provider=crossplane `
  --auto-approve
```

This creates the AKS control-plane cluster and bootstraps Argo CD with the `cluster-addons` `ApplicationSet` from `terraform/bootstrap/addons.yaml`.

### 2. Use the generated kubeconfig

```powershell
$env:KUBECONFIG = (Resolve-Path .\kubeconfig).Path
kubectl config current-context
```

Expected context:

```text
gitops-aks
```

### 3. Wait for the Terraform-seeded Argo bootstrap

Verify that Argo CD is up and that the initial `cluster-addons` `ApplicationSet` exists:

```powershell
kubectl -n argocd get applicationset cluster-addons
kubectl -n argocd get application cluster-addons
```

`cluster-addons` reads the repo path referenced by the cluster secret annotations and recursively applies:

- `gitops/bootstrap/control-plane/addons/oss`
- `gitops/bootstrap/control-plane/addons/azure`
- `gitops/bootstrap/control-plane/addons/backstage`

That bootstrap installs the addon `ApplicationSet`s, Backstage, and the repo-managed `clusters` `ApplicationSet`.

### 4. Confirm the addon baseline

Wait until these are `Synced` and `Healthy`:

```powershell
kubectl -n argocd get applicationset
kubectl -n argocd get application
```

At minimum, you should see:

- `cluster-addons`
- all `addons-*` `ApplicationSet`s listed in the Baseline State section
- `clusters`
- `backstage`

### 5. Let the `clusters` Application install the Crossplane repo layer

No manual apply is required here anymore. The file `gitops/bootstrap/control-plane/addons/oss/clusters-argo-applicationset.yaml` causes Argo CD to generate the `clusters` `Application`, which then syncs:

- `gitops/clusters/crossplane`

That path currently resolves to:

- `gitops/clusters/crossplane/core`
- `gitops/clusters/crossplane/addons`
- `gitops/clusters/crossplane/base/cluster`
- `gitops/clusters/crossplane/base/vm`

Verify:

```powershell
kubectl -n argocd get application clusters
kubectl get crd vmclaims.kubernetes.example.com
kubectl get crd aksclusterclaims.kubernetes.example.com
kubectl get composition
kubectl get providerconfigs.azure.upbound.io
```

Expected objects:

- `vmclaims.kubernetes.example.com`
- `aksclusterclaims.kubernetes.example.com`
- `linux-vm-with-network`
- `aks-with-virtual-network`
- `default`

### 6. Create the Backstage GitHub token secret

If you want Backstage to create pull requests against this repository, create the secret used by the deployed Backstage app.

Do not commit the token to git. Set it from your shell instead:

```powershell
$env:GITHUB_PAT = "<your-github-pat>"
kubectl -n backstage create secret generic backstage-github `
  --from-literal=token="$env:GITHUB_PAT" `
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n backstage rollout restart deploy/backstage
```

Verify:

```powershell
kubectl -n backstage get pods
kubectl -n backstage get secret backstage-github
```

### 7. Install the `portal-services` Argo CD application

The live `gitops-aks` baseline currently includes `portal-services` as a standalone Argo CD `Application`.

Apply it directly:

```powershell
kubectl apply -f .\gitops\apps\infra\portal-services-argoapp.yaml
```

Verify:

```powershell
kubectl -n argocd get application portal-services
```

`portal-services` syncs:

- `gitops/apps/infra/portal-services/instances`

The current baseline keeps that path effectively empty except for `.gitkeep`, so the application should become healthy without provisioning any resource claims by default.

## Verification Checklist

Run these checks from the repository root:

```powershell
kubectl config current-context
kubectl -n argocd get applicationset
kubectl -n argocd get application
kubectl get ns
kubectl -n crossplane-system get pods
kubectl get crd vmclaims.kubernetes.example.com
kubectl get crd aksclusterclaims.kubernetes.example.com
kubectl get composition
kubectl get providerconfigs.azure.upbound.io
kubectl -n backstage get pods
kubectl -n argocd get application portal-services
```

The baseline is correct when:

- context is `gitops-aks`
- every `ApplicationSet` in the Baseline State section exists
- every `Application` in the Baseline State section is `Synced` and `Healthy`
- `crossplane-system` pods are running
- Crossplane claim CRDs and `Composition`s exist
- `ProviderConfig/default` exists
- Backstage pod is running
- `portal-services` is `Synced` and `Healthy`

## Notes About Current Scope

- `gitops/clusters/crossplane/core/kustomization.yaml` currently enables only `../addons`.
- `aks0` and `aks1` remain commented out and are not part of the baseline state.
- `gitops/apps/infra/kustomization.yaml` currently includes only:
  - `apps-deployment.yaml`
  - `portal-services-argoapp.yaml`
- The live cluster does not currently have an `apps-deployment` `Application`; only `portal-services` is part of the active infra app layer.
- Backstage is part of the control-plane addon bootstrap, not a separate infra bootstrap step.

## If You Need to Reconcile Drift

```powershell
kubectl -n argocd annotate application cluster-addons argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd annotate application clusters argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd annotate application portal-services argocd.argoproj.io/refresh=hard --overwrite
```

Then re-check:

```powershell
kubectl -n argocd get application
kubectl -n argocd get applicationset
```
