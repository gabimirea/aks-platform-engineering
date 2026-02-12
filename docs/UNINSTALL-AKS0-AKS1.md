# Clean Uninstall: aks0 + aks1 (+ PostgreSQL/CNPG)

This runbook removes the two CAPZ-managed workload clusters (`aks0`, `aks1`) and the PostgreSQL workload on `aks1`.

All commands below are PowerShell-friendly and should be run from the repo root.

## 1) Use the control-plane kubeconfig

```powershell
$env:KUBECONFIG = "$(Resolve-Path .\terraform\kubeconfig)"
kubectl config current-context
kubectl get nodes
```

## 2) Stop GitOps reconciliation first (important)

If you skip this, Argo CD may recreate resources while you are deleting them.

```powershell
# Pause auto-sync on the parent app (if present) so child resources are not recreated.
if (kubectl -n argocd get application clusters 2>$null) {
  kubectl -n argocd patch application clusters --type merge -p '{"spec":{"syncPolicy":null}}'
}

kubectl -n argocd delete applicationset aks-appset aks1-appset --ignore-not-found
kubectl -n argocd delete application aks0 aks1 --ignore-not-found
kubectl -n argocd delete application aks1-cnpg-demo aks1-cnpg-operator --ignore-not-found
```

## 3) Delete workload clusters from Cluster API

```powershell
kubectl delete cluster aks0 --ignore-not-found
kubectl delete cluster aks1 --ignore-not-found
```

Wait until both clusters are gone from the control plane:

```powershell
kubectl get cluster
```

Expected: `aks0` and `aks1` no longer listed.

## 4) Remove any leftover CAPZ resources (if still present)

```powershell
kubectl delete azuremanagedcontrolplane aks0 aks1 --ignore-not-found
kubectl delete azuremanagedcluster aks0 aks1 --ignore-not-found
kubectl delete machinepool -l "cluster.x-k8s.io/cluster-name in (aks0,aks1)" --ignore-not-found
kubectl delete azuremanagedmachinepool -l "cluster.x-k8s.io/cluster-name in (aks0,aks1)" --ignore-not-found
```

## 5) Remove Argo CD destination-cluster secrets for aks0/aks1

```powershell
kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster -o name |
  Where-Object { $_ -match 'aks0|aks1' } |
  ForEach-Object { kubectl -n argocd delete $_ }
```

## 6) Verify Azure resources are deleted

```powershell
az aks show -g aks0 -n aks0 --query "provisioningState" -o tsv
az aks show -g aks1 -n aks1 --query "provisioningState" -o tsv
```

Expected: both commands should return `ResourceNotFound` once deletion is complete.

## 7) Optional: remove Azure PostgreSQL Flexible Server (Backstage DB)

Use this only if you also want to remove the Terraform-managed Azure PostgreSQL server:

```powershell
az postgres flexible-server delete --name backstage-postgresql-server --resource-group aks-gitops --yes
```

## 8) If a resource is stuck in `Terminating`

Remove finalizers on Argo CD applications:

```powershell
kubectl -n argocd patch application aks0 --type merge -p '{"metadata":{"finalizers":[]}}'
kubectl -n argocd patch application aks1 --type merge -p '{"metadata":{"finalizers":[]}}'
kubectl -n argocd patch application aks1-cnpg-operator --type merge -p '{"metadata":{"finalizers":[]}}'
kubectl -n argocd patch application aks1-cnpg-demo --type merge -p '{"metadata":{"finalizers":[]}}'
```

Remove finalizers on CAPI clusters:

```powershell
kubectl patch cluster aks0 --type merge -p '{"metadata":{"finalizers":[]}}'
kubectl patch cluster aks1 --type merge -p '{"metadata":{"finalizers":[]}}'
```

## 9) Final verification

```powershell
kubectl get cluster
kubectl -n argocd get applicationsets
kubectl -n argocd get applications
kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=cluster
```

Expected:
- No `aks0` / `aks1` clusters in `kubectl get cluster`
- No `aks-appset` / `aks1-appset`
- No `aks0` / `aks1` / `aks1-cnpg-*` applications
- No Argo cluster secrets for `aks0` / `aks1`
