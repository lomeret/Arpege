# Compile Arpège pour Windows (.exe).
# À exécuter SUR une machine Windows (les builds desktop Flutter sont host-only).
# Prérequis : Flutter + Visual Studio 2022 « Desktop development with C++ »,
#             et le Mode développeur Windows activé (pdfrx utilise des liens symboliques).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

flutter config --enable-windows-desktop
flutter pub get
flutter build windows --release

Write-Host ""
Write-Host "Build termine : build\windows\x64\runner\Release\"
Write-Host "Executable : build\windows\x64\runner\Release\arpege.exe"
