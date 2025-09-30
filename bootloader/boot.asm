[BITS 16]
ORG 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7000

    mov [boot_drive], dl

    mov si, msg_stage1
    call print_string
    mov si, nl
    call print_string

    mov cx, 3

disk_read_attempt:
    mov ax, 0x0000
    mov es, ax
    mov bx, 0x1000
    mov ah, 0x02
    mov al, 2
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13

    jnc disk_read_success
    dec cx
    jnz disk_read_attempt

    mov si, disk_msg
    call print_string
    mov si, nl
    call print_string
    jmp $

disk_read_success:
    mov si, msg_loaded
    call print_string
    mov si, nl
    call print_string

    lgdt [gdt_descriptor]

    mov si, msg_gdt
    call print_string
    mov si, nl
    call print_string

    jmp 0x0000:0x1000

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

boot_drive db 0

msg_stage1 db "STAGE1", 0
msg_loaded db "STLS", 0
disk_msg   db "STLF", 0
msg_gdt    db "GDTL", 0
nl         db 0x0D, 0x0A, 0

gdt_start:
    dq 0

    dw 0xFFFF, 0x0000
    db 0x00
    db 10011010b
    db 11001111b
    db 0x00

    dw 0xFFFF, 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 510-($-$$) db 0
dw 0xAA55

