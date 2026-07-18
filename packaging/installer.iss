; Inno Setup script for "Godot AI Console".
; Build via build_installer.ps1 (defines AppVer / GodotVer).
#ifndef AppVer
  #define AppVer "0.1.0"
#endif
#ifndef GodotVer
  #define GodotVer "4.4.1-stable"
#endif

[Setup]
AppId={{8E2B7A10-52C4-4C8B-9B7B-71D3C9A24F55}}
AppName=Godot AI Console
AppVersion={#AppVer}
AppPublisher=AI Console contributors
DefaultDirName={autopf}\GodotAI
DefaultGroupName=Godot AI Console
OutputDir=output
OutputBaseFilename=GodotAI-Setup-{#AppVer}
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes

[Files]
; Godot editor + bridge + docs into the install dir.
Source: "staging\Godot_v{#GodotVer}_win64.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "staging\Godot_v{#GodotVer}_win64_console.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "staging\bridge\*"; DestDir: "{app}\bridge"; Flags: ignoreversion recursesubdirs
Source: "staging\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs
; First project: template with the AI Console plugin pre-enabled, copied into
; the user's documents on install; never overwritten, never uninstalled.
Source: "staging\template\*"; DestDir: "{userdocs}\GodotAI\MyFirstAIProject"; \
  Flags: recursesubdirs onlyifdoesntexist uninsneveruninstall

[Icons]
Name: "{group}\Godot AI Console"; Filename: "{app}\Godot_v{#GodotVer}_win64.exe"; \
  Parameters: "-e --path ""{userdocs}\GodotAI\MyFirstAIProject"""; \
  Comment: "Godot editor with the AI Console panel"
Name: "{group}\Godot (Project Manager)"; Filename: "{app}\Godot_v{#GodotVer}_win64.exe"
Name: "{autodesktop}\Godot AI Console"; Filename: "{app}\Godot_v{#GodotVer}_win64.exe"; \
  Parameters: "-e --path ""{userdocs}\GodotAI\MyFirstAIProject"""; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\Godot_v{#GodotVer}_win64.exe"; \
  Parameters: "-e --path ""{userdocs}\GodotAI\MyFirstAIProject"""; \
  Description: "Launch Godot AI Console now"; Flags: postinstall nowait skipifsilent
