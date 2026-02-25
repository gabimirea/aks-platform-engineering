# Demo Services

This folder is reconciled by Argo CD using `gitops/apps/infra/DEMO-SERVICES-ArgoApp.yaml`.

Each request should be created in a dedicated subfolder under:

- `gitops/apps/infra/demo-services/instances/<request-name>/`

Backstage template added in this repository will create pull requests with either:

- an Azure Storage Account request, or
- an Azure Virtual Machine request (with required network resources).

## Deletion strategy (same GitOps flow)

Deletion follows the same strategy as creation:

1. Open a pull request.
2. Remove the request folder:
   - `gitops/apps/infra/demo-services/instances/<request-name>/`
3. Merge the pull request.

Argo CD will detect removed manifests and prune resources.
Because the ASO resources are modeled in the same request folder and linked by owner references,
the Storage Account or VM stack is deleted through reconciliation (no manual `kubectl delete` required).
