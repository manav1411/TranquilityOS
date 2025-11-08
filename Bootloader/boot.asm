
[ORG 0x7c00]
    jmp start
    %include "print.inc"

start:
    x


times 510-($-$$) db 0
dw 0xAA55