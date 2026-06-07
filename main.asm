org 0x7C00
use16

; Константы для адресации памяти кадра
BACKBUFFER_SEG = 0x1000 ; Сегмент в ОЗУ для скрытого буфера кадра (0x10000)

start:
    ; --- Инициализация сегментов памяти ---
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; --- Шаг 1: Включение графики VGA 13h (320x200, 256 цветов) ---
    mov ax, 0x0013
    int 0x10

    ; --- Шаг 2: Переход в Unreal Mode для плоской адресации памяти ---
    cli
    lgdt [gdt_ptr]
    mov eax, cr0
    or al, 1                 ; Включаем защищенный режим на один миг
    mov cr0, eax

    mov ax, 0x08             ; Загружаем плоский дескриптор данных 4 ГБ
    mov fs, ax

    mov eax, cr0
    and al, 0xFE             ; Возвращаемся в 16-битный реальный режим
    mov cr0, eax
    sti

    ; --- Шаг 3: Аппаратная инициализация мыши PS/2 через порты ---
    cli
    mov al, 0xA8             ; Включить порт мыши на контроллере
    out 0x64, al
    call ps2_wait_command

    ; Настройка Sample Rate мыши (чтобы она не летала слишком быстро)
    mov al, 0xD4
    out 0x64, al
    call ps2_wait_command
    mov al, 0xF3             ; Команда: Установить частоту опроса
    out 0x60, al
    call ps2_wait_data
    in al, 0x60              ; Читаем ACK
    
    mov al, 0xD4
    out 0x64, al
    call ps2_wait_command
    mov al, 40               ; Устанавливаем ровно 40 пакетов в секунду (плавный ход)
    out 0x60, al
    call ps2_wait_data
    in al, 0x60              ; Читаем ACK

    ; Разрешаем мыши присылать данные пакетов
    mov al, 0xD4
    out 0x64, al
    call ps2_wait_command
    mov al, 0xF4             ; Команда: Начать передачу пакетов
    out 0x60, al
    call ps2_wait_data
    in al, 0x60              ; Читаем ACK
    sti

    ; Начальные координаты курсора строго по центру экрана
    mov word [mouse_x], 160
    mov word [mouse_y], 100

; =============================================================================
; ГЛАВНЫЙ СВЕРХПЛАВНЫЙ ЦИКЛ БЕЗ МЕРЦАНИЯ И УСKОРЕНИЙ
; =============================================================================
main_loop:
    ; Переключаем ES на скрытый буфер в ОЗУ, чтобы собирать кадр незаметно
    mov ax, BACKBUFFER_SEG
    mov es, ax

    ; 1. Рисуем весь интерфейс в скрытый буфер кадра
    call draw_ui_backbuffer

    ; 2. Рисуем курсор в скрытый буфер кадра
    call draw_cursor_backbuffer

    ; 3. ДВОЙНАЯ БУФЕРИЗАЦИЯ: Мгновенное аппаратное копирование кадра на экран VGA (0xA000)
    push ds
    mov ax, BACKBUFFER_SEG
    mov ds, ax               ; Источник: скрытый буфер ОЗУ
    xor si, si
    mov ax, 0xA000
    mov es, ax               ; Назначение: видеопамять экрана
    xor di, di
    mov cx, 16000            ; Быстро переносим по 4 байта за один проход через movsd
    cld
    db 0x66                  ; Префикс размера 32-битного операнда
    rep movsw                
    pop ds

    ; 4. Опрос контроллера мыши
    in al, 0x64
    test al, 1               ; Проверяем, пришли ли новые данные от мыши
    jz .hardware_delay       ; Если данных нет — просто держим FPS задержкой

    test al, 0x20            ; Данные точно от мыши?
    jz .hardware_delay

    ; Считываем стабильный 3-байтовый пакет данных
    in al, 0x60
    mov [mouse_flags], al    
    
    call ps2_wait_data
    in al, 0x60
    xor cx, cx
    mov cl, al
    mov [mouse_offset_x], cx 
    
    call ps2_wait_data
    in al, 0x60
    xor dx, dx
    mov dl, al
    mov [mouse_offset_y], dx 

    ; Рассчитываем координаты X
    mov al, [mouse_flags]
    test al, 0x10
    jz .x_pos
    or word [mouse_offset_x], 0xFF00
.x_pos:
    mov ax, [mouse_x]
    add ax, [mouse_offset_x]
    cmp ax, 0
    jge .clip_x
    xor ax, ax
.clip_x:
    cmp ax, 314
    jle .save_x
    mov ax, 314
.save_x:
    mov [mouse_x], ax

    ; Рассчитываем координаты Y
    test byte [mouse_flags], 0x20
    jz .y_pos
    or word [mouse_offset_y], 0xFF00
.y_pos:
    mov ax, [mouse_y]
    sub ax, [mouse_offset_y]
    cmp ax, 0
    jge .clip_y
    xor ax, ax
.clip_y:
    cmp ax, 194
    jle .save_y
    mov ax, 194
.save_y:
    mov [mouse_y], ax

    ; --- Проверка клика левой кнопкой мыши по кнопке Close ---
    test byte [mouse_flags], 1
    jz .hardware_delay

    cmp word [mouse_y], 184
    jb .hardware_delay
    cmp word [mouse_x], 2
    jb .hardware_delay
    cmp word [mouse_x], 42
    ja .hardware_delay

    ; Клик сработал — мгновенно тушим QEMU через ACPI
    mov ax, 0x2000
    mov dx, 0x0604
    out dx, ax
    cli
    hlt

.hardware_delay:
    ; Железное ограничение кадров через чтение порта системного таймера PIT (Порт 0x40)
    ; Это полностью убирает дикую скорость мыши и лаги наложения кадров
    mov cx, 5                ; Задаем длительность стабильного шага ожидания
.wait_pit:
    in al, 0x40              ; Читаем текущую фазу колебаний таймера
    mov ah, al
    in al, 0x40
    dec cx
    jnz .wait_pit

    jmp main_loop

; =============================================================================
; ПОДПРОГРАММЫ ОТРИСОВКИ В СКРЫТЫЙ БУФЕР
; =============================================================================
ps2_wait_command:
    in al, 0x64
    test al, 2
    jnz ps2_wait_command
    ret

ps2_wait_data:
    in al, 0x64
    test al, 1
    jz ps2_wait_data
    ret

; Сборка интерфейса Windows 10 внутри оперативной памяти
draw_ui_backbuffer:
    xor di, di
    ; Тёмно-синий фон Windows 10: 320 * 184 = 58 880 пикселей. Цвет 0x34
    mov cx, 58880
    mov al, 0x34
    cld
    rep stosb

    ; Матово-чёрная панель задач: 320 * 16 = 5120 пикселей. Цвет 0x00
    mov cx, 5120
    mov al, 0x00
    rep stosb

    ; Рисуем плоскую красную кнопку [X] Close (X: 2..42, Y: 186..196)
    mov bx, 186
.btn_y:
    mov ax, bx
    mov si, 320
    mul si
    add ax, 2
    mov di, ax
    mov cx, 40
    mov al, 0x28                    ; Фирменный красный Windows 10 Close
    rep stosb
    inc bx
    cmp bx, 197
    jne .btn_y
    ret

; Отрисовка белого курсора мыши 6x6 пикселей внутри оперативной памяти
draw_cursor_backbuffer:
    mov ax, [mouse_y]
    mov si, 320
    mul si
    add ax, [mouse_x]
    mov di, ax                      

    mov al, 0x0F                    ; Чистый белый цвет
    mov bp, 6
.c_y:
    mov cx, 6
.c_x:
    mov [es:di], al
    inc di
    dec cx
    jnz .c_x
    add di, 320 - 6
    dec bp
    jnz .c_y
    ret

; =============================================================================
; СТРУКТУРЫ ДАННЫХ
; =============================================================================
align 16
gdt64:
    dq 0x0000000000000000           ; Нулевой дескриптор
    dq 0x00CF92000000FFFF           ; Плоский сегмент данных 4 ГБ
gdt_ptr:
    dw $-gdt64-1
    dd gdt64

mouse_x         dw 0
mouse_y         dw 0
mouse_flags     db 0
mouse_offset_x  dw 0
mouse_offset_y  dw 0

; Сборка строго в один сектор диска MBR (512 байт)
times 510-($-$$) db 0
dw 0xAA55
