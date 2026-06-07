org 0x7C00
use16                   ; Начинаем в 16-битном режиме BIOS

start:
    cli                 ; Отключаем прерывания
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00      ; Инициализация стека

    ; === 1. Установка графики VGA 320x200, 256 цветов ===
    mov ax, 0x0013      
    int 0x10

    ; === 2. Обнуляем область памяти под таблицы страниц (0x1000 - 0x5000) ===
    mov edi, 0x1000
    mov cr3, edi        ; Адрес PML4 таблицы загружаем в регистр CR3
    xor eax, eax
    mov ecx, 4096
    rep stosd

    ; === 3. Построение таблиц страниц для x86-64 ===
    mov dword [0x1000], 0x2003      ; PML4 -> PDPT
    mov dword [0x2000], 0x3003      ; PDPT -> PD
    mov dword [0x3000], 0x4003      ; PD -> PT

    ; Заполняем таблицу страниц (PT) для адресации первых 2 Мегабайт памяти
    mov edi, 0x4000
    mov ebx, 0x00000003             ; Стартовый физический адрес 0x0 + флаги
    mov ecx, 512                    ; 512 записей по 4 КБ = 2 МБ
.set_pt_entries:
    mov dword [edi], ebx
    mov dword [edi+4], 0
    add edi, 8
    add ebx, 0x1000                 ; Шаг 4 КБ
    loop .set_pt_entries

    ; === 4. Включение PAE ===
    mov eax, cr4
    or eax, 1 shl 5                 
    mov cr4, eax

    ; === 5. Включение Long Mode в регистре EFER ===
    mov ecx, 0xC0000080             
    rdmsr                           
    or eax, 1 shl 8                 
    wrmsr                           

    ; === 6. Включение страничной адресации и защищенного режима ===
    mov eax, cr0
    or eax, 0x80000001              
    mov cr0, eax

    ; === 7. Загрузка 64-битной GDT ===
    lgdt [gdt_descriptor]

    ; === 8. Дальний прыжок в полноценный 64-битный код ===
    jmp 0x08:long_mode_entry

; --- ГЛОБАЛЬНАЯ ТАБЛИЦА ДЕСКРИПТОРОВ ДЛЯ x86-64 ---
gdt_start:
    dd 0, 0                         
gdt_code:
    dw 0xFFFF, 0x0000, 0x9A00, 0x00AF 
gdt_data:
    dw 0xFFFF, 0x0000, 0x9200, 0x00CF 
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; ============================================================
; НАЧАЛО ПОЛНОЦЕННОГО 64-БИТНОГО РЕЖИМА
; ============================================================
use64
long_mode_entry:
    mov ax, 0x10                    ; Селектор данных
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, 0x7C00                 ; Настраиваем стек

    ; === 9. ЗАЛИВКА ФОНА (БОРДОВЫЙ ЦВЕТ UBUNTU) ===
    mov rdi, 0xA0000                
    mov al, 89                      ; Бордовый пиксель
    mov rcx, 320 * 200              
    rep stosb

    ; === 10. ОТРЕСОВКА ОКНА ТЕРМИНАЛА LINUX ===
    mov rdx, 40                     ; Текущий Y
.loop_y:
    cmp rdx, 160
    jge .draw_cursor_now
    
    mov rbx, 50                     ; Текущий X
.loop_x:
    cmp rbx, 270
    jge .next_line
    
    ; Изолированный расчет пикселя окна (используем r10 вместо раскидывания raк/rdк)
    mov r10, rdx
    imul r10, 320
    add r10, rbx
    add r10, 0xA0000
    
    ; Разделение на шапку и тело
    mov rcx, rdx
    sub rcx, 40
    cmp rcx, 14
    jl .draw_title
    
    mov byte [r10], 0               ; Черное тело терминала
    jmp .pixel_done

.draw_title:
    mov byte [r10], 8               ; Серая шапка окна

    ; Рисуем кнопки Linux (комплиментарные пиксели)
    cmp rbx, 60
    jl .pixel_done
    cmp rbx, 66
    jge .check_orange
    mov byte [r10], 40              ; Красная
    jmp .pixel_done
.check_orange:
    cmp rbx, 70
    jl .pixel_done
    cmp rbx, 76
    jge .check_green
    mov byte [r10], 42              ; Оранжевая
    jmp .pixel_done
.check_green:
    cmp rbx, 80
    jl .pixel_done
    cmp rbx, 86
    jge .pixel_done
    mov byte [r10], 46              ; Зеленая

.pixel_done:
    inc rbx
    jmp .loop_x

.next_line:
    inc rdx
    jmp .loop_y

; === 11. МАТЕМАТИЧЕСКАЯ ОТРИСОВКА СТАТИЧНОГО КУРСОРA ===
.draw_cursor_now:
    ; Рисуем аккуратный указатель (белый треугольник с черной рамкой)
    ; Координаты: X=140, Y=70 (прямо внутри созданного окна терминала)
    mov rdx, 70                     ; Начальный Y
.c_y:
    cmp rdx, 85                    ; Высота 15 пикселей
    jge .system_ok

    mov rbx, 140                    ; Начальный X
.c_x:
    mov rcx, rdx
    sub rcx, 70
    add rcx, 140                    ; Вычисляем наклонную линию
    
    cmp rbx, rcx
    jg .c_next_line

    ; Безопасный расчет адреса пикселя курсора в r10
    mov r10, rdx
    imul r10, 320
    add r10, rbx
    add r10, 0xA0000

    ; Границы треугольника красим в черный контур (0), середину — в белый (15)
    mov r11, rdx
    sub r11, 70
    add r11, 140
    cmp rbx, r11
    je .c_black
    cmp rbx, 140
    je .c_black
    cmp rdx, 84
    je .c_black

    mov byte [r10], 15              ; Белый пиксель
    jmp .c_done
.c_black:
    mov byte [r10], 0               ; Черный пиксель контура
.c_done:
    inc rbx
    jmp .c_x

.c_next_line:
    inc rdx
    jmp .c_y

.system_ok:
    hlt                             ; Процессор засыпает, система стабильна!
    jmp $

; Сигнатура загрузочного сектора (ровно 512 байт)
times 510 - ($ - start) db 0
dw 0xAA55
