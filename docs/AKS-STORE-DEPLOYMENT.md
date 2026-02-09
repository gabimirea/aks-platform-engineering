# AKS Store Demo - Deployment Guide

This guide explains how to deploy the AKS Store demo application for testing purposes.

## Quick Start (One Command)

The fastest way to deploy everything:

```powershell
# Run from the repository root
./deploy-aks-store.ps1
```

This script will:
1. Create the `argocd` namespace
2. Deploy all AKS Store components (store-front, order-service, product-service)
3. Wait for the application to be ready
4. Display the external IP address to access the application

## Manual Deployment Steps

If you prefer manual control or the script doesn't work, follow these steps:

### Step 1: Create the argocd namespace
```bash
kubectl create namespace argocd
```

### Step 2: Deploy all services at once
```bash
kubectl apply -f gitops/apps/myapp/aks-store-complete.yaml
```

### Step 3: Verify deployments
```bash
# Check if pods are running
kubectl get pods -l app=store-front
kubectl get pods -l app=order-service
kubectl get pods -l app=product-service
```

### Step 4: Wait for LoadBalancer IP
```bash
# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=store-front --timeout=300s

# Get the external IP
kubectl get service store-front
```

### Step 5: Access the application
Once the LoadBalancer has an EXTERNAL-IP, visit it in a browser:
```
http://<EXTERNAL-IP>
```

## Files Involved

| File | Purpose |
|------|---------|
| `gitops/apps/myapp/aks-store-complete.yaml` | Complete manifest with all services |
| `gitops/apps/myapp/AKSStoreDemoArgoApp.yaml` | ArgoCD Application (for GitOps deployment) |
| `deploy-aks-store.ps1` | Automated PowerShell deployment script |

## Troubleshooting

### Pod is in CrashLoopBackOff
Check the logs:
```bash
kubectl logs -l app=store-front
```

Common issues:
- Services not yet deployed (order-service, product-service must exist)
- LoadBalancer IP not available (wait a few more minutes)

### LoadBalancer IP stays <pending>
This is normal in non-cloud environments. Check if the service is created:
```bash
kubectl get svc store-front -o wide
```

### Access application but it's not responding
Make sure all three services are running:
```bash
kubectl get deployments
kubectl get svc
```

## Cleanup

To remove all deployed resources:
```bash
kubectl delete deployment store-front order-service product-service
kubectl delete svc store-front order-service product-service
```

Or delete the namespace:
```bash
kubectl delete namespace argocd
```

## Using with ArgoCD

If you want ArgoCD to manage this deployment:

1. Update [gitops/apps/myapp/AKSStoreDemoArgoApp.yaml](AKSStoreDemoArgoApp.yaml) to point to your repository
2. Apply the ArgoCD Application:
   ```bash
   kubectl apply -f gitops/apps/myapp/AKSStoreDemoArgoApp.yaml
   ```

## What Gets Deployed

The deployment includes:

### 1. **Product Service**
- Image: `ghcr.io/azure-samples/aks-store-demo/product-service:latest`
- Port: 3002
- Purpose: Returns product information for the store

### 2. **Order Service**
- Image: `ghcr.io/azure-samples/aks-store-demo/order-service:latest`
- Port: 3000
- Purpose: Handles order processing
- Dependencies: Requires RabbitMQ (not included - optional)

### 3. **Store Front (Web UI)**
- Image: `ghcr.io/azure-samples/aks-store-demo/store-front:latest`
- Port: 8080 (exposed as 80 via LoadBalancer)
- Purpose: Vue.js web application for customers
- Dependencies: Requires order-service and product-service

## Environment Variables

The services use these environment variables (all pre-configured):

| Service | Variable | Value |
|---------|----------|-------|
| order-service | ORDER_QUEUE_HOSTNAME | rabbitmq |
| order-service | ORDER_QUEUE_PORT | 5672 |
| store-front | VUE_APP_ORDER_SERVICE_URL | http://order-service:3000/ |
| store-front | VUE_APP_PRODUCT_SERVICE_URL | http://product-service:3002/ |

## Reference

- Source: https://github.com/Azure-Samples/aks-store-demo
- Microsoft Learn Guide: https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli
