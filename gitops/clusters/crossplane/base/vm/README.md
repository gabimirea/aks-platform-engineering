# VM API Abstraction Starter (XRD + Composition)

This folder defines a Crossplane platform API for Linux VMs on Azure:

- `XVMInstance` (composite)
- `VMClaim` (claim)

With this model, the portal should generate one claim object (for example `vmclaim.yaml`) instead of multiple managed resources (`VirtualNetwork`, `Subnet`, `NIC`, `LinuxVirtualMachine`, etc.).

## Files

- `vm-composite-resource-definition.yaml`: defines `VMClaim` schema.
- `vm-composition.yaml`: composes Azure resources from one claim.
- `kustomization.yaml`: bundles both resources.

## How to adopt

1. Deploy this folder with your Crossplane platform app.
2. Update the portal template to emit only:
   - `apiVersion: kubernetes.example.com/v1alpha1`
   - `kind: VMClaim`
3. Replace legacy managed-resource files under:
   - `gitops/apps/infra/portal-services/instances/create-vm/`
4. Rename `vmclaim.yaml.example` to `vmclaim.yaml` (and remove old files).
