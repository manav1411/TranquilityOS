[bits 32]

; This is the kernel entry point
; later ill change this to call the C kernel main
; Here we just make a dummy kernel that prints 'X'

start:
    mov edi, 0xb8000    ; Video memory start (top left)
    mov al, 'X'         ; char to print
    mov ah, 0x4E        
    mov [edi], ax

hang:
    jmp hang

; Pad to ensure we have enough sectors
times 2048 - ($-$$) db 0