.text
.globl isr_common_stub
.type isr_common_stub, @function

isr_common_stub:
    cli
    hlt
    jmp isr_common_stub

.section .note.GNU-stack, "", @progbits
