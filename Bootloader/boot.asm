[ORG 0x7c00]
    jmp start
    %include "print.inc"

; GDT Setup
gdt_start:
    dq 0x0000000000000000   ; null descriptor
    dq 0x00CF9A000000FFFF   ; code segment
    dq 0x00CF92000000FFFF   ; data segment
gdt_end:

gdt_descriptor:
    dw gdt_end-gdt_start-1  ; define max size limit
    dd gdt_start            ; base address

CODE_SEG equ 0x08
DATA_SEG equ 0x10


init_pm:
    mov ax, DATA_SEG
    mov ds, ax              ; sets data segment registers to our data seg address
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax              ; stack starts at data seg address
    mov esp, 0x9FC00        ; sets up stack

    mov eax, cr0
    or eax, 1
    mov cr0, eax            ; protected mode is now enabled

    jmp CODE_SEG:0x1000     ; jmp to kernel


start:
    cli                     ; disables interrupts
    lgdt [gdt_descriptor]   ; loads the GDT

    mov [boot_drive], dl    ; save boot drive address
    ; load kernel (mem location from sector2 to 0x0000:0x1000)
    mov ah, 0x02            ; read sectors
    mov al, 1               ; num of sectors (ADJUSTABLE!)
    mov ch, 0               ; cylinder
    mov dh, 0               ; head
    mov cl, 2               ; sector number
    mov dl, [boot_drive]
    mov ax, 0x0000
    mov es, ax              ; segment
    mov bx, 0x1000          ; offset
    int 0x13                ; interrupt to access the CHS^
    jc disk_error

    jmp CODE_SEG:init_pm    ; jmp to kernel code

    jmp hang


hang:
    jmp hang


boot_drive db 0

times 510-($-$$) db 0
dw 0xAA55