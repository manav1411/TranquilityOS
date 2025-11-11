making my own bootloader (part 1):

The purpose of a bootloader is to pass execution to the part of memory where the kernel sits.

steps to run:

1. write bootloader in assembly in `boot.asm` file - contains code meant to be executed by a BIOS (in 16 bit mode).
2. assemble it into a binary with `nasm -f bin boot.asm -o boot.bin`. `nasm` is an assembler for x86 architecture for 16/32/64 bit programs. `-f` specifies the output file **f**ormat. -o specifies **o**utput file name. no flag needed for assembly input file name. Doing `-f bin` specifies a RAW binary file (not not an executable like ELF, just bytes that go directly into memory). Note that nasm assembles x86 machine code into a binary file (not an executable) - hence, macOS does not run it directly, so there's no need for cross-compilation. it's just raw bytes for whatever architecture assembly targets.
3. use qemu to create an x86 virtual CPU with `qemu-system-x86_64 -drive format=raw,file=boot.bin`. `-drive` specifies the disk image(boot.bin)/format(raw) to QEMU. 

notice that `qemu-system-x86_64` emulates a x84-64 CPU. All x86 CPUs start up in 16-bit mode. It starts in real mode, executes the bootloader, and then only switches to protected mode or long mode if our bootloader code specifies it to. So using even like `qemu-system-i386` means it would behave the same way, we just use x86_64 since it is a more general emulator and can handle 16, 32, and 64 bit code. 

The emulated BIOS inside QEMU loads first 512 bytes from the disk image (boot.bin) into memory at 0x7C00, checks that the last two bytes are 0xAA55(boot signature), starts executing code at 0x7C00.

the bootloader is executed on top of SeaBIOS (qemu default), which is an x86 BIOS

first bootloader:

```nasm
; boot.asm

hang:
	jmp hang
	
	times 510-($-$$) db 0
	db 0x55
	db 0xAA
	
```

`$`, `$$`, and `db` are NASM directives. Not assembly instructions for the CPU:

`$` is the current address NASM is assembling at. e.g. if NASM had written 100 bytes of code, then `$` = 100.

`$$` is the start address of the current file, in this case start of the bootloader.

so `$` - `$$` gives the current size of everything assembled so far.

`db` = 'define byte', this is a NASM directive to put literal bytes in the output file. We can do like `db A` which defines 1 byte, as 41.

instructions:

`times` is an instruction that means repeat. so we are repeating ‘db 0’ 510-($-$$) times. We are padding the file with zeros till total size is 512 bytes

`jmp` jumps to a specified label. in our code, It's basically an infinite loop that repeats forever. equivalent of `while (1) {`.

at the end, we are defining 0xAA55 as the last 2 bytes. this is the boot signature required by the BIOS to recognise this as a bootable sector. Notice it is little endian order.

Typically, after the code is assembled in NASM, it is copied to a floppy disk, hard drive, USB using partcopy, dd, or debug. You then simply boot from that disk.

if you wanted to actually put it on like a usb, do dd if=boot.bin of=/dev/sda. dd=disk diplicate that copies bytes. if=boot.bin is the input file, of=/dev/sda is the output file (typically entire first physical disk). Basically writes the contents of boot.bin directly to the beginning of sector 0 of the /dev/sda disk. Behind the scenes, it writes to the master boot record (MBR).

bootloader part 2 (printing characters):

review: boot sector loaded by BIOS is 512 bytes. Code in boot sector of the disk loaded at `0000:7c00` is what the BIOS starts executing. The machine starts in Real Mode. 

in real mode, addresses are calculated as: `segment * 16 + offset`. Since offset can be much larger than 16, there are many pairs of segment/offsets that can point to the same memory address. e.g. some say the bootloader is loaded at `0000:7C00`, others say `07C0:0000`. this is the same address. it doesn’t matter which one you use.

To do this, we do the necessary stuff (such as the bootloader signature the bios looks for at the bottom, padding with 0 bytes to make it exactly 512 bytes - 1 sector, setting ds as 0x07c0 i.e. where we want the code execution to start, a hang label which jumps to hang and loops when we want to not do anything).

we add a section that we call 'msg' and db it to 'hello world' chars, then 13 (carriage return \r), then 10 (line feed \n), then 0 (so we can say in our loop to stop when msg char is 0

we set `si` (source index, used for string operations) as `msg`, and we do `cld` which clears the direction flag effectively auto-incrementing after each operation.

then, we have a ch_loop that prints a character every iteration. in each iteration we do: 

`lodsb` - which loads a byte from the `si` register into register `al`

we then refresh the value of al by or-ing al with itself just in case.

if al=0, we jump to hang

we then do the bios interrupt 0x10 by `int 0x10` (usually used for video display functions), and we set `AH` register to `0xE` which is to display a character. `bh` set to 0 just as a default.

this interrupt reads the `al` register and prints the character.

you can break up your assembly code into different files like:

```nasm
jmp main

%include otherCode.blah

main:
...rest of code...
```

remember to use jmp main, so that execution starts at main, and not some other procedure in otherCode.blah, etc.

```nasm
mov ax, 0x07c0
mov ds, ax

mov si, msg
cld
output_char:
    lodsb
    or al, al
    jz hang

    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp output_char

hang:
    jmp hang

msg db "hello world", 13, 10, 0
    times 510-($-$$) db 0
    db 0x55
    db 0xAA
```

bootloader part 3 (looking into the machine code):

below assembly, instructions are coded into machine code. in machine code, there are opcodes (operation codes) - an opcode tells the CPU what operation to perform like adding, subtracting, moving data. Binary code that specifies the action. The rest of theinstruction (operands) provides the data to be processed.

bootloader part 4 (hello world without BIOS):

previously, when we printed characters from the bootloader, we used the BIOS interrupt.

Now, we will print a string and contents of a memory location to screen without using BIOS and instead using video memory (which starts at `0xB800`), and also converting hex to make it displayed to check register/memory values (useful education for future debugging). We learn this, since after we go into protected mode, we won’t have BIOS interrupts available - so we need to know how to print stuff to the screen and debug.

to print a string using video ram (vram), the screen buffer starts at memory address `0xB8000` where every character cell is 2 bytes. e.g. writing 'A' (0x41) and attribute white on black (0x0F) to `0xB8000` will display a white A.

below, cprint calculates where on screen to place the character and writes it using `stosw` (which stores a word in ES:DI and increments DI). ES = the segment for video memory.

printing string and memory address from vram:

```nasm
[ORG 0x7c00]
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x9c00

    cld

    mov ax, 0xb800  ; video memory
    mov es, ax

    mov si, msg
    call sprint

    mov ax, 0xb800
    mov gs, ax
    mov bx, 0x0000
    mov ax, [gs:bx] ; see video memory address

    mov word [reg16], ax
    call printreg16

hang:
    jmp hang

dochar:
    call cprint

sprint:
    lodsb
    cmp al, 0
    jne dochar
    add byte [ypos], 1
    mov byte [xpos], 0
    ret

cprint:
    mov ah, 0x0F
    mov cx, ax
    movzx ax, byte [ypos]
    mov dx, 160
    mul dx
    movzx bx, byte [xpos]
    shl bx, 1

    mov di, 0
    add di, ax
    add di, bx

    mov ax, cx
    stosw
    add byte [xpos], 1
    
    ret

printreg16:
    mov di, outstr16
    mov ax, [reg16]
    mov si, hexstr
    mov cx, 4

hexloop:
    rol ax, 4
    mov bx, ax
    and bx, 0x0f
    mov bl, [si + bx]
    mov [di], bl
    inc di
    dec cx
    jnz hexloop

    mov si, outstr16
    call sprint
    
    ret

xpos db 0
ypos db 0
hexstr db '0123456789ABCDEF'
outstr16 db '0000', 0
reg16 dw 0
msg db "hello, this isn't from the BIOS!", 0
times 510-($-$$) db 0
db 0x55
db 0xAA
```

I cbs-ed learning all the particularities and specifics above (bc too tedious/time consuming, not bc too challenging). But I get the general gist of how it works at a higher level.

personal notes:

at this point, I’m able to see a much clearer picture of the role of the bootloader in an operating system. The BIOS is firmware (firmware = software permanently stored in hardware, but is updatable). This BIOS looks for the bootloader given the specific signature and jumps to that execution address. The bootloader stores itself at 0x07c0 and starts executing from there. 

The key difference between a bootloader and the kernel is that the bootloader is run in real mode, and the kernel is run in protected mode. You want the bootloader to do things you can only do in real mode (such as identifying the memory addresses of where to store stuff, etc).

The job of the bootloader is, in 512 bytes, is to start executing the kernel code at an address it specifies, and switching from 16 bit real mode to 32 bit protected mode. 

bootloader part 5 (interrupts):

when there is input from hardware, a hardware interrupt is triggered. e.g. when you press a key. to find the entry in the IVT (interrupt vector table), multiply the interrupt number by 4 (4=size of each entry). 

```nasm
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
```

bootloader part 6 (entering protected mode, GDT):

all we need to do to enter protected mode is switch a single bit in a special control register:`cr0`.

we need to set up a global descriptor table (GDT). This is a data structure with 'memory segment' entries - used by the CPU.

a GDT should have entries:

- entry 0: NULL descriptor, containing no data.
- DPL (descriptor privilege level 0): kernel is stored here.
- Data Segment descriptor: to store data, since writing to code segments is not allowed.
- Task State Segment descriptor: to see the state of tasks
- room for more segments in the future (like user-level, LDTs, more TSS, etc)

bootloader part 7 (stack, finalising design):

So, I want my bootloader (loaded by the BIOS at 0x07C0, to set up the stack (16 bit real mode, for bootloader to use before pmode), then find the kernel code, load the gdt i made, set up the stack to be used by the kernel in 32bit pmode, and execute code from the kernel.

some things I want to clear up to understand things better:

1. 

this is how everything looks in memory (map!):

```nasm
+---------------------------+  0xFFFFF <- High memory
|  video RAM, BIOS ROM, etc |
|        ~free RAM~         |
|                           |
|                           |
|                           |
|        Pmode Stack        | <- kernel stack from bootloader, grows downwards
|                           |
|                           |
|                           |
|---------------------------|0x7E00
|                           |
|   Bootloader (512 bytes)  | <- compiled bootloader, stores upwards
|---------------------------|0x7C00
|     real temp stack       | <- temp stack for bootloader, grows downwards
|                           |
|   Kernel loaded here      | <- compiled kernel, stores upwards
|---------------------------|0x1000
|                           |
|   BIOS data / IVT area    |
+---------------------------+0x0000
```

Note that this is RAM, not where the actual compiled files live. So, when our bootloader finishes executing and passes execution to the kernel, which starts executing from 0x1000, even if our kernel is large and grows past 0x7C00 (where our bootloader code was being read), it doesn’t matter since the bootloader has done everything it needs to do.

Also note how our stack is at the top and grow downwards, and our code is at the bottom and grows upwards. This is to ensure that they don’t collide.

in our code, we define a stack at 0x7C00, which grows downards. This is our stack to be used for bootloader things such as push operations - fine. After switching to 32 bit protected mode, we set the stack at 0x90000 (dont need prev one anymore), this is high and ensures even if we push a lot onto the stack, it is unlikely to overwrite memory used for other things. the stack at 0x9000 persists till the kernel resets/replaces it. It is the kernel's temporary runtime stack. 

the stack in used like: in real mode, call instruction pushes the return address, push/pop manipulates temporary values, interrupts push flags/return state. in protected mode, it is used for return addresses, function arguments, local variables, saved registers like push esi. ESP (stack pointer) is like the current threads ‘working scratchpad’

note: in protected mode, memory addresses are flat (just the base), but in real mode they’re formed as physical address = segment*16+offset. So after switching to Pmode, all addresses are calculated linear-ly.

we will use the BIOS interrupt 0x13 to load the kernel program and to find it we define the CHS address (cylinder, head, sector), num of sectors to read, and the offset from here the kernel is stores from.

when we are in real mode (16 bit), we have addresses 0x00000-0xFFFFF. This is 1mb. all you have. In protected mode, since we switch to 32 bit, we have addresses 0x00000000–0xFFFFFFFF (4gb). this is why the RAM in 32 bit systems was limited to 4gb.

why did I pick 0x90000 for the stack top? well because it is a bit below 0xA0000 address from which point onwards, VGA RAM, BIOS ROM, etc are stored. I kept it a bit below to provide a safe margin.

Also notice how the stack is in real mode addressing. 

For now, our kernel doesn't do much. we don't have paging/any memory management like page tables. we are just using flat physical memory.  Even though when we switched to Pmode 32 bit, we still are only using the physical RAM that existed in real mode (1mb). So this stack is temporary, and a staging area for when we need it whilst doing things in our kernel. We don't set the stack to something like 0x90000000 because our machine only has 1mb accessible so far, it doesn't correspond to real physical RAM. We first need to turn on paging, and create page tables so that the CPU doesn't treat addresses literally as physical memory offsets,  and we have the ability to map higher regions.

the GDT tells the CPU how to interpret segment registers, once we enter protected mode. the lgdt instruction loads our GDT into GDTR (a CPU register holding the GDT base+limit). After we turn on protected mode, when we far jump, we load CS (code segment) register, with CODE_SEG (0x08), the 2nd entry. That's what makes the CPU use our code segment descriptor.

finalised bootloader code:

```nasm
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
```

makefile:

I’ve read makefile documentation, and understood how they work.

Basically for complex proejcts with various dependencies, compiling might take forever both processing wise as well as finding the right commands wise.

To organise this, makefiles help us organise dependencies, what to compile, etc. It tracks whichever files we changed, etc, and when we run a specific make command, will check if there is an update on the files/dependency files to necessitate relevent recompilations/other commands. it helps tidy things up well.

previously, to compile my operating system, I compiled the bootloader with nasm, the kernel with nasm, made an OS image with cat, and ran with qemu like this:

```
nasm -f bin bootloader/boot.asm -o boot.asm
nasm -f bin kernel/kernel.asm -o kernel.bin
cat boot.bin kernel.bin > os_image.bin
qemu-system-x86_64 -fda os_image.bin
```

here is the makefile I made for my OS, which does the above with `make run`, as well as an extra `make clean` command if I want to delete all the compiled files. If I just want to compile the files but not run, I simply do `make`.

```makefile
# files
BOOT=bootloader/boot.asm
KERNEL=kernel/kernel.asm
BOOT_BIN=boot.bin
KERNEL_BIN=kernel.bin
OS_IMG=os_image.bin

# default target, makes the OS image, doesn't run it
all: $(OS_IMG)

# OS image built by concatenating boot and kernel.
$(OS_IMG): $(BOOT_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(OS_IMG)

# compiling bootloader
$(BOOT_BIN): $(BOOT)
	nasm -f bin $(BOOT) -o $(BOOT_BIN)

# compiling kernel
$(KERNEL_BIN): $(KERNEL)
	nasm -f bin $(KERNEL) -o $(KERNEL_BIN)

# run in QEMU
run: $(OS_IMG)
	qemu-system-x86_64 -fda $(OS_IMG)

# delete compiled files
clean:
	rm -f $(BOOT_BIN) $(KERNEL_BIN) $(OS_IMG)
```

linker file:

atp, the bootloader works, and I’m able to print out an X with a kernel file like this:

```makefile
[bits 32]
start:
    mov edi, 0xb8000    ; Video memory start (top left)
    mov al, 'X'         ; char to print
    mov ah, 0x4E        
    mov [edi], ax

hang:
    jmp hang
```

What I want to do now, is that instead of coding in assembly, write my code from the kernel onwards in C. Currently our bootloader reads kernel sectors from the disk into ram at the kernel_offset we specify in the bootloader, JMPs execution to that point in memory.

We tell the bootloader where the kernel sectors are using CHS addressing (we tell it sector 2, read 4 sectors, store at 0x1000).

Now, we will keep this idea, but instead of a stub kernel in assembly, we will replace it with a ‘kernel_entry’ assembly program, who’s job it is to call a C program kernel.c’s main function and start executing. And that C program will print an ‘X’ primitively.

Now to do this, we can’t simply cat because with C code, when you compile it with like gcc,  an object file is produced containing .text section, .data section, etc. it is not yet in a flat memory layout (requires linking) - so if you cat boot.bin and kernel.o, after the 0x1000 jump, it could be anything there.

this is where the linker comes in - it turns the object file (kernel.o) into a flat binary. My specific linker script tells the linker where execution starts, the output format (raw binary), where to load the kernel, and what different object files are.

this is the linker code, as you can see, the entry point is at kernel_entry, which we’ve got set in the kernel_entry.asm assembly file. we tell it to output a flat binary, where it is executing (0x1000), and what different parts of the object files are such as .text.

```makefile
ENTRY(kernel_entry);
OUTPUT_FORMAT("binary");
SECTIONS {
    . = 0x1000;
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) }
}
```

kernel_entry.asm:

kerenl_entry.asm is in 32 bit protected mode, and we have the global kernel_entry symbol (which makes the symbol global, available to the linker) (the linker knows to start executing code from that section).

extern kernel_main tells nasm that kernel_main is a symbol not in this file so nasm leaves a placeholder there, and the linker fills in the plkaceholder with the actual address of the kernel_main function when linking the kernel.

now, at the kernel_entry section, we simply call the kernel_main label and the bootloader will jump to that address in the C kernel file and the C kernel function kernel_main will control execution, until it returns. When it returns, execution goes back to kernel_entry, which just endless loops (does nothing):

```makefile
[bits 32]
global kernel_entry
extern kernel_main

kernel_entry:
    call kernel_main
    jmp hang

hang:
    jmp hang
```

kernel planning (first C part!):

great, so now we can write C code, and all the other stuff is handled by linker files, make files, assembly, etc. At this point, we can write C code, but are missing a lot of features typically expected such as printf, standard library, etc. All we have is kernel_main entry point.

useful resource to figure out what order to make things in: https://wiki.osdev.org/What_Order_Should_I_Make_Things_In%3F

TODO list from now:

1. Now, I will write a `kprint` function, to print stuff to the kernel.
2. output / input? to a serial port (uses UART)
3. interrupt/exception handling system - able to dump contents of registers
4. plan memory map (virtual and physical)
5. the heap (to allow ability to allocate memory at runtime, i.e. malloc and free

after this, I'll sketch out what is likely to depend on what, and do things in 'lead depndent first' order. Ideas bubbling in my head are: file system, GUI.

kprint:

first function to implement in kernel_main is kprint, so that sum like this would work:

```c
void kernel_main() {
    kprint("hello world!");
    return;
}
```

we have the video text buffer at 0xB8000. each character on screen is represented by 2 bytes (byte0 is ASCII code of the character, byte1 is its attribute (colour and background)).

for historical reasons, there are 80 columns x 25 rows, the offset is calculated linearly. so 4000 bytes total. 

if we want to print a character at (x, y), we do video_memory[(y*80 + x) * 2] = char. if we write in uint16_t though, since each entry is 16 bits (a char is 8 bits), we can simply do video_memory[(y*80 + x)], since a 16bit entry takes up the expected 2 bytes.

Note that the first 8 bits in an entry in vram is the ‘attribute’, inside the ‘attribute, the first 4 bits is the background colour and the next 4 bits is the text colour. You can see specifics here: https://en.wikipedia.org/wiki/BIOS_color_attributes. I have chosen green bg, yellow text (Aussie Aussie Aussie!!). now the next 8 bits in an entry in video memory is the actual ASCII char we want to display.

Since we want to print multiple chars, we need to iterate to get further entries from the base vram address. To start with, we see that we get a pointer to the video memory address (0xB8000), we can then calculate further offsets from there like video_memory[ypos*80+xpos], which we can iterate for each char as required. 

To iterate over each char, we simply do `char curr_char = *str++;` which simply gets the char at the str address, and moves the pointer pointing to str to the next char.

```c
// function to print text to vram - useful for debugging!
void kprint(const char* str) {
    uint8_t xpos = 0;
    uint8_t ypos = 0;
    volatile uint16_t *video_memory = (uint16_t*)0xB8000;
    
    // print string to vram
    while (*str != '\0') {
        // prints char to vram in green/yellow
        char curr_char = *str++;
        uint16_t char_entry = (0x2E << 8) | curr_char;
        video_memory[ypos * 80 + xpos] = char_entry;
        xpos++;
        
        // new col every 80chars, overwrite every 25cols
        if (xpos > 80) {
            ypos++;
            xpos = 0;
            if (ypos > 25) {
                ypos = 0;
            }
        }
    }
    return;
}
```

getting serial ports working:

X

timeline update:

Working on making my own operating system so far has been quite satisfying and I’ve learnt quite a bit! But planning ahead, there’s SO much I would need to do for it to be at my standard of ‘done’ as a completionist, such as memory mapping, interrupt vector tables, writing drivers for hardware like keyboard (mouse would be cool!),a GUI, heap, etc. And I don’t have the time to finish this as interesting as it may be. So I have decided to reach a satisfying plateau (such as getting keyboard input/output working) and then put it on ice to work on other stuff.

I love working at the low level, and I want to freeze this project, not terminate it. So that I can come back to it, work on it as I wish. But for now, I need to prioritise other work.

Note to self: currently, we’ve got the kernel able to print letters to the screen by vram. Next, we need to set up some basic kernel infrastructure like the heap, IDT, etc. Getting keyboard I/O working and writing a driver for it is the next big ‘milestone’. Useful resource for that: 

http://www.osdever.net/bkerndev/Docs/intro.htm