# Builds Arpège for Windows (.exe).
# Must be run ON a Windows machine (Flutter desktop builds are host-only).
# Requirements: Flutter + Visual Studio 2022 "Desktop development with C++",
#               and Windows Developer Mode enabled (pdfrx uses symbolic links).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

flutter config --enable-windows-desktop
flutter pub get
flutter build windows --release

Write-Host ""
Write-Host "Build finished: build\windows\x64\runner\Release\"
Write-Host "Executable: build\windows\x64\runner\Release\arpege.exe"
