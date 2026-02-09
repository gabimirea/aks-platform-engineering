# Deploy AKS Store Demo - Automated Script
# This script deploys the complete AKS Store demo application

Write-Host "Starting AKS Store Demo Deployment..." -ForegroundColor Green

# Step 1: Create argocd namespace if it doesn't exist
Write-Host "Step 1: Creating argocd namespace..." -ForegroundColor Yellow
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Step 2: Deploy the AKS Store application
Write-Host "Step 2: Deploying AKS Store components..." -ForegroundColor Yellow
kubectl apply -f gitops/apps/myapp/aks-store-complete.yaml

# Step 3: Wait for store-front to be ready
Write-Host "Step 3: Waiting for store-front pod to be ready (up to 5 minutes)..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=store-front --timeout=300s 2>$null

# Step 4: Get the LoadBalancer IP
Write-Host "Step 4: Retrieving LoadBalancer IP..." -ForegroundColor Yellow
$maxAttempts = 30
$attempts = 0
$ip = $null

while ($attempts -lt $maxAttempts) {
    $ip = kubectl get service store-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ($ip) {
        break
    }
    Write-Host "  Waiting for LoadBalancer IP... (attempt $($attempts + 1)/$maxAttempts)"
    Start-Sleep -Seconds 10
    $attempts++
}

if ($ip) {
    Write-Host "✅ Deployment Complete!" -ForegroundColor Green
    Write-Host "📊 Application URL: http://$ip" -ForegroundColor Cyan
    Write-Host "You can now visit your web server at: http://$ip"
} else {
    Write-Host "⚠️  LoadBalancer IP not assigned yet. This may take a few more minutes." -ForegroundColor Yellow
    Write-Host "Run this command to check the IP later:"
    Write-Host "  kubectl get service store-front" -ForegroundColor Cyan
}

Write-Host "`nDeployment Status:" -ForegroundColor Yellow
kubectl get deployments -l app=store-front,app=order-service,app=product-service
Write-Host "`nServices:" -ForegroundColor Yellow
kubectl get svc store-front,order-service,product-service
