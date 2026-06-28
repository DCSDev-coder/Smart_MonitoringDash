param(
    [string]$Bind = "10.18.7.50",
    [int]$Port = 8080,
    [string]$Folder = "build/web"
)

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$resolvedFolder = Resolve-Path $Folder -ErrorAction Stop

Write-Host ""
Write-Host "Serving Rack Console demo from: $resolvedFolder"
Write-Host "Open this URL on the INVT ePAD screen:"
Write-Host "  http://$Bind`:$Port"
Write-Host ""

py -m http.server $Port --bind $Bind --directory $resolvedFolder
