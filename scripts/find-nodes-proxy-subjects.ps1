#!/usr/bin/env pwsh
# Detect subjects with explicit nodes/proxy-like grants

$ErrorActionPreference = "Stop"

function Info($msg) { Write-Host "[i] $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "[+] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Div()      { Write-Host "---------------------------------------------------------------------" -ForegroundColor DarkGray }

Ok "Scanning for nodes/proxy permissions..."
Write-Host ""
Write-Host "NOTE: This script only finds explicit nodes/proxy-style grants by parsing ClusterRole YAML/JSON."
Write-Host "It does NOT detect inherited permissions from cluster-admin or aggregated wildcards."
Write-Host "For comprehensive coverage, use: https://github.com/aquasecurity/kubectl-who-can"
Write-Host ""

# Get ClusterRoles containing nodes/proxy, nodes/*, or *
$clusterRoles = (kubectl get clusterroles -o json | ConvertFrom-Json).items
$roles = @()

foreach ($cr in $clusterRoles) {
    foreach ($rule in ($cr.rules | Where-Object { $_ })) {
        $resources = @($rule.resources)
        if ($resources -contains "nodes/proxy" -or $resources -contains "nodes/*" -or $resources -contains "*") {
            $roles += $cr.metadata.name
            break
        }
    }
}
$roles = $roles | Sort-Object -Unique

if (-not $roles) {
    Info "No matching ClusterRoles found."
    exit 0
}

Div
Ok "Checking ClusterRoleBindings"

$crbs = (kubectl get clusterrolebindings -o json | ConvertFrom-Json).items
$crbFindings = foreach ($role in $roles) {
    foreach ($crb in $crbs) {
        if ($crb.roleRef.name -eq $role) {
            foreach ($s in @($crb.subjects)) {
                if ($null -ne $s) {
                    [pscustomobject]@{
                        Kind      = $s.kind
                        Namespace = if ($s.namespace) { $s.namespace } else { "-" }
                        Name      = $s.name
                        Role      = $role
                    }
                }
            }
        }
    }
}

$crbFindings = $crbFindings | Sort-Object Kind, Namespace, Name, Role -Unique
foreach ($f in $crbFindings) {
    if ($f.Kind -eq "ServiceAccount") {
        Warn ("Vulnerable Service Account: {0}/{1} -> {2}" -f $f.Namespace, $f.Name, $f.Role)
        Write-Host ("  Verify: kubectl auth can-i get nodes --subresource=proxy --as=system:serviceaccount:{0}:{1}" -f $f.Namespace, $f.Name) -ForegroundColor DarkGray
        Write-Host ""
    } else {
        Info ("[{0}] {1}/{2} -> {3}" -f $f.Kind, $f.Namespace, $f.Name, $f.Role)
    }
}

Write-Host ""
Div
Ok "Checking RoleBindings"

$rbs = (kubectl get rolebindings -A -o json | ConvertFrom-Json).items
$rbFindings = foreach ($role in $roles) {
    foreach ($rb in $rbs) {
        if ($rb.roleRef.name -eq $role) {
            $bindingNs = $rb.metadata.namespace
            foreach ($s in @($rb.subjects)) {
                if ($null -ne $s) {
                    [pscustomobject]@{
                        Kind            = $s.kind
                        Namespace       = if ($s.namespace) { $s.namespace } else { "-" }
                        Name            = $s.name
                        Role            = $role
                        BindingNs       = $bindingNs
                    }
                }
            }
        }
    }
}

$rbFindings = $rbFindings | Sort-Object Kind, Namespace, Name, Role, BindingNs -Unique
foreach ($f in $rbFindings) {
    if ($f.Kind -eq "ServiceAccount") {
        Warn ("Vulnerable Service Account: {0}/{1} -> {2} (binding ns: {3})" -f $f.Namespace, $f.Name, $f.Role, $f.BindingNs)
        Write-Host ("  Verify: kubectl auth can-i get nodes --subresource=proxy --as=system:serviceaccount:{0}:{1}" -f $f.Namespace, $f.Name) -ForegroundColor DarkGray
        Write-Host ""
    } else {
        Info ("[{0}] {1}/{2} -> {3} (binding ns: {4})" -f $f.Kind, $f.Namespace, $f.Name, $f.Role, $f.BindingNs)
    }
}

Div
