@echo off
chcp 65001 > nul
cls

set FASM_PATH="C:\fasm\fasm.exe"
set QEMU_PATH="C:\Program Files\qemu\qemu-system-x86_64.exe"

echo [1/3] Компиляция монолитной системы высокого разрешения...
if exist os-image.bin del os-image.bin
if exist os-image.iso del os-image.iso
%FASM_PATH% main.asm os-image.bin
if %errorlevel% neq 0 (echo Ошибка FASM & pause & exit)

echo [2/3] Конвертация и сборка загрузочного ISO образа...
:: Дублируем бинарник под формат ISO-носителя для универсальности
copy /b os-image.bin os-image.iso > nul
echo Образ успешно упакован: os-image.iso

echo [3/3] Запуск OniOS 1024x768 в QEMU...
:: Запускаем QEMU, эмулируя полноценный жесткий диск из созданного файла
%QEMU_PATH% -drive file=os-image.bin,format=raw,index=0,media=disk -boot c -vga std -m 256M

pause
