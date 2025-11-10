# files
KERNEL_ENTRY=kernel/kernel_entry.asm
KERNEL_ENTRY_OBJ=kernel/kernel_entry.o
C_KERNEL=kernel/kernel.c
C_KERNEL_OBJ=kernel/kernel.o
LINKER=kernel/linker.ld
BOOT=bootloader/boot.asm
BOOT_BIN=boot.bin
KERNEL_BIN=kernel.bin
OS_IMG=os_image.bin

# default target, makes the OS image, doesn't run it
all: $(OS_IMG)

# compile bootloader
$(BOOT_BIN): $(BOOT)
	nasm -f bin $(BOOT) -o $(BOOT_BIN)

# compile C kernel to obj file
$(C_KERNEL_OBJ): $(C_KERNEL)
	i686-elf-gcc -m32 -ffreestanding -nostdlib -O2 -Wall -Wextra -c $(C_KERNEL) -o $(C_KERNEL_OBJ)

# compile kernel entry to obj file
$(KERNEL_ENTRY_OBJ): $(KERNEL_ENTRY)
	nasm -f elf32 $(KERNEL_ENTRY) -o $(KERNEL_ENTRY_OBJ)

# link kernel objects to make a flat binary
$(KERNEL_BIN): $(C_KERNEL_OBJ) $(KERNEL_ENTRY_OBJ)
	i686-elf-ld -nostdlib -m elf_i386 -T $(LINKER) -o $(KERNEL_BIN) $(KERNEL_ENTRY_OBJ) $(C_KERNEL_OBJ)

# OS image built by concatenating boot and kernel.
$(OS_IMG): $(BOOT_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(OS_IMG)

# run in QEMU
run: $(OS_IMG)
	qemu-system-i386 -fda $(OS_IMG)

# delete compiled files
clean:
	rm -f $(BOOT_BIN) $(KERNEL_BIN) $(C_KERNEL_OBJ) $(KERNEL_ENTRY_OBJ) $(OS_IMG)