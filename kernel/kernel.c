// The kernel starts here :)
#include <stdint.h>

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


void kernel_main() {
    kprint("hello world! - from Manav's kernel! :D");
    return;
}