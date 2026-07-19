# Installs the AI Console addon into any existing Godot project and enables it
# in that project's project.godot — the per-project equivalent of what the
# installer pre-bakes into MyFirstAIProject.
#
# Interactive (Start Menu shortcut): shows a folder picker + message boxes.
# Scripted (CI / power users):
#   add_ai_to_project.ps1 -Project C:\path\to\project [-AddonSource <dir>]
param(
    [string]$Project = "",
    [string]$AddonSource = ""
)
$ErrorActionPreference = "Stop"

$PluginEntry = "res://addons/ai_console/plugin.cfg"

if (-not $AddonSource) {
    # Installed layout: {app}\tools\add_ai_to_project.ps1 next to {app}\addon\ai_console
    $AddonSource = Join-Path (Split-Path $PSScriptRoot -Parent) "addon\ai_console"
}

$Interactive = $false
if (-not $Project) {
    $Interactive = $true
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the Godot project folder (the one containing project.godot) to add the AI Console to."
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }
    $Project = $dialog.SelectedPath
}

function Finish([string]$Message, [bool]$IsError) {
    if ($Interactive) {
        Add-Type -AssemblyName System.Windows.Forms
        $icon = if ($IsError) { [System.Windows.Forms.MessageBoxIcon]::Error } else { [System.Windows.Forms.MessageBoxIcon]::Information }
        [System.Windows.Forms.MessageBox]::Show($Message, "Godot AI Console", [System.Windows.Forms.MessageBoxButtons]::OK, $icon) | Out-Null
    }
    Write-Host $Message
    if ($IsError) { exit 1 } else { exit 0 }
}

$configPath = Join-Path $Project "project.godot"
if (-not (Test-Path $configPath)) {
    Finish "No project.godot found in:`n$Project`n`nPick the folder that directly contains project.godot." $true
}
if (-not (Test-Path (Join-Path $AddonSource "plugin.cfg"))) {
    Finish "AI Console addon source not found at:`n$AddonSource" $true
}

# 1. Copy (or refresh) the addon into the project.
$destination = Join-Path $Project "addons\ai_console"
New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
if (Test-Path $destination) { Remove-Item $destination -Recurse -Force }
Copy-Item $AddonSource $destination -Recurse

# 2. Enable the plugin in project.godot (idempotent, plain-text patch).
$config = Get-Content $configPath -Raw
if ($config -notmatch [regex]::Escape($PluginEntry)) {
    if ($config -match 'enabled=PackedStringArray\(([^\)]*)\)') {
        $current = $Matches[1].Trim()
        $entry = '"' + $PluginEntry + '"'
        $newList = if ($current -eq "") { $entry } else { "$current, $entry" }
        $config = $config -replace 'enabled=PackedStringArray\([^\)]*\)', "enabled=PackedStringArray($newList)"
    }
    elseif ($config -match '\[editor_plugins\]') {
        $config = $config -replace '\[editor_plugins\]', "[editor_plugins]`r`n`r`nenabled=PackedStringArray(`"$PluginEntry`")"
    }
    else {
        $config = $config.TrimEnd() + "`r`n`r`n[editor_plugins]`r`n`r`nenabled=PackedStringArray(`"$PluginEntry`")`r`n"
    }
    Set-Content -Path $configPath -Value $config -NoNewline
}

Finish "AI Console installed into:`n$Project`n`nReopen the project with Godot AI Console and the AI panel will appear at the bottom of the editor." $false
