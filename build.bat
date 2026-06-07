@echo off
chcp 65001 > nul
cls

set FASM_PATH="C:\fasm\fasm.exe"
set QEMU_PATH="C:\Program Files\qemu\qemu-system-x86_64.exe"

echo [1/2] Компиляция монолитной x86-64 графической системы...
if exist os-image.bin del os-image.bin
%FASM_PATH% main.asm os-image.bin
if %errorlevel% neq 0 (echo Ошибка FASM & pause & exit)

echo [2/2] Запуск OniOS x64 в QEMU...
%QEMU_PATH% -drive file=os-image.bin,format=raw,index=0,media=disk -boot c -vga std -m 256M

pause
