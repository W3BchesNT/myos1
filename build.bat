@echo off
chcp 65001 >nul
cls
color 0D

echo ============================================================
echo       OniOSV1 x86-64 MODULAR LINUX GRAPHIC COMPILER
echo ============================================================

set ROOT_DIR=%~dp0
cd /d "%ROOT_DIR%"

set FASM=%USERPROFILE%\Desktop\FASM\fasm.exe
set VM_NAME=oniOS_Linux_x64
set VBOX_PATH=%PROGRAMFILES%\Oracle\VirtualBox
set VBOX=%VBOX_PATH%\VBoxManage.exe
set FINAL_IMG=%ROOT_DIR%oniOS.img

echo [1/4] Принудительное закрытие процессов VirtualBox...
taskkill /f /im VirtualBox.exe >nul 2>&1
taskkill /f /im VBoxSVC.exe >nul 2>&1
timeout /t 2 >nul

echo [2/4] Компиляция загрузчика и 64-битного ядра через FASM...
if exist boot.bin del /f /q boot.bin >nul 2>&1
if exist kernel.bin del /f /q kernel.bin >nul 2>&1
if exist "%FINAL_IMG%" del /f /q "%FINAL_IMG%" >nul 2>&1

"%FASM%" boot.asm boot.bin
"%FASM%" kernel.asm kernel.bin

if not exist boot.bin (
    color 0C
    echo ERROR: Ошибка сборки boot.asm!
    pause
    exit /b
)
if not exist kernel.bin (
    color 0C
    echo ERROR: Ошибка сборки kernel.asm!
    pause
    exit /b
)

copy /b boot.bin + kernel.bin "%FINAL_IMG%" >nul

echo [3/4] Удаление старой конфигурации ВМ...
"%VBOX%" controlvm "%VM_NAME%" poweroff >nul 2>&1
"%VBOX%" unregistervm "%VM_NAME%" --delete >nul 2>&1

echo [4/4] Создание и запуск чистой x86-64 Linux ВМ...
"%VBOX%" createvm --name "%VM_NAME%" --ostype "Linux_64" --register >nul
"%VBOX%" modifyvm "%VM_NAME%" --cpus 1 --memory 256 --ioapic on --longmode on --boot1 floppy

"%VBOX%" storagectl "%VM_NAME%" --name "FloppyController" --add floppy >nul
"%VBOX%" storageattach "%VM_NAME%" --storagectl "FloppyController" --port 0 --device 0 --type fdd --medium "%FINAL_IMG%" >nul

echo ============================================================
echo SUCCESS! Полноценная модульная x86-64 ОС запущена!
echo ============================================================
"%VBOX%" startvm "%VM_NAME%"

pause
