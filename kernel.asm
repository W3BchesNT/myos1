org 0x8000
use64

kernel_start:
    mov ax, 0x10            ; Настройка селекторов данных
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x7C00         ; Стабильная точка стека

    ; === 1. Отрисовка графики ОДИН раз при старте ОС ===
    include "gui.asm"

    ; Стартовые координаты курсора (выбираем чистый бордовый фон)
    mov r8d, 100            ; Текущий X
    mov r9d, 20             ; Текущий Y (выше окна, чтобы стирать только бордовый цвет)

; === ГЛАВНЫЙ ЦИКЛ АВТОМАТИЧЕСКОЙ АНИМАЦИИ ===
main_loop:

    ; Рисуем курсор на текущих координатах
    call draw_mouse_cursor

    ; === 2. Безопасная программная задержка (таймаут) ===
    mov ecx, 8000000        ; Уменьшили число, чтобы анимация была плавной
.delay_loop:
    dec ecx
    jnz .delay_loop

    ; === 3. БЕЗОПАСНОЕ ЗАТИРАНИЕ СТАРOГO КУРСОРA ===
    mov edx, r9d            ; EDX - счетчик строк Y
.erase_y:
    mov ecx, r9d
    add ecx, 19             ; Высота курсора
    cmp edx, ecx
    jge .erase_done
    
    mov ebx, r8d            ; EBX - счетчик столбцов X
.erase_x:
    mov ecx, r8d
    add ecx, 12             ; Ширина курсора
    cmp ebx, ecx
    jge .erase_next_line

    ; РАСЧЕТ АДРЕСА БЕЗ ПОРЧИ РЕГИСТРОВ EBX И EDX
    movsxd r10, edx         ; R10 = Y (безопасное расширение знака до 64 бит)
    imul r10, 320           ; R10 = Y * 320
    movsxd r11, ebx         ; R11 = X
    add r10, r11            ; R10 = (Y * 320) + X
    add r10, 0xA0000        ; R10 = Абсолютный адрес пикселя в VGA

    mov byte [r10], 89      ; Возвращаем бордовый цвет Ubuntu (89)

    inc ebx
    jmp .erase_x
.erase_next_line:
    inc edx
    jmp .erase_y

.erase_done:

    ; === 4. Изменение координат (Движение вправо) ===
    add r8d, 2              ; Сдвигаем курсор вправо на 2 пикселя

    ; Если курсор подходит к правому краю экрана, возвращаем назад
    cmp r8d, 290
    jl .no_reset
    mov r8d, 10
.no_reset:

    jmp main_loop           ; Переходим к следующему кадру анимации

; === Подключение внешнего спрайта курсора ===
include "cursor.asm"

times 4096 - ($ - kernel_start) db 0
