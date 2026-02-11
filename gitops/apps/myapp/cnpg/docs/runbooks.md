# Runbooks

## Operator app stuck OutOfSync or Missing

Symptoms:

- Argo app `aks1-cnpg-operator` is `OutOfSync/Missing`
- Error on CRD apply due to annotation size

Action:

1. Ensure app has `ServerSideApply=true`:
   - File: `gitops/apps/myapp/AKS1-CNPG-Operator-ArgoApp.yaml`
2. Re-sync app in Argo CD.
3. Validate CRD exists:

```bash
kubectl --context aks1 get crd poolers.postgresql.cnpg.io
```

## Operator pod CrashLoopBackOff

Symptoms:

- Pod in `cnpg-system` restarts
- Logs include `no matches for kind "Pooler"`

Action:

1. Confirm missing CRD:

```bash
kubectl --context aks1 get crd poolers.postgresql.cnpg.io
```

2. Fix operator app sync options (`ServerSideApply=true`), then sync again.

## Scale to HA

Action:

1. Update CNPG Cluster spec to `instances: 3`.
2. Commit and sync via Argo CD.
3. Validate:

```bash
kubectl get clusters.postgresql.cnpg.io -n cnpg-demo
kubectl get pods -n cnpg-demo
```

## Backup and restore planning

This repository currently contains demo deployment only. For production:

1. Add CNPG backup configuration (object store target and schedule).
2. Add restore runbook with tested RTO/RPO.
3. Link backups and runbooks in this TechDocs package.
