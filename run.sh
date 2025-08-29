#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR=build
BOOT_DIR=bootloader
KERNEL_DIR=kernel

mkdir -p "$BUILD_DIR"

nasm -f bin "$BOOT_DIR/boot.asm"         -o "$BUILD_DIR/boot.bin"
nasm -f bin "$BOOT_DIR/bootstrapper.asm" -o "$BUILD_DIR/bootstrapper.bin"

gcc -m32 -ffreestanding -fno-stack-protector -fno-pic -fno-pie \
    -c "$KERNEL_DIR/isr_stub.S" -o "$BUILD_DIR/isr_stub.o"

gcc -m32 -ffreestanding -nostdlib -fno-stack-protector -fno-pic -fno-pie \
    -c "$KERNEL_DIR/kernel.c" -o "$BUILD_DIR/kernel.o"

ld -m elf_i386 -static -no-pie \
   -T "$KERNEL_DIR/linker.ld" \
   "$BUILD_DIR/kernel.o" "$BUILD_DIR/isr_stub.o" \
   -o "$BUILD_DIR/kernel.elf"

objcopy -O binary "$BUILD_DIR/kernel.elf" "$BUILD_DIR/kernel.bin"

kernel_size=$(stat -c%s "$BUILD_DIR/kernel.bin")
sector_size=512
pad_size=$(( ( (kernel_size + sector_size - 1) / sector_size ) * sector_size ))
truncate -s "$pad_size" "$BUILD_DIR/kernel.bin"

cat "$BUILD_DIR/boot.bin" "$BUILD_DIR/bootstrapper.bin" > "$BUILD_DIR/temp.img"

cat "$BUILD_DIR/temp.img" "$BUILD_DIR/kernel.bin" > "$BUILD_DIR/raw.img"
rm "$BUILD_DIR/temp.img"

qemu-system-i386 \
  -vga std \
  -drive format=raw,file="$BUILD_DIR/raw.img" \
  -no-reboot -no-shutdown \
 -d int,cpu_reset,guest_errors
