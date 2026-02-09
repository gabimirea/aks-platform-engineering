Cluster labels and ArgoCD bootstrapping

Why labels matter

The management cluster uses an ApplicationSet (app-of-apps) to install platform addons
(like ArgoCD) into workload clusters. The ApplicationSet selects clusters using
labels such as `enable_argocd=true` or `environment: control-plane`.

How we persist the label

We add a Cluster manifest to the repo so the label is stored in Git. The file
`gitops/clusters/labels/aks0-labels.yaml` contains the required labels for the
`aks0` cluster. When the management ArgoCD syncs `gitops/clusters/...` it will
apply this manifest to the Cluster API object and the ApplicationSet should
pick up the label and install the addons.

Notes

- This assumes the management ArgoCD has an Application synchronizing the
  `gitops/clusters` path. If not, apply the manifest manually or add an
  ArgoCD app to sync it.
- You can also label clusters directly with `kubectl label cluster aks0 enable_argocd=true`.
