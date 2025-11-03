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

if you wanted to actually put it on like a usb, do `dd if=boot.bin of=/dev/sda`. `dd=disk` duplicate that copies bytes. if=boot.bin is the input file, of=/dev/sda is the output file (typically entire first physical disk). Basically writes the contents of boot.bin directly to the beginning of sector 0 of the /dev/sda disk. Behind the scenes, it writes to the master boot record (MBR).