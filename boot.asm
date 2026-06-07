org 0x7C00
use16

boot_start:
    ; Инициализация сегментов памяти
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    mov [boot_disk_id], dl   ; Сохраняем номер диска, который дал BIOS

    ; Функция чтения секторов BIOS (int 0x13 / AH=02h)
    mov ah, 0x02
    mov al, 8                ; Читаем 8 секторов с диска (запас под большой код ядра)
    mov ch, 0                ; Цилиндр 0
    mov cl, 2                ; Начинаем читать со 2-го сектора (сразу за бутом)
    mov dh, 0                ; Головка 0
    mov dl, [boot_disk_id]
    
    ; Загружаем ядро в память по адресу 0x1000:0000 (физический 0x10000)
    mov bx, 0x1000
    mov es, bx
    xor bx, bx               ; Смещение 0
    int 0x13
    jc boot_error            ; Если ошибка чтения диска — зависнуть

    ; Передаем управление загруженному графическому ядру
    jmp 0x1000:0000

boot_error:
    cli
    hlt
    jmp $

boot_disk_id db 0

; Выравнивание загрузчика строго до 512 байт
times 510-($-$$) db 0
dw 0xAA55
