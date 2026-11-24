# UraxOS installer: copies the app to %LOCALAPPDATA%\Programs\UraxOS and creates Start menu shortcuts.
$ErrorActionPreference = 'Stop'
$src  = Join-Path $PSScriptRoot 'UraxOS'
$dest = Join-Path $env:LOCALAPPDATA 'Programs\UraxOS'
if (-not (Test-Path (Join-Path $src 'UraxOS.exe'))) {
  Write-Host 'Could not find the UraxOS folder next to this installer. Extract the whole zip first, then run the installer again.' -ForegroundColor Red
  Read-Host 'Press Enter to close'; exit 1
}
Get-Process UraxOS -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
Write-Host "Installing UraxOS to $dest ..."
Copy-Item $src $dest -Recurse -Force
Get-ChildItem $dest -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

$menu = Join-Path ([Environment]::GetFolderPath('Programs')) 'UraxOS'
New-Item -ItemType Directory -Force -Path $menu | Out-Null
$shell = New-Object -ComObject WScript.Shell
$exe = Join-Path $dest 'UraxOS.exe'
function New-Link($name, $target, $arguments, $desc, $workdir = $dest) {
  $l = $shell.CreateShortcut((Join-Path $menu "$name.lnk"))
  $l.TargetPath = $target
  if ($arguments) { $l.Arguments = $arguments }
  $l.WorkingDirectory = $workdir
  $l.IconLocation = "$exe,0"
  $l.Description = $desc
  $l.Save()
}
New-Link 'UraxOS' $exe '' 'UraxOS (fullscreen)'
New-Link 'UraxOS (Window)' $exe '--windowed' 'UraxOS in a window'
New-Link 'Uninstall UraxOS' (Join-Path $dest 'Uninstall UraxOS.cmd') '' 'Remove UraxOS' $env:TEMP

Write-Host ''
Write-Host 'UraxOS is installed. Open the Start menu and type UraxOS.' -ForegroundColor Green
$r = Read-Host 'Start UraxOS now? (Y/N)'
if ($r -match '^[Yy]') { Start-Process $exe }
