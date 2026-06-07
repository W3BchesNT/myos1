org 0x7c00
use16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    ; 1. Настройка стабильной VESA графики (800x600, 32-bit цвет, режим 0x115)
    mov ax, 0x4f02
    mov bx, 0x4115      ; Режим 0x115 (800x600) + флаг LFB (0x4000)
    int 0x10
    cmp ax, 0x004f
    jne vesa_error

    ; Получаем адрес фреймбуфера
    mov ax, 0x4f01
    mov cx, 0x115
    mov di, 0x9000
    int 0x10

    mov eax, [0x9028]
    mov [fb_address], eax

    cli

    ; 2. Переход в 64-битный Long Mode
    mov eax, cr4
    or eax, 1 shl 5     ; Включаем PAE
    mov cr4, eax

    ; Обнуляем таблицы страниц
    mov edi, 0x1000
    mov cr3, edi
    xor eax, eax
    mov ecx, 4096
    rep stosd

    ; Настраиваем таблицы
    mov dword [0x1000], 0x2003
    mov dword [0x2000], 0x3003
    mov dword [0x3000], 0x00000083
    mov dword [0x3008], 0x00200083

    ; Включаем Long Mode
    mov ecx, 0xc0000080
    rdmsr
    or eax, 1 shl 8
    wrmsr

    ; Включаем пейджинг
    mov eax, cr0
    or eax, 1 shl 31 or 1
    mov cr0, eax

    lgdt [gdt64_pointer]

    jmp 0x08:init_64

vesa_error:
    mov ah, 0x0e
    mov al, 'E'
    int 0x10
    hlt

use64
init_64:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Передаем адрес экрана в R8 и прыгаем в GUI ядра
    mov eax, [fb_address]
    mov r8, rax
    jmp kernel_start

align 4
fb_address dd 0

align 8
gdt64:
    dq 0x0000000000000000
    dq 0x00209a0000000000
    dq 0x0000920000000000
gdt64_pointer:
    dw $ - gdt64 - 1
    dq gdt64

times 510-($-$$) db 0
dw 0xaa55

; Ядро подключается сразу за сигнатурой 512 байт
include '..\kernel\kernel.asm'
