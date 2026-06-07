use64

WIDTH  = 800
HEIGHT = 600

kernel_start:
    ; 1. Заливка заднего фона (Темно-серый рабочий стол)
    mov rdi, r8 
    mov ecx, WIDTH * HEIGHT
    mov eax, 0x00202020 
    rep stosd

    ; 2. Нижняя панель (Taskbar)
    mov rdi, r8
    mov rax, 560        ; Начинаем с 560-й строки (высота 40 пикселей)
    mov rbx, WIDTH * 4
    imul rax, rbx
    add rdi, rax
    mov ecx, WIDTH * 40
    mov eax, 0x00101010 ; Черный цвет панели
    rep stosd

    ; 3. Кнопка "Пуск" (Ярко-синяя)
    mov rsi, 565
draw_btn:
    cmp rsi, 595
    jge draw_gui
    mov rdi, r8
    mov rax, rsi
    mov rbx, WIDTH
    imul rax, rbx
    add rax, 10
    shl rax, 2
    add rdi, rax
    mov ecx, 50
    mov eax, 0x000078D7
    rep stosd
    inc rsi
    jmp draw_btn

draw_gui:
    ; 4. РИСУЕМ СИНЕЕ ОКНО (X=200, Y=150, Ширина=400, Высота=300)
    ; Отрисовка тела окна (Красивый синий цвет: 0x000066CC)
    mov rsi, 150        ; Стартовый Y

.draw_window_body:
    cmp rsi, 450        ; Конечный Y (150 + 300)
    jge .draw_window_header
    
    mov rdi, r8
    mov rax, rsi
    mov rdx, WIDTH
    imul rax, rdx
    add rax, 200        ; Стартовый X = 200
    shl rax, 2
    add rdi, rax

    mov ecx, 400        ; Ширина = 400 пикселей
    mov eax, 0x000066CC ; Цвет: СИНЕЕ ОКНО
    rep stosd
    
    inc rsi
    jmp .draw_window_body

.draw_window_header:
    ; Отрисовка рамки/заголовка окна (Темно-синий топ: 0x00003399, Высота=25)
    mov rsi, 150        ; Опять сверху вниз на 25 пикселей

.draw_window_header_loop:
    cmp rsi, 175        ; Верхняя плашка высотой 25px
    jge kernel_halt
    
    mov rdi, r8
    mov rax, rsi
    mov rdx, WIDTH
    imul rax, rdx
    add rax, 200
    shl rax, 2
    add rdi, rax

    mov ecx, 400
    mov eax, 0x00003399 ; Темно-синий заголовок окна
    rep stosd
    
    inc rsi
    jmp .draw_window_header_loop

kernel_halt:
    hlt
    jmp kernel_halt

align 512
