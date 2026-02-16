# Clean Uninstall: aks0 and/or aks1

This runbook lets you decommission CAPZ-managed workload clusters independently:
- `aks0` only
- `aks1` only
- both clusters

All commands are PowerShell-friendly and should be run from the repo root.

## 1) Use the control-plane kubeconfig

```powershell
$env:KUBECONFIG = "$(Resolve-Path .\terraform\kubeconfig)"
kubectl config current-context
kubectl get nodes
```

## 2) Uninstall `aks0` only

### 2.1 Stop GitOps reconciliation for aks0 resources

`aks0` is part of CAPZ `core` (`gitops/clusters/capz/core`). If parent `clusters` app is active, it may recreate `aks-appset`.

```powershell
# Remove/disable aks0 from git first (recommended), then sync Argo:
# gitops/clusters/capz/core/kustomization.yaml -> remove ../aks0

# Defensive cleanup in cluster:
kubectl -n argocd delete applicationset aks-appset --ignore-not-found
```

### 2.2 Remove Argo apps targeting aks0

```powershell
kubectl -n argocd patch application aks0 --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks0-aks-store-demo --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks0-cnpg-operator --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks0-cnpg-demo --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks0-cnpg-dev --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks0-cnpg-uat --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks0-cnpg-prod --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null

kubectl -n argocd delete application aks0 aks0-aks-store-demo --ignore-not-found
kubectl -n argocd delete application aks0-cnpg-operator aks0-cnpg-demo aks0-cnpg-dev aks0-cnpg-uat aks0-cnpg-prod --ignore-not-found
```

### 2.3 Delete `aks0` CAPI/CAPZ resources

```powershell
kubectl delete cluster aks0 --ignore-not-found
kubectl delete azuremanagedcontrolplane aks0 --ignore-not-found
kubectl delete azuremanagedcluster aks0 --ignore-not-found
kubectl delete machinepool -l "cluster.x-k8s.io/cluster-name=aks0" --ignore-not-found
kubectl delete azuremanagedmachinepool -l "cluster.x-k8s.io/cluster-name=aks0" --ignore-not-found
```

### 2.4 Remove Argo destination cluster secret for aks0

```powershell
# If AKS was recreated and endpoint changed, remove stale secret explicitly (example):
kubectl -n argocd delete secret cluster-aks0-3dzx89ki.hcp.swedencentral.azmk8s.io-3454713729 --ignore-not-found

# Generic cleanup for aks0/aks1 cluster secrets:
kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster -o name |
  Where-Object { $_ -match 'aks0|aks1' } |
  ForEach-Object { kubectl -n argocd delete $_ }
```

### 2.5 Verify `aks0` deletion

```powershell
kubectl get cluster
az aks show -g aks0 -n aks0 --query "provisioningState" -o tsv
```

Expected: `aks0` absent from `kubectl get cluster` and Azure returns `ResourceNotFound`.

## 3) Uninstall `aks1` only

### 3.1 Stop GitOps reconciliation for aks1 resources

If you enabled optional aks1 onboarding, remove/disable this file from Git and sync:
- `gitops/clusters/capz/optional/aks1-argo-applicationset.yaml`

Then cleanup live objects:

```powershell
kubectl -n argocd delete applicationset clusters-capz-aks1 --ignore-not-found
kubectl -n argocd delete applicationset aks1-appset --ignore-not-found
```

### 3.2 Remove Argo apps targeting aks1 (legacy naming)

```powershell
kubectl -n argocd patch application aks1 --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks1-cnpg-operator --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks1-cnpg-demo --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks1-cnpg-dev --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks1-cnpg-uat --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl -n argocd patch application aks1-cnpg-prod --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null

kubectl -n argocd delete application aks1 --ignore-not-found
kubectl -n argocd delete application aks1-cnpg-operator aks1-cnpg-demo aks1-cnpg-dev aks1-cnpg-uat aks1-cnpg-prod --ignore-not-found
```

### 3.3 Delete `aks1` CAPI/CAPZ resources

```powershell
kubectl delete cluster aks1 --ignore-not-found
kubectl delete azuremanagedcontrolplane aks1 --ignore-not-found
kubectl delete azuremanagedcluster aks1 --ignore-not-found
kubectl delete machinepool -l "cluster.x-k8s.io/cluster-name=aks1" --ignore-not-found
kubectl delete azuremanagedmachinepool -l "cluster.x-k8s.io/cluster-name=aks1" --ignore-not-found
```

### 3.4 Remove Argo destination cluster secret for aks1

```powershell
# Generic cleanup for aks0/aks1 cluster secrets:
kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster -o name |
  Where-Object { $_ -match 'aks0|aks1' } |
  ForEach-Object { kubectl -n argocd delete $_ }
```

### 3.5 Verify `aks1` deletion

```powershell
kubectl get cluster
az aks show -g aks1 -n aks1 --query "provisioningState" -o tsv
```

Expected: `aks1` absent from `kubectl get cluster` and Azure returns `ResourceNotFound`.

## 4) If a resource is stuck in `Terminating`

Clear finalizers on cluster and CAPZ resources:

```powershell
kubectl patch cluster aks0 --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl patch cluster aks1 --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl patch azuremanagedcontrolplane aks0 --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl patch azuremanagedcontrolplane aks1 --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl patch azuremanagedcluster aks0 --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
kubectl patch azuremanagedcluster aks1 --type merge -p '{"metadata":{"finalizers":[]}}' 2>$null
```

## 5) Optional: remove Azure PostgreSQL Flexible Server (Backstage DB)

Use this only if you also want to remove the Terraform-managed Azure PostgreSQL server:

```powershell
az postgres flexible-server delete --name backstage-postgresql-server --resource-group aks-gitops --yes
```

## 6) Final verification

```powershell
kubectl get cluster
kubectl -n argocd get applicationsets
kubectl -n argocd get applications
kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
```
