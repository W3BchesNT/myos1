use64

CURSOR_W = 12
CURSOR_H = 19

cursor_sprite:
    db 2,2,0,0,0,0,0,0,0,0,0,0
    db 2,1,2,0,0,0,0,0,0,0,0,0
    db 2,1,1,2,0,0,0,0,0,0,0,0
    db 2,1,1,1,2,0,0,0,0,0,0,0
    db 2,1,1,1,1,2,0,0,0,0,0,0
    db 2,1,1,1,1,1,2,0,0,0,0,0
    db 2,1,1,1,1,1,1,2,0,0,0,0
    db 2,1,1,1,1,1,1,1,2,0,0,0
    db 2,1,1,1,1,1,1,1,1,2,0,0
    db 2,1,1,1,1,1,1,1,1,1,2,0
    db 2,1,1,1,1,1,1,2,2,2,2,2
    db 2,1,1,1,2,1,1,2,0,0,0,0
    db 2,1,1,2,2,1,1,2,0,0,0,0
    db 2,1,2,0,0,2,1,1,2,0,0,0
    db 2,2,0,0,0,2,1,1,2,0,0,0
    db 0,0,0,0,0,0,2,1,1,2,0,0
    db 0,0,0,0,0,0,2,1,1,2,0,0
    db 0,0,0,0,0,0,0,2,2,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0

draw_mouse_cursor:
    lea rsi, [cursor_sprite]    

    xor rcx, rcx                
.loop_y:
    cmp rcx, CURSOR_H
    jge .done

    mov rdx, r9
    add rdx, rcx                
    cmp rdx, 200                
    jge .next_line

    xor rbx, rbx                
.loop_x:
    cmp rbx, CURSOR_W
    jge .next_line

    mov rax, r8
    add rax, rbx                
    cmp rax, 320                
    jge .skip_pixel

    mov al, [rsi]
    cmp al, 0
    je .skip_pixel              

    mov rax, rdx
    imul rax, 320
    add rax, r8
    add rax, rbx
    add rax, 0xA0000

    mov dl, [rsi]
    cmp dl, 1
    je .draw_white
    
    mov byte [rax], 0           ; Черный контур
    jmp .skip_pixel

.draw_white:
    mov byte [rax], 15          ; Белое тело

.skip_pixel:
    inc rsi
    inc rbx
    jmp .loop_x

.next_line:
    inc rcx
    jmp .loop_y

.done:
    ret
