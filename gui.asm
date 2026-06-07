use64

    ; === ЗАЛИВКА ФОНА (БОРДОВЫЙ ЦВЕТ UBUNTU) ===
    mov rdi, 0xA0000                
    mov al, 89                      
    mov rcx, 320 * 200              
    rep stosb

    ; === ОТРЕСОВКА ОКНА ТЕРМИНАЛА LINUX ===
    mov rdx, 40                     ; Начальный Y
.loop_y:
    cmp rdx, 160
    jge .gui_done
    
    mov rbx, 50                     ; Начальный X
.loop_x:
    cmp rbx, 270
    jge .next_line
    
    mov rax, rdx
    imul rax, 320
    add rax, rbx
    add rax, 0xA0000
    
    mov rcx, rdx
    sub rcx, 40
    cmp rcx, 14
    jl .draw_title
    
    mov byte [rax], 0               ; Черное тело терминала
    jmp .pixel_done

.draw_title:
    mov byte [rax], 8               ; Серая шапка окна

    ; Кнопки управления окном (красная, оранжевая, зеленая)
    cmp rbx, 60
    jl .pixel_done
    cmp rbx, 66
    jge .check_orange
    mov byte [rax], 40               
    jmp .pixel_done

.check_orange:
    cmp rbx, 70
    jl .pixel_done
    cmp rbx, 76
    jge .check_green
    mov byte [rax], 42               
    jmp .pixel_done

.check_green:
    cmp rbx, 80
    jl .pixel_done
    cmp rbx, 86
    jge .pixel_done
    mov byte [rax], 46               

.pixel_done:
    inc rbx
    jmp .loop_x

.next_line:
    inc rdx
    jmp .loop_y

.gui_done:
