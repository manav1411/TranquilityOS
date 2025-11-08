[bits 16]
[org 0x7c00]

KERNEL_OFFSET equ 0x1000

; Store boot drive (should be 0 for floppy)
mov [BOOT_DRIVE], dl

; Setup stack
mov bp, 0x9000
mov sp, bp

; Print loading message
mov bx, MSG_LOAD_KERNEL
call print_string

; Load kernel - try multiple approaches
mov bx, KERNEL_OFFSET
mov dh, 4  ; Load more sectors to be safe
call disk_load

; Print success message
mov bx, MSG_SUCCESS
call print_string

; Switch to protected mode
cli
lgdt [gdt_descriptor]

mov eax, cr0
or eax, 1
mov cr0, eax

jmp CODE_SEG:start_32bit

[bits 32]
start_32bit:
    ; Set up data segments
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Set up stack
    mov ebp, 0x90000
    mov esp, ebp
    
    ; Jump to kernel
    jmp KERNEL_OFFSET

; Improved disk load function
[bits 16]
disk_load:
    pusha
    
    ; Try multiple times in case of transient errors
    mov cx, 3
.retry:
    push cx
    
    mov ah, 0x02
    mov al, dh
    mov ch, 0x00    ; cylinder 0
    mov dh, 0x00    ; head 0  
    mov cl, 0x02    ; sector 2 (after boot sector)
    mov dl, [BOOT_DRIVE]
    
    int 0x13
    jnc .success    ; If no carry, success!
    
    ; Reset disk system between retries
    mov ah, 0x00
    mov dl, [BOOT_DRIVE]
    int 0x13
    
    pop cx
    loop .retry
    
    ; All retries failed
    mov bx, DISK_ERROR_MSG
    call print_string
    jmp $
    
.success:
    pop cx
    popa
    ret

print_string:
    pusha
    mov ah, 0x0e
.loop:
    mov al, [bx]
    cmp al, 0
    je .done
    int 0x10
    inc bx
    jmp .loop
.done:
    popa
    ret

; GDT
gdt_start:
    dq 0x0
gdt_code:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10011010b
    db 11001111b
    db 0x0
gdt_data:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10010010b
    db 11001111b
    db 0x0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; Data
BOOT_DRIVE db 0
MSG_LOAD_KERNEL db "Loading kernel...", 0x0D, 0x0A, 0
MSG_SUCCESS db "Kernel loaded! Switching to 32-bit...", 0x0D, 0x0A, 0
DISK_ERROR_MSG db "Disk read failed!", 0x0D, 0x0A, 0

times 510 - ($-$$) db 0
dw 0xaa55