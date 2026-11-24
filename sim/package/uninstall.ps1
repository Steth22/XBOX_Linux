# UraxOS uninstaller.
Set-Location $env:TEMP
$dest = Join-Path $env:LOCALAPPDATA 'Programs\UraxOS'
Get-Process UraxOS -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item (Join-Path ([Environment]::GetFolderPath('Programs')) 'UraxOS') -Recurse -Force -ErrorAction SilentlyContinue
$r = Read-Host 'Also delete your saved UraxOS data (users, settings, files)? (Y/N)'
if ($r -match '^[Yy]') { Remove-Item (Join-Path $env:APPDATA 'UraxOS') -Recurse -Force -ErrorAction SilentlyContinue }
Start-Process cmd -ArgumentList "/c timeout /t 5 /nobreak >nul & rmdir /s /q `"$dest`"" -WindowStyle Hidden
Write-Host 'UraxOS was removed.'
Start-Sleep -Seconds 1
