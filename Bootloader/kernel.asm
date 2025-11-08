; In kernel.asm - add padding
[BITS 32]
[ORG 0x1000]

start:
    mov ebx, 0xb8000
    mov dword [ebx], 0x07214B4F    ; 'O', 'K' in video memory
.loop:
    jmp .loop

; Pad to at least 512 bytes
times 512 - ($ - $$) db 0