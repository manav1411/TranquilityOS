// The kernel starts here :)

void kernel_main() {
    volatile unsigned short* video = (unsigned short*)0xB8000;
    *video = ('X' | (0x4E << 8)); // print X with color
    return;
}