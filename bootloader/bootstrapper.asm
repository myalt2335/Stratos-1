[BITS 16]
ORG 0x1000

start:
    mov [boot_drive], dl

    mov si, dbg_after_entry
    call print_string

    mov si, debug_real_mode
    call print_string

    call enable_a20
    mov si, debug_a20
    call print_string

    mov si, dbg_before_load
    call print_string
    call load_kernel
    mov si, dbg_after_load
    call print_string

    call write_boot_info
    mov si, wrt_marker
    call print_string

    mov ax, 0x9000
    mov es, ax
    mov di, 0x0200

    mov ax, 0x4F00
    int 0x10
    cmp ax, 0x004F
    jne .no_vbe

    mov ax, 0x4F01
    mov cx, 0x0101 ; 8bpp (640x480)
    mov di, 0x0200
    int 0x10
    cmp ax, 0x004F
    jne .no_vbe

    mov ax, [es:di]
    test al, 1
    jz .no_vbe
    test al, 1 << 7
    jz .no_vbe

    mov ax, 0x4F02
    mov bx, 0x4000 | 0x0101
    int 0x10
    cmp ax, 0x004F
    jne .no_vbe

    mov si, dbg_vbe_set
    call print_string

    mov bx, [es:di + 0x28]
    mov cx, [es:di + 0x2A]
    mov [fb_lo], bx
    mov [fb_hi], cx
    mov byte [vbe_flag], 1
    jmp .vbe_done

.no_vbe:
    mov si, dbg_no_vbe
    call print_string
    mov byte [vbe_flag], 0
    mov word [fb_lo], 0
    mov word [fb_hi], 0

.vbe_done:
    xor ax, ax
    mov es, ax
    mov di, 0x9005
    mov al, [vbe_flag]
    stosb
    mov ax, [fb_lo]
    stosw
    mov ax, [fb_hi]
    stosw

    call switch_to_pm

    mov si, debug_failed_pm
    call print_string
    jmp $

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret
; and they will hear the way you called out my name
enable_a20:
    in al, 0x92
    or al, 2
    out 0x92, al

    call check_a20
    jc .done

    call enable_a20_legacy
    call check_a20
    jc .done

    mov si, a20_fail_msg
    call print_string
    cli
.hang:
    hlt
    jmp .hang

.done:
    ret

check_a20:
    pushf
    cli
    push ds
    push es

    xor ax, ax
    mov ds, ax
    mov es, ax

    mov si, 0x0500
    mov di, 0x1500

    mov al, [ds:si]
    mov bl, [es:di]

    cmp al, bl
    jne .enabled

    not al
    mov [ds:si], al
    mov cl, [es:di]
    cmp al, cl
    jne .enabled

    not al
    mov [ds:si], al

    pop es
    pop ds
    popf
    clc
    ret

.enabled:
    pop es
    pop ds
    popf
    stc
    ret

enable_a20_legacy:
    call wait_input_clear
    mov al, 0xD1
    out 0x64, al
    call wait_input_clear
    mov al, 0xDF
    out 0x60, al
    call wait_input_clear
    ret

wait_input_clear:
.wait:
    in al, 0x64
    test al, 0x02
    jnz .wait
    ret

; they will experience unimaginable wonders.
load_kernel:
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 3
    mov ch, 0
    mov cl, 4
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc .err
    ret
.err:
    mov si, dbg_load_err
    call print_string
    jmp $

write_boot_info:
    xor ax, ax
    mov es, ax
    mov di, 0x9000

    mov al, [boot_drive]
    stosb

    mov ax, 0x1000
    stosw

    mov ax, 2048
    stosw

    ret

switch_to_pm:
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp dword CODE_SEG:init_pm

[BITS 32]
init_pm:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x80000

    call clear_screen

    mov esi, pm_hit
    mov edi, 0xB8000
    call print_pm

    cmp byte [vbe_flag], 1
    jne .no_vbe_draw

    movzx ebx, word [fb_lo]
    movzx ecx, word [fb_hi]
    shl ecx, 16
    or ebx, ecx

    mov edx, 10
    imul edx, 640
    add edx, 10
    add ebx, edx

    mov byte [ebx], 4

.no_vbe_draw:
    jmp dword CODE_SEG:0x10000

clear_screen:
    mov edi, 0xB8000
    mov eax, 0x07200720
    mov ecx, 2000
    rep stosd
    ret

print_pm:
.loop:
    lodsb
    test al, al
    je .done
    mov ah, 0x07
    mov [edi], ax
    add edi, 2
    jmp .loop
.done:
    ret


gdt_start:
    dq 0

    dw 0xFFFF, 0
    db 0x00, 0x9A, 0xFC, 0x00

    dw 0xFFFF, 0
    db 0x00, 0x92, 0xFC, 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ 0x08
DATA_SEG equ 0x10

boot_drive       db 0
vbe_flag         db 0
fb_lo            dw 0
fb_hi            dw 0

dbg_after_entry  db "ENT ", 0
debug_real_mode  db "RM  ", 0
debug_a20        db "A20 ", 0
a20_fail_msg     db "A20F", 0
debug_gdt_loaded db "GDT ", 0
dbg_before_load  db "BLD ", 0
dbg_after_load   db "ALD ", 0
dbg_load_err     db "LDF ", 0
wrt_marker       db "WRT ", 0
dbg_vbe_set      db "VBES", 0
dbg_no_vbe       db "NOVB", 0
debug_failed_pm  db "FAIL ", 0
pm_hit           db "PM OK HERE → STOP", 0

stage2_end:
times 1024 - ($ - $$) db 0
