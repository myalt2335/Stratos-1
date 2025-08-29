ENTRY(kernel_main)

SECTIONS
{
    . = 0x10000;
    
    .text :
    {
        *(.text.kernel_entry)
        *(.text*)
    }

    .rodata :
    {
        *(.rodata)
    }

    .data :
    {
        *(.data)
    }

    .bss (NOLOAD) :
    {
        __bss_start = .;
        *(.bss)
        __bss_end = .;
    }
}
