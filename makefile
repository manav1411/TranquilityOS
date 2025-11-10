# Files
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

# Clean generated files
clean:
	rm -f $(BOOT_BIN) $(KERNEL_BIN) $(OS_IMG)
