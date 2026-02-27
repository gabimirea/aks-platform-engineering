# Portal Services

This folder is reconciled by Argo CD using `gitops/apps/infra/portal-services-argoapp.yaml`.

Each request should be created in a dedicated subfolder under:

- `gitops/apps/infra/portal-services/instances/<request-name>/`

Crossplane manifests in this folder assume Azure `ProviderConfig` named `default`
(or the name selected in the Backstage form).

Backstage template added in this repository will create pull requests with either:

- an Azure Storage Account request, or
- an Azure Virtual Machine request (with required network resources),
  implemented as Crossplane Azure resources.

## Deletion strategy (same GitOps flow)

Deletion follows the same strategy as creation:

1. Open a pull request.
2. Remove the request folder:
   - `gitops/apps/infra/portal-services/instances/<request-name>/`
3. Merge the pull request.

Argo CD will detect removed manifests and prune resources.
Crossplane reconciles deletion of the Azure resources represented by those manifests
(no manual `kubectl delete` required).


