#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Parameter()]
    [string]$ForwarderIp = "172.22.4.4",

    [Parameter()]
    [ValidateSet("Forest", "Domain", "Legacy")]
    [string]$ReplicationScope = "Forest",

    [Parameter()]
    [string]$CsvPath = (Join-Path -Path $PSScriptRoot -ChildPath "azure-private-dns-zones.csv"),

    [Parameter()]
    [ValidateSet("Commercial", "Government", "China", "All")]
    [string[]]$Cloud = @("All"),

    [Parameter()]
    [switch]$IncludeTemplateZones,

    [Parameter()]
    [string[]]$AdditionalZones
)

$ErrorActionPreference = "Stop"

function Info($Message) { Write-Host "[i] $Message" -ForegroundColor Cyan }
function Ok($Message)   { Write-Host "[+] $Message" -ForegroundColor Green }
function Warn($Message) { Write-Host "[!] $Message" -ForegroundColor Yellow }

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this script in an elevated PowerShell session (Run as Administrator)."
    }
}

Assert-Admin
Import-Module DnsServer -ErrorAction Stop

if (-not (Test-Path -LiteralPath $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

$csvRows = Import-Csv -LiteralPath $CsvPath
if (-not $csvRows -or $csvRows.Count -eq 0) {
    throw "No rows found in CSV: $CsvPath"
}

$selectedClouds = if ($Cloud -contains "All") {
    @("Commercial", "Government", "China")
} else {
    $Cloud
}

$filteredRows = $csvRows | Where-Object {
    $_.zone -and ($selectedClouds -contains $_.cloud)
}

$templateRows = $filteredRows | Where-Object {
    $_.is_template -eq "True" -or $_.is_template -eq "true"
}

$concreteRows = if ($IncludeTemplateZones) {
    $filteredRows
} else {
    $filteredRows | Where-Object { $_.is_template -ne "True" -and $_.is_template -ne "true" }
}

$ZoneNames = @(
    $concreteRows.zone
    $AdditionalZones
) | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Sort-Object -Unique

Info "Forwarder target IP: $ForwarderIp"
Info "Replication scope: $ReplicationScope"
Info "CSV path: $CsvPath"
Info "Clouds: $($selectedClouds -join ', ')"
Info "Zones to process: $($ZoneNames.Count)"

foreach ($zone in $ZoneNames) {
    try {
        $existingZone = Get-DnsServerZone -Name $zone -ErrorAction SilentlyContinue

        if (-not $existingZone) {
            Add-DnsServerConditionalForwarderZone `
                -Name $zone `
                -MasterServers $ForwarderIp `
                -ReplicationScope $ReplicationScope `
                -ErrorAction Stop | Out-Null
            Ok "Created conditional forwarder: $zone -> $ForwarderIp"
            continue
        }

        if ($existingZone.ZoneType -ne "Forwarder") {
            Warn "Skipping '$zone': zone exists but is type '$($existingZone.ZoneType)'."
            continue
        }

        Set-DnsServerConditionalForwarderZone `
            -Name $zone `
            -MasterServers $ForwarderIp `
            -ReplicationScope $ReplicationScope `
            -ErrorAction Stop | Out-Null

        Ok "Updated conditional forwarder: $zone -> $ForwarderIp"
    } catch {
        Warn "Failed for '$zone': $($_.Exception.Message)"
    }
}

if (-not $IncludeTemplateZones -and $templateRows.Count -gt 0) {
    Warn "Template zones in CSV were skipped (use -IncludeTemplateZones to include them):"
    $templateRows.zone | Sort-Object -Unique | ForEach-Object { Warn " - $_" }
}

Ok "Completed."
