; Inno Setup script for Arpège — builds a single setup.exe installer.
; Compile with: ISCC.exe arpege.iss  (or via ..\installer\build_installer.py)
; Paths are relative to the location of this file (the installer\ folder).

#define MyAppName "Arpège"
; Version: overridable via ISCC /DMyAppVersion=x.y.z[.build] (see
; build_installer.py, which reads it from pubspec.yaml and appends the CI
; build number when present). Fallback value when compiled by hand.
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "Louis Meret"
#define MyAppExeName "arpege.exe"

[Setup]
; AppId uniquely identifies the app (updates / uninstall).
; DO NOT change it between versions, or Windows will treat it as two different apps.
AppId={{44c3dc8e-168f-47d9-a623-efbfe6b4c358}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Arpege
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=..\dist
OutputBaseFilename=Arpege-Setup-{#MyAppVersion}
SetupIconFile=..\assets\Logo.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Flutter app, 64-bit only.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Copies the ENTIRE Release folder (exe + DLLs + data\) — this is what was
; missing when only the .exe was copied to the desktop.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
