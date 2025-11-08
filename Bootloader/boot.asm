[ORG 0x7c00]
    jmp start
    %include "print.inc"

; GDT Setup
gdt_start:
    dq 0x0000000000000000   ; null descriptor
    dq 0x00CF9A000000FFFF   ; code segment
    dq 0x00CF9A200000FFFF   ; data segment
gdt_end:

gdt_descriptor:
    dw gdt_end-gdt_start-1  ; define max size limit
    dd gdt_start            ; base address

CODE_SEG 0x08
DATA_SEG 0x10


init_pm:
    mov ax, DATA_SEG
    mov ds, ax              ; sets data segment registers to our data seg address
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax              ; stack starts at data seg address
    mov sp, 0x9FC00         ; sets up stack
    call 0x1000             ; jmp to kernel


start:
    cli                     ; disables interrupts
    lgdt [gdt_descriptor]   ; loads the GDT

    mov eax, cr0
    or eax, 1
    mov cr0, eax            ; protected mode is now enabled

    jmp CODE_SEG:

    jmp hang


hang:
    jmp hang

times 510-($-$$) db 0
dw 0xAA55