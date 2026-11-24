@echo off
setlocal
cd /d "%~dp0"
set "VBM=%ProgramFiles%\Oracle\VirtualBox\VBoxManage.exe"
if not exist "%VBM%" (
  echo VirtualBox is not installed. Get it from https://www.virtualbox.org/wiki/Downloads
  pause
  exit /b 1
)
set "VM=UraxOS alpha"
"%VBM%" showvminfo "%VM%" >nul 2>&1 && (
  echo A VM named "%VM%" already exists. Delete it in VirtualBox first if you want a fresh one.
  pause
  exit /b 1
)
echo Creating the "%VM%" virtual machine...
"%VBM%" createvm --name "%VM%" --ostype ArchLinux_64 --register || goto fail
"%VBM%" modifyvm "%VM%" --firmware efi --memory 6144 --cpus 4 --graphicscontroller vmsvga --vram 128 --accelerate-3d off --nic1 nat --audio-driver default --audio-enabled on --audio-out on --usb-ohci on --mouse usbtablet --clipboard-mode bidirectional --rtc-use-utc on || goto fail
"%VBM%" storagectl "%VM%" --name SATA --add sata --controller IntelAhci --portcount 1 || goto fail
"%VBM%" clonemedium disk "UraxOS-alpha.vmdk" "%USERPROFILE%\VirtualBox VMs\%VM%\UraxOS-alpha-disk.vdi" --format VDI || goto fail
"%VBM%" storageattach "%VM%" --storagectl SATA --port 0 --device 0 --type hdd --medium "%USERPROFILE%\VirtualBox VMs\%VM%\UraxOS-alpha-disk.vdi" || goto fail
"%VBM%" usbfilter add 0 --target "%VM%" --name "PS4 controller" --vendorid 054C --active yes || goto fail
echo.
echo Done. Open VirtualBox and start "%VM%".
pause
exit /b 0
:fail
echo Something went wrong. Take a photo of this window and send it.
pause
exit /b 1
