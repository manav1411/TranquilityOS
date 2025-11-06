[ORG 0x7c00]
    jmp start
    %include "print.inc"

start:
    xor ax, ax              ; zeros out ax
    mov ds, ax              ; data segment = 0
    mov ss, ax              ; stack segment = 0
    mov sp, 0x9c00          ; stack pointer points here
    mov ax, 0xb800
    mov es, ax              ; video ram address

    cli                     ; disables interrupts
    xor ax, ax              ; zeros out ax
    mov bx, 0x09            ; keyboard interrupt num
    shl bx, 2               ; multiplies bx by 4 (since each interrupt vector = 4 bytes)

    mov gs, ax              ; GS=0 so we can directly write to IVT (lives in segment 0)
    mov [gs:bx], word keyhandler ; offset of handler address is our data. i.e. when a key is pressed, jmp to 'keyhandler'
    mov [gs:bx+2], ds     ; segment of handler addres is 0.
    sti                     ; enables interrupts

    jmp $                   ; loop forever

keyhandler:
    in al, 0x60             ; gets keyboard data from port 60.
    mov bl, al              ; stores result in bl
    mov byte [port60], al   ; stores result at 'port60' asw

    in al, 0x61             ; reads keyboard control port (on or off)
    mov ah, al
    or al, 0x80             ; disable bit 7
    out 0x61, al            ; send modified value back to port 61
    xchg ah, al
    out 0x61, al            ; send original value back to port 61

    mov al, 0x20 
    out 0x20, al            ; sends an end-of-interrupt command to PIC (so it can send the next one)

    and bl, 0x80            ; ensures only key PRESS is registered, not release asw
    jnz done                ;

    mov ax, [port60]
    mov word [reg16], ax    ; passing value for printreg16
    call printreg16         ; prints value at reg16 address

done:
    iret                    ; returns after interrupt

port60 dw 0                 ; 
times 510-($-$$) db 0       ; padding to 512 bytes
dw 0xAA55                   ; bootloader signature