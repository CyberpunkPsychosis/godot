# Downloads the pinned official Godot editor for Windows and verifies its
# SHA-512 against the official checksum manifest published with the release.
param(
    [string]$Version = "4.4.1-stable",
    [string]$OutDir = "$PSScriptRoot\dist"
)
$ErrorActionPreference = "Stop"

$zipName = "Godot_v${Version}_win64.exe.zip"
$base = "https://github.com/godotengine/godot/releases/download/$Version"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "Downloading $zipName ..."
Invoke-WebRequest "$base/$zipName" -OutFile "$OutDir\$zipName"
Invoke-WebRequest "$base/SHA512-SUMS.txt" -OutFile "$OutDir\SHA512-SUMS.txt"

$expected = (Select-String -Path "$OutDir\SHA512-SUMS.txt" -Pattern ([regex]::Escape($zipName)) |
    ForEach-Object { ($_.Line -split '\s+')[0] }) | Select-Object -First 1
if (-not $expected) { throw "Checksum for $zipName not found in SHA512-SUMS.txt" }

$actual = (Get-FileHash "$OutDir\$zipName" -Algorithm SHA512).Hash.ToLower()
if ($actual -ne $expected.ToLower()) {
    throw "SHA-512 mismatch for $zipName`nexpected: $expected`nactual:   $actual"
}
Write-Host "Checksum OK"

Expand-Archive -Path "$OutDir\$zipName" -DestinationPath $OutDir -Force
Get-ChildItem $OutDir -Filter "Godot*"
Write-Host "Godot editor extracted to $OutDir"
