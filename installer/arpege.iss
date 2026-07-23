; Script Inno Setup pour Arpège — génère un installeur setup.exe unique.
; Compilation : ISCC.exe arpege.iss  (ou via ..\installer\build_installer.py)
; Les chemins sont relatifs à l'emplacement de ce fichier (dossier installer\).

#define MyAppName "Arpège"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Louis Meret"
#define MyAppExeName "arpege.exe"

[Setup]
; AppId identifie l'app de façon unique (mises à jour / désinstallation).
; NE PAS changer entre deux versions, sinon Windows croit à deux apps différentes.
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
; App Flutter 64 bits uniquement.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Copie TOUT le dossier Release (exe + DLL + data\) — c'est ce qui manquait quand
; tu copiais le .exe seul sur le bureau.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
