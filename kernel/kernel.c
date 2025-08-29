#include <stdint.h>
#include "fonts/VGA8.h"

//intellisense, SHUT. THE FUCK. UP.
#ifndef __GNUC__
  #ifndef __attribute__
    #define __attribute__(x)
  #endif
#endif
#if defined(__GNUC__)
  #define ASM(insn) __asm__ __volatile__(insn)
#else
  #define ASM(insn)
#endif
// thank you.

typedef struct __attribute__((packed)) {
    uint8_t  boot_drive;
    uint16_t kernel_segment;
    uint16_t kernel_size;
    uint8_t  graphics_flag;
    uint16_t fb_lo;
    uint16_t fb_hi;
} boot_info_t;
#define BOOT_INFO_PTR ((volatile boot_info_t*)0x00009000)

__attribute__((noreturn))
static void hang(void) {
    ASM("cli");
    for (;;) { ASM("hlt"); }
}

__attribute__((section(".text.kernel_entry"), noreturn))
void kernel_main(void) {
    volatile boot_info_t *bi = BOOT_INFO_PTR;
    if (bi->graphics_flag != 1) hang();
    uint32_t fb_addr = ((uint32_t)bi->fb_hi << 16) | bi->fb_lo;
    if (fb_addr == 0) hang();

    uint8_t *mode_ptr    = (uint8_t*)(0x00090000 + 0x0200);
    uint8_t  bpp         = *(mode_ptr + 0x19);
    uint16_t pitch       = *(uint16_t*)(mode_ptr + 0x10);
    uint16_t width       = *(uint16_t*)(mode_ptr + 0x12);
    uint16_t height      = *(uint16_t*)(mode_ptr + 0x14);
    if (bpp != 8) hang();

    volatile uint8_t *lfb = (uint8_t*)(uintptr_t)fb_addr;

    for (uint32_t y = 0; y < height; y++) {
        for (uint32_t x = 0; x < width; x++) {
            lfb[y * pitch + x] = 1;
        }
    }

    uint32_t box_w = 256, box_h = 12;
    uint32_t box_x = 0, box_y = height - box_h;
    for (uint32_t y = 0; y < box_h; y++) {
        for (uint32_t x = 0; x < box_w; x++) {
            lfb[(box_y + y) * pitch + (box_x + x)] = 0;
        }
    }

    for (uint32_t y = 0; y < 4; y++) {
        for (uint32_t x = 0; x < box_w && x < 256; x++) {
            lfb[(box_y + (box_h/2) + y) * pitch + x] = (uint8_t)x;
        }
    }

    const char *msg = "Hello, graphics mode! :)"; // There's a limit on how many characters you can write
    int len = 0;
    while (msg[len]) len++;

    int total_px = len * 8;
    int start_x  = (width  - total_px) / 2;
    int start_y  = (height - box_h - 16) / 2;

    int x0 = start_x;
    for (int i = 0; i < len; i++) {
        char c = msg[i];
        const uint8_t *glyph;

        if (c < 32 || c > 126) {
            glyph = vga8_font['?' - 32];
        } else {
            glyph = vga8_font[c - 32];
        }

        for (int row = 0; row < 8; row++) {
            uint8_t bits = glyph[row];
            for (int col = 0; col < 8; col++) {
                if (bits & (1 << (7 - col))) {
                    int px = x0 + col;
                    int py = start_y + row;
                    lfb[py * pitch + px] = 7;
                }
            }
        }
        x0 += 8;
    }

    hang();
}

static const uint8_t pad_data[512] = { [0 ... 511] = 0xFF };
