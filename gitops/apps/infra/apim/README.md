# APIM + AKS Store (GitOps)

This folder provisions Azure API Management (APIM) using Azure Service Operator (ASO) and publishes an AKS Store endpoint through APIM with subscription-key access.

## What this deploys

From `gitops/apps/infra/apim/base`:

- Azure Resource Group (`ResourceGroup`)
- APIM instance (`Service`)
- APIM API (`Api`) at path `/aksstore`
- APIM Product (`Product`) with `subscriptionRequired: true`
- API to Product association (`ProductApi`)

Overlay `gitops/apps/infra/apim/overlays/dev` patches:

- APIM instance name/publisher metadata
- API backend `serviceUrl` (AKS Store endpoint)

## Prerequisites

- A running cluster with ASO installed and APIM/resource CRDs enabled.
- `kubectl` context pointing to the control-plane cluster where ASO runs.
- Argo CD installed (for GitOps install path).
- AKS Store deployed to workload cluster (`aks1`) from:
  - `gitops/apps/myapp/AKSStoreDemoArgoApp.yaml`
- APIM backend URL available (AKS Store `store-front` or `store-admin` LoadBalancer URL/IP).

## 1) Configure values before install

Update these placeholders:

1. APIM Azure resource name in `gitops/apps/infra/apim/overlays/dev/patch-apim-service.yaml`
   - `spec.azureName: apim-dev-change-me-001`
2. APIM publisher details in `gitops/apps/infra/apim/overlays/dev/patch-apim-service.yaml`
   - `publisherEmail`, `publisherName`
3. Backend URL in `gitops/apps/infra/apim/overlays/dev/patch-apim-api-aks-store.yaml`
   - `spec.serviceUrl: http://<AKS_STORE_LB_IP_OR_DNS>`

Get AKS Store URL:

```bash
kubectl --context aks1 -n pets get svc store-front
```

Use `http://<EXTERNAL-IP>` (or DNS) as `serviceUrl`.

## 2) Install

Choose one method.

### Option A: ArgoCD (recommended)

Apply APIM Argo app:

```bash
kubectl apply -f gitops/apps/infra/APIM-ArgoApp.yaml
```

If AKS Store is not installed yet:

```bash
kubectl apply -f gitops/apps/myapp/AKSStoreDemoArgoApp.yaml
```

### Option B: Direct apply (without Argo app)

```bash
kubectl apply -k gitops/apps/infra/apim/overlays/dev
```

## 3) Verify provisioning

APIM provisioning can take a while (often 20-60+ minutes).

Check ASO resources:

```bash
kubectl get resourcegroups.resources.azure.com -n default
kubectl get services.apimanagement.azure.com -n default
kubectl get apis.apimanagement.azure.com -n default
kubectl get products.apimanagement.azure.com -n default
kubectl get productapis.apimanagement.azure.com -n default
```

Inspect conditions:

```bash
kubectl describe services.apimanagement.azure.com apim-service -n default
kubectl describe apis.apimanagement.azure.com aks-store-api -n default
```

## 4) Test through APIM (subscription key)

The API is configured with `subscriptionRequired: true`. You need a key from APIM.

1. In Azure Portal:
   - Open APIM instance (`azureName` from `patch-apim-service.yaml`)
   - Go to `Products` -> `AKS Store Product`
   - Create/get a subscription and copy the primary key
2. Call APIM gateway:

```bash
curl -H "Ocp-Apim-Subscription-Key: <YOUR_KEY>" \
  "https://<APIM_NAME>.azure-api.net/aksstore/"
```

Expected:
- `200` and AKS Store front page content if backend URL is correct.
- `401`/`403` if key is missing/invalid.

### Health probe endpoint

The API includes a `/health` operation and forwards it to the backend at:

```bash
curl -H "Ocp-Apim-Subscription-Key: <YOUR_KEY>" \
  "https://<APIM_NAME>.azure-api.net/aksstore/health"
```

Expected response:

```json
{"status":"ok","version":"2.1.0"}
```

This validates gateway/key/path and backend reachability together.

## 5) Uninstall

Choose the same method you used for install.

### Option A: If installed via ArgoCD app

Delete Argo application:

```bash
kubectl delete -f gitops/apps/infra/APIM-ArgoApp.yaml
```

Because `resources-finalizer.argocd.argoproj.io` is set in the app, Argo will cascade-delete managed APIM manifests.

Optional: remove AKS Store app too:

```bash
kubectl delete -f gitops/apps/myapp/AKSStoreDemoArgoApp.yaml
```

### Option B: If installed via direct apply

```bash
kubectl delete -k gitops/apps/infra/apim/overlays/dev
```

## 6) Post-uninstall checks

```bash
kubectl get services.apimanagement.azure.com -n default
kubectl get apis.apimanagement.azure.com -n default
kubectl get products.apimanagement.azure.com -n default
kubectl get productapis.apimanagement.azure.com -n default
kubectl get resourcegroups.resources.azure.com -n default
```

Azure-side delete of APIM can also take significant time; resources may remain in deleting state for a while.

## Troubleshooting

- `Api` is not ready:
  - Verify `spec.serviceUrl` points to a reachable AKS Store endpoint.
  - Confirm AKS Store service has external IP and responds directly.
- APIM call returns 404:
  - Ensure API path is `/aksstore` and request URL is `https://<apim>.azure-api.net/aksstore/`.
- APIM call returns 401/403:
  - Ensure `Ocp-Apim-Subscription-Key` is present and valid for `AKS Store Product`.
- Argo is OutOfSync:
  - Confirm `repoURL` and `targetRevision` in `gitops/apps/infra/APIM-ArgoApp.yaml` are correct for your fork/branch.
