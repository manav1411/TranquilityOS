# TranquilityOS
an OS built from scratch, designed to run on x86 architecture. The project explores the fundamentals of bootloaders, kernel dev, and low-level hardware interaction, starting from BIOS execution to a basic 32-bit kernel.

## Features
- Minimal bootloader written in x86 assembly
- Transition from real mode (16-bit) to protected mode (32-bit)
- Simple kernel that prints directly to video memory (bypassing BIOS)
- QEMU support for rapid testing and debugging


## Project Structure (may be outdated)
TranquilityOS/
├─ bootloader/
│  └─ boot.asm
├─ kernel/
│  └─ kernel.asm
├─ Makefile         # Automates build, run, debug
└─ README.md

## Steps to Run
1. ensure you have nasm and qemu for emulation.
2. `make run`

## Bootloader Overview
- The bootloader is responsible for:
- Being loaded by BIOS into memory at 0x7C00.-
- Initializing the stack and registers.
- Loading the kernel into memory.
- Switching the CPU from 16-bit real mode to 32-bit protected mode.
- Jumping to the kernel entry point.

## Kernel Overview
- The kernel is minimal and demonstrates:
- Writing characters to the screen via video memory
- Infinite loop to "hang" the system for demonstration
- Placeholder for future C kernel integration



## Future Work
- Kernel functionality with C code
- Implement memory management and task switching
- Add file system support
- implement multi-core support and user-level programs




Notes to self:
- don't build an arbitrary OS that mimics those already built, but something that actually has a purpose and novelty - demonstrates ability to build complex systems, not just following instructions. might not be relevant at the start.
- explicitly document design tradeoffs to demonstrate thinking beyond following instructions