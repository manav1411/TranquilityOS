[BITS 32]
[ORG 0x1000]

; simple hello world
start:
    mov esi, msg       ; source string
    mov edi, 0xb8000   ; VGA memory start
    mov ecx, msg_len   ; string length

print_loop:
    lodsb               ; load byte from [ESI] into AL, increment ESI
    mov ah, 0x07        ; attribute byte: white on black
    stosw               ; store AX (char+attr) at [EDI], increment EDI by 2
    loop print_loop

hang:
    jmp hang

; ----------------------
msg db 'hello from the kernel!', 0
msg_len equ $ - msg
