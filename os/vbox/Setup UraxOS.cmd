@echo off
setlocal EnableExtensions
title UraxOS setup
cd /d "%~dp0"
set "VM=UraxOS alpha"
set "HASH=2afcdb59d44ea0bb7e927e8aa1bc6ed4794cc1bbb563f921bbbcf8286dddedc1"
set "VBM=%ProgramFiles%\Oracle\VirtualBox\VBoxManage.exe"
set "VMDIR=%USERPROFILE%\VirtualBox VMs\%VM%"
echo ============================================
echo   UraxOS alpha - one-click setup
echo ============================================
echo.

rem ---------- 1) VirtualBox ----------
if exist "%VBM%" goto vbok
echo [1/5] VirtualBox is not installed. Downloading it...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $b='https://download.virtualbox.org/virtualbox/'; $v=(Invoke-WebRequest -UseBasicParsing ($b+'LATEST-STABLE.TXT')).Content.Trim(); $f=(Invoke-WebRequest -UseBasicParsing ($b+$v+'/')).Links | ForEach-Object { $_.href } | Where-Object { $_ -match '-Win\.exe$' } | Select-Object -First 1; Invoke-WebRequest -UseBasicParsing ($b+$v+'/'+$f) -OutFile (Join-Path $env:TEMP 'vbox-setup.exe')"
if errorlevel 1 goto vbmanual
echo       Installing VirtualBox. Windows will ask for permission: press Yes.
powershell -NoProfile -Command "Start-Process -FilePath (Join-Path $env:TEMP 'vbox-setup.exe') -ArgumentList '--silent','--ignore-reboot' -Verb RunAs -Wait"
if not exist "%VBM%" goto vbmanual
:vbok
echo [1/5] VirtualBox: OK

rem ---------- 2) Already set up? Just start it ----------
"%VBM%" showvminfo "%VM%" >nul 2>&1
if errorlevel 1 goto prepare
echo [2/5] The UraxOS VM already exists. Starting it...
"%VBM%" startvm "%VM%" >nul
goto done

rem ---------- 3) Join the parts and unzip ----------
:prepare
if exist "UraxOS-alpha\UraxOS-alpha.vmdk" goto haveimg
if exist "UraxOS-alpha.zip" goto check
for %%N in (001 002 003 004 005 006 007 008 009 010) do if not exist "UraxOS-alpha.zip.%%N" (
  echo Part UraxOS-alpha.zip.%%N is missing. Put all 10 parts in this folder, then run me again.
  goto fail
)
echo [2/5] Joining the 10 parts (about 2.4 GB)...
copy /b UraxOS-alpha.zip.001+UraxOS-alpha.zip.002+UraxOS-alpha.zip.003+UraxOS-alpha.zip.004+UraxOS-alpha.zip.005+UraxOS-alpha.zip.006+UraxOS-alpha.zip.007+UraxOS-alpha.zip.008+UraxOS-alpha.zip.009+UraxOS-alpha.zip.010 UraxOS-alpha.zip >nul
if errorlevel 1 goto fail
:check
echo [3/5] Checking the file...
certutil -hashfile UraxOS-alpha.zip SHA256 | find /i "%HASH%" >nul
if errorlevel 1 (
  echo The file is damaged. Download the parts again.
  del /q UraxOS-alpha.zip >nul 2>&1
  goto fail
)
echo       Unzipping...
tar -xf UraxOS-alpha.zip
if errorlevel 1 goto fail
:haveimg

rem ---------- 4) Create the VM ----------
echo [4/5] Creating the "%VM%" virtual machine (copying the disk takes a few minutes)...
"%VBM%" createvm --name "%VM%" --ostype ArchLinux_64 --register >nul || goto fail
"%VBM%" modifyvm "%VM%" --firmware efi --memory 6144 --cpus 4 --graphicscontroller vmsvga --vram 128 --accelerate-3d off --nic1 nat --audio-driver default --audio-enabled on --audio-out on --usb-ohci on --mouse usbtablet --clipboard-mode bidirectional --rtc-use-utc on || goto fail
"%VBM%" storagectl "%VM%" --name SATA --add sata --controller IntelAhci --portcount 1 || goto fail
"%VBM%" clonemedium disk "UraxOS-alpha\UraxOS-alpha.vmdk" "%VMDIR%\UraxOS-alpha-disk.vdi" --format VDI || goto fail
"%VBM%" storageattach "%VM%" --storagectl SATA --port 0 --device 0 --type hdd --medium "%VMDIR%\UraxOS-alpha-disk.vdi" || goto fail
"%VBM%" usbfilter add 0 --target "%VM%" --name "PS4 controller" --vendorid 054C --active yes >nul

rem ---------- 5) Start ----------
echo [5/5] Starting UraxOS...
"%VBM%" startvm "%VM%" >nul
echo.
choice /c YN /m "Setup is done. Delete the downloaded parts and temporary files to free about 7 GB"
if errorlevel 2 goto done
del /q UraxOS-alpha.zip.0* UraxOS-alpha.zip "Join UraxOS*.cmd" >nul 2>&1
rmdir /s /q UraxOS-alpha >nul 2>&1
echo Temporary files deleted.

:done
echo.
echo Done. Next time just run this file again (or open VirtualBox) to start UraxOS.
echo Tip: press Host+F in the VirtualBox window for full screen.
pause
exit /b 0

:vbmanual
echo.
echo Could not install VirtualBox automatically.
echo Install it from https://www.virtualbox.org/wiki/Downloads then run me again.
start "" https://www.virtualbox.org/wiki/Downloads
pause
exit /b 1

:fail
echo.
echo Something went wrong. Take a photo of this window and send it.
pause
exit /b 1
