all: os-image.bin

os-image.bin: boot.bin kernel.bin
	dd if=/dev/zero of=os-image.bin bs=512 count=2880
	dd if=boot.bin of=os-image.bin conv=notrunc
	dd if=kernel.bin of=os-image.bin bs=512 seek=1 conv=notrunc

boot.bin: bootloader/boot.asm
	nasm -f bin $< -o $@

kernel.bin: kernel/kernel.asm
	nasm -f bin $< -o $@

run: os-image.bin
	qemu-system-x86_64 -fda os-image.bin

debug: os-image.bin
	qemu-system-x86_64 -fda os-image.bin -d cpu -no-reboot -no-shutdown

clean:
	rm -f *.bin *.img

disasm: boot.bin
	ndisasm -b 16 boot.bin
