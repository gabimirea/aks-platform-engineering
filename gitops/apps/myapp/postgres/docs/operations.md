# Operations

## Prerequisites

- `kubectl` context set to `aks1`
- Access to `argocd` on `gitops-aks` for app health checks

## Health checks

```bash
kubectl get pods -n cnpg-system
kubectl get clusters.postgresql.cnpg.io -A
kubectl get pods -n cnpg-demo
kubectl get svc -n cnpg-demo
kubectl get pods -n cnpg-dev
kubectl get svc -n cnpg-dev
kubectl get pods -n cnpg-uat
kubectl get svc -n cnpg-uat
kubectl get pods -n cnpg-prod
kubectl get svc -n cnpg-prod
```

## Smoke test

```bash
kubectl exec -n cnpg-demo app-db-1 -- psql -U postgres -d postgres -c "select now();"
kubectl exec -n cnpg-demo app-db-1 -- psql -U postgres -d postgres -c "create table if not exists smoke(id int); insert into smoke values (1); select * from smoke;"
```

## Storage inspection

```bash
kubectl get pvc -n cnpg-demo
kubectl get pvc -n cnpg-dev
kubectl get pvc -n cnpg-uat
kubectl get pvc -n cnpg-prod
kubectl get storageclass default -o yaml
```

## Argo app checks

```bash
kubectl -n argocd get applications
kubectl -n argocd get application aks1-cnpg-operator
kubectl -n argocd get application aks1-cnpg-demo
kubectl -n argocd get application aks1-cnpg-dev
kubectl -n argocd get application aks1-cnpg-uat
kubectl -n argocd get application aks1-cnpg-prod
```
