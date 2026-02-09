#!/bin/bash
# Deploy AKS Store Demo - Automated Script (Bash version)
# This script deploys the complete AKS Store demo application

echo "Starting AKS Store Demo Deployment..."

# Step 1: Create argocd namespace if it doesn't exist
echo "Step 1: Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Deploy the AKS Store application
echo "Step 2: Deploying AKS Store components..."
kubectl apply -f gitops/apps/myapp/aks-store-complete.yaml

# Step 3: Wait for store-front to be ready
echo "Step 3: Waiting for store-front pod to be ready (up to 5 minutes)..."
kubectl wait --for=condition=ready pod -l app=store-front --timeout=300s 2>/dev/null

# Step 4: Get the LoadBalancer IP
echo "Step 4: Retrieving LoadBalancer IP..."
max_attempts=30
attempts=0
ip=""

while [ $attempts -lt $max_attempts ]; do
    ip=$(kubectl get service store-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$ip" ]; then
        break
    fi
    echo "  Waiting for LoadBalancer IP... (attempt $((attempts + 1))/$max_attempts)"
    sleep 10
    ((attempts++))
done

if [ -n "$ip" ]; then
    echo "✅ Deployment Complete!"
    echo "📊 Application URL: http://$ip"
    echo "You can now visit your web server at: http://$ip"
else
    echo "⚠️  LoadBalancer IP not assigned yet. This may take a few more minutes."
    echo "Run this command to check the IP later:"
    echo "  kubectl get service store-front"
fi

echo ""
echo "Deployment Status:"
kubectl get deployments -l app=store-front,app=order-service,app=product-service
echo ""
echo "Services:"
kubectl get svc store-front,order-service,product-service
