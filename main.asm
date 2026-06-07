org 0x7c00
use16

; =====================================================================
; СЕКТОР 1: ЗАГРУЗЧИК (СТРОГО x86-64 ИНИЦИАЛИЗАЦИЯ)
; =====================================================================
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    mov [boot_drive], dl

    ; 1. Настройка оригинальной VESA графики (1024x768, 32-bit цвет, режим 0x118)
    mov ax, 0x4f02
    mov bx, 0x4118      ; Режим 1024x768 + флаг Линейного Фреймбуфера LFB (0x4000)
    int 0x10

    ; Читаем VBE структуру, чтобы узнать точный физический адрес экрана
    mov ax, 0x4f01
    mov cx, 0x118
    mov di, 0x9000      
    int 0x10

    ; Извлекаем физический адрес экрана (из смещения 40 структуры VBE)
    mov eax, [0x9028]
    mov [fb_address], eax

    ; 2. ЧИТАЕМ ЯДРО ИЗ ВТОРОГО СЕКТОРА ДИСКА В ОЗУ (адрес 0x8000)
    mov ah, 0x02        
    mov al, 15          ; Читаем 15 секторов с запасом
    mov ch, 0           
    mov cl, 2           ; Начинаем со 2-го сектора (сразу за загрузчиком)
    mov dh, 0           
    mov dl, [boot_drive]
    mov bx, 0x8000      
    int 0x13
    jc disk_error

    cli

    ; 3. Быстрое включение PAE (обязательно для x86-64)
    mov eax, cr4
    or eax, 1 shl 5
    mov cr4, eax

    ; 4. ОПТИМИЗИРОВАННАЯ ГЕНЕРАЦИЯ ТАБЛИЦ СТРАНИЦ ПОД ВСЮ ПАМЯТЬ (4 ГБ)
    ; Обнуляем память под таблицы по адресам: PML4=0x1000, PDPT=0x2000, PD=0x3000
    mov edi, 0x1000
    mov cr3, edi
    xor eax, eax
    mov ecx, 3072       
    rep stosd

    ; Связываем таблицы страниц между собой
    mov dword [0x1000], 0x2003      ; PML4 -> PDPT
    mov dword [0x2000], 0x3003      ; PDPT -> Page Directory (PD)

    ; ВАЖНОЕ РЕШЕНИЕ: Мапим ВСЕ 4 ГИГАБАЙТА памяти страницами по 2МБ, 
    ; чтобы процессор x64 видел физический адрес видеокарты QEMU!
    mov edi, 0x3000
    mov eax, 0x00000083             ; Флаги: Present + Writable + 2MB Page
    mov ecx, 2048                   ; 2048 страниц * 2МБ = ровно 4 ГБ замапленной памяти
.build_paging:
    mov [edi], eax
    add edi, 8
    add eax, 0x200000               ; Сдвиг физического адреса на 2 МБ вперед
    dec ecx
    jnz .build_paging

    ; 5. Включаем Long Mode (EFER MSR)
    mov ecx, 0xc0000080
    rdmsr
    or eax, 1 shl 8
    wrmsr

    ; 6. Включаем пейджинг и защищенный режим одновременно (переход в x64)
    mov eax, cr0
    or eax, 1 shl 31 or 1
    mov cr0, eax

    ; Загружаем 64-битную таблицу GDT
    lgdt [gdt64_pointer]

    ; ДАЛЬНИЙ ПРЫЖОК В ИСТИННЫЙ 64-БИТНЫЙ LONG MODE НА АДРЕС НАШЕГО ЯДРА
    jmp 0x08:0x8000

disk_error:
    mov ah, 0x0e
    mov al, 'D'
    int 0x10
    hlt

align 4
fb_address dd 0
boot_drive db 0

align 8
gdt64:
    dq 0x0000000000000000        
    dq 0x00209a0000000000        ; Сегмент кода x86-64 Long Mode (Селектор 0x08)
    dq 0x0000920000000000        ; Сегмент данных x86-64 (Селектор 0x10)
gdt64_pointer:
    dw $ - gdt64 - 1
    dq gdt64

; Ровно 512 байт для первого сектора загрузки
times 510-($-$$) db 0
dw 0xaa55

; =====================================================================
; СЕКТОР 2: КОД ИСТИННОГО 64-БИТНОГО ЯДРА (ПОЛНОЦЕННЫЙ РЕЖИМ USE64)
; =====================================================================
org 0x8000
use64

WIDTH  = 1024
HEIGHT = 768

kernel_start:
    ; Сбрасываем 64-битные сегменты данных
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Извлекаем сохраненный адрес видеопамяти экрана в регистр R8
    mov eax, [fb_address]
    mov r8, rax

    ; 1. ЗАЛИВКА РАБОЧЕГО СТОЛА (Красивый серый цвет Windows 10: 0x002F2F2F)
    mov rdi, r8 
    mov ecx, WIDTH * HEIGHT
    mov eax, 0x002F2F2F 
    rep stosd

    ; 2. РИСУЕМ НИЖНЮЮ ПАНЕЛЬ ЗАДАЧ (Высота 40 пикселей, строки 728..768)
    mov rdi, r8
    mov rax, 728
    mov rbx, WIDTH * 4           ; 4 байта на пиксель в 32-битном True Color
    imul rax, rbx
    add rdi, rax
    mov ecx, WIDTH * 40
    mov eax, 0x00101010          ; Темно-черный цвет панели задач Windows 10
    rep stosd

    ; 3. РИСУЕМ СИНЮЮ КНОПКУ "ПУСК" СЛЕВА НА ПАНЕЛИ (X: 10..60, Y: 733..763)
    mov rsi, 733
.draw_btn_loop:
    cmp rsi, 763
    jge .draw_window
    mov rdi, r8
    mov rax, rsi
    mov rbx, WIDTH
    imul rax, rbx
    add rax, 10                  ; Отступ X = 10 пикселей
    shl rax, 2
    add rdi, rax
    mov ecx, 50                  ; Width = 50px
    mov eax, 0x000078D7          ; Ярко-синий цвет Windows 10
    rep stosd
    inc rsi
    jmp .draw_btn_loop

.draw_window:
    ; 4. РИСУЕМ ТВОЕ СОЧНОЕ СИНЕЕ ОКНО (X: 312..712, Y: 234..534, Размер: 400x300)
    mov rsi, 234
.draw_win_loop:
    cmp rsi, 534
    jge .draw_window_header
    mov rdi, r8
    mov rax, rsi
    mov rbx, WIDTH
    imul rax, rbx
    add rax, 312                 ; Начальный X = 312 пикселей по центру экрана
    shl rax, 2
    add rdi, rax
    mov ecx, 400                 ; Ширина окна = 400px
    mov eax, 0x000066CC          ; Сочный, насыщенный чистый синий цвет окна
    rep stosd
    inc rsi
    jmp .draw_win_loop

.draw_window_header:
    ; 5. РИСУЕМ ТЕМНО-СИНЮЮ ШАПКУ ОКНА (Y: 234..264, Высота 30 пикселей)
    mov rsi, 234
.draw_header_loop:
    cmp rsi, 264
    jge .draw_close_btn
    mov rdi, r8
    mov rax, rsi
    mov rbx, WIDTH
    imul rax, rbx
    add rax, 312
    shl rax, 2
    add rdi, rax
    mov ecx, 400
    mov eax, 0x00003399          ; Классический темно-синий заголовок окна Windows
    rep stosd
    inc rsi
    jmp .draw_header_loop

.draw_close_btn:
    ; 6. РИСУЕМ КРАСНЫЙ КРЕСТИК ЗАКРЫТИЯ ОКНА (X: 686..702, Y: 241..257, Размер 16x16)
    mov rsi, 241
.draw_close_loop:
    cmp rsi, 257
    jge .halt
    mov rdi, r8
    mov rax, rsi
    mov rbx, WIDTH
    imul rax, rbx
    add rax, 686                 ; Позиция крестика справа на шапке
    shl rax, 2
    add rdi, rax
    mov ecx, 16
    mov eax, 0x00E81123          ; Красный цвет крестика Windows 10
    rep stosd
    inc rsi
    jmp .draw_close_loop

.halt:
    hlt
    jmp .halt

align 512
