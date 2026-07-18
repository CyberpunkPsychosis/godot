# Assembles the staging tree and runs Inno Setup to produce
# packaging/output/GodotAI-Setup-<version>.exe.
# Prerequisites: download_godot.ps1 has run; bridge/npm ci has run;
# Inno Setup 6 (ISCC.exe) is installed (preinstalled on GitHub windows runners).
param(
    [string]$GodotVersion = "4.4.1-stable",
    [string]$AppVersion = "0.1.0"
)
$ErrorActionPreference = "Stop"
$repo = Resolve-Path "$PSScriptRoot\.."
$staging = "$PSScriptRoot\staging"
$dist = "$PSScriptRoot\dist"

if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $staging | Out-Null

# 1. Godot editor (byte-identical to the official release).
Copy-Item "$dist\Godot_v${GodotVersion}_win64.exe" $staging
if (Test-Path "$dist\Godot_v${GodotVersion}_win64_console.exe") {
    Copy-Item "$dist\Godot_v${GodotVersion}_win64_console.exe" $staging
}

# 2. Bridge (source + node_modules; runs with the system Node or the docs
#    explain installing Node — kept simple and AV-friendly vs a packed exe).
New-Item -ItemType Directory -Force -Path "$staging\bridge" | Out-Null
Copy-Item "$repo\bridge\src" "$staging\bridge\src" -Recurse
Copy-Item "$repo\bridge\package.json" "$staging\bridge"
Copy-Item "$repo\bridge\node_modules" "$staging\bridge\node_modules" -Recurse

# 3. Project template = the dev project minus dev-only bits.
New-Item -ItemType Directory -Force -Path "$staging\template" | Out-Null
Copy-Item "$repo\project\*" "$staging\template" -Recurse -Exclude ".godot"
Remove-Item "$staging\template\tests" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$staging\template\.godot" -Recurse -Force -ErrorAction SilentlyContinue

# 4. Docs.
New-Item -ItemType Directory -Force -Path "$staging\docs" | Out-Null
Copy-Item "$repo\README.md" "$staging\docs"
Copy-Item "$repo\docs\*" "$staging\docs" -Recurse -ErrorAction SilentlyContinue

# 5. Compile the installer.
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\output" | Out-Null
$iscc = "ISCC.exe"
if (-not (Get-Command $iscc -ErrorAction SilentlyContinue)) {
    $iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
}
& $iscc "/DAppVer=$AppVersion" "/DGodotVer=$GodotVersion" "$PSScriptRoot\installer.iss"
Get-ChildItem "$PSScriptRoot\output"
