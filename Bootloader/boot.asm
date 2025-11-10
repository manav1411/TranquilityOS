[bits 16]
[org 0x7C00]
jmp start
%include "./bootloader/print.inc"


; GDT setup
gdt_start:
    dq 0x0000000000000000   ; Null
gdt_code:
    dq 0x00CF9A000000FFFF   ; Code segment, 0-4gb, ring 0
gdt_data:
    dq 0x00CF92000000FFFF   ; Data segment, 0-4gb, ring 0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1      ; gdt max size limit
    dd gdt_start                    ; gdt base address^

CODE_SEG equ gdt_code - gdt_start   ; code seg offset from gdt start
DATA_SEG equ gdt_data - gdt_start   ; data seg offset from gdt start


; 32-bit entry point
[bits 32]
start32:
    mov ax, DATA_SEG
    mov ds, ax              ; sets data seg registers to our DATA_SEG address
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov ss, ax              ; starts stack at DATA_SEG address
    mov esp, 0x90000        ; stack top, grows down from 0x90000
    jmp KERNEL_OFFSET       ; jump to kernel entry
[bits 16]


; main function
start:
    mov [BOOT_DRIVE], dl    ; saves boot address

    mov bp, 0x7C00          ; stack grows down from 0x7C00
    mov sp, bp

    ; Load kernel (e.g., 4 sectors starting from LBA 2)
    mov ah, 0x02            ; read sectors
    mov al, 4               ; num of sectors (adjustable!)
    mov ch, 0x00            ; cylinder
    mov cl, 0x02            ; sector number (starts from 1)
    mov dh, 0x00            ; head
    mov dl, [BOOT_DRIVE]    
    mov bx, KERNEL_OFFSET   ; offset
    int 0x13                ; interrupt to access the CHS^

    cli                     ; disables interrupts
    lgdt [gdt_descriptor]   ; loads the gdt
    mov eax, cr0
    or eax, 1
    mov cr0, eax            ; enables protected mode
    jmp CODE_SEG:start32    ; sets up data, stack, and jmps to kernel




KERNEL_OFFSET equ 0x1000    ; kernel addr (loaded from 0x1000:0000)
BOOT_DRIVE db 0

times 510 - ($-$$) db 0     ; padding to 512 bytes
dw 0xAA55                   ; boot signature