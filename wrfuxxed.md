# WRFUxxed
WRFUxxed is an all-access exploit for the WRFU Tester rom that was used by Nintendo for testing the DSi wifi hardware. The exploit has been confirmed on v0.60 and v3.01, but almost certainly also exists on v2.01. It appears that on v3.01 (and probably v2.01) it is not possible to perform the exploit on the 3DS, presumably caused by loading a wifi firmware. As such v0.60 is preferable and this write-up will focus on this version.

So, what makes this rom so special?
* DSi limited cartridge rom
* Retail signed, boots on all (unmodified) retail DSi and 3DS devices
* Small (1 ~ 1.5 MB, depending on the version)
* Not region locked (aka, all bits in header field `0x1B0` set)
* NAND access rights (and thus also SD access)
* Unlocked ARM7 SCFG (aka no hardware is locked)
* Autoboots on a DSi (this may rather be a disadvantage)
* Connects to a SPI-UART bridge via the cartridge SPI bus (IS-SPI-USB-ADAPTER)
    * Allows to send external data to the program
    * Turns out to be exploitable

## IS-SPI-USB-ADAPTER
An SPI transaction should always transfer exactly one byte. To receive response bytes to a command, use the nop command (`0x80`) one byte at a time. The baudrate should be set to 2MHz.

Commands:
* `0x60`-`0x6F`: Echo command id
* `0x80`: Nop
    * Used to receive response bytes. When no response bytes are available returns `0x80` initially, or `0x90` after the reset command has been issued.
* `0x90`: Reset, status/default response becomes 0x90 after this
* `0xA0`-`0xAF`: Echo command id
* `0xB0`: Get writable length
    * Returns the amount of bytes that can be written to write ring (DS -> UART): `{ 0x90, LSB, MSB }`. The returned length should not be larger than 1024.
* `0xC0`: Get readable length
    * Returns the amount of bytes available in the read ring (UART -> DS): `{ 0x90, LSB, MSB }`. The returned length should not be larger than 1024.
* `0xDX`: Writes `X + 1` bytes to the ring buffer (DS -> UART)
    * Expects `X + 1` data bytes. The response bytes should be `0x90`.
* `0xEX`: Reads `X + 1` bytes from the ring buffer (UART -> DS)
    * Returns 1 status byte `0x90` followed by the `X + 1` data bytes.
* `0xF0`: Initialize
    * Returns `{ 0x90, 0x53, 0x50, 0x49, 0x55 }` (the last 4 bytes correspond to ascii `SPIU`).

After each SPI transaction a delay should be inserted from the DS side by using `SVC_WaitByLoop`. Initially `3000` is used as parameter for this (should be about 90us, assuming ARM9 at 134MHz and cached bios). This is also the maximum delay used. During the initialization the DS side will try different delays starting from a small value, testing if the right value is returned using the echo commands.

## The exploit
The exploit uses a stack smash in the function that receives a command from the SPI-UART bridge. For v0.60 this function is at address `0x02005790`, for v3.01 at address `0x02005A2C`. Presumably because of compiler (settings) differences the v3.01 version of the function is slightly easier to exploit, but we'll focus on v0.60 here. Functionally both functions are equal.

The function starts by checking if there's any data available from the UART. Commands are 10 bytes long, so when there are at least 10 bytes available the function will continue and receive the command bytes. For receiving data the function allocates a 100 byte buffer on the stack. This is not an issue for the command itself. After all, it is only 10 bytes long. The interesting part is that the last two bytes of the command are parsed as a hexadecimal number in ascii. As such it can range from `00` to `ff` (should be lower case), 0 to 255 (and as far as I could see it could be even more if you put an invalid character, but as the readable length will never be more than 1024, it wouldn't be very useful). The function will then use this number as the length of the payload of the command. It will wait until there are enough bytes available in the UART read ring and then load those bytes into the stack buffer. A buffer that was only 100 bytes long. From here we can easily overwrite a large part of the stack to take over control.

In v0.60 the stack of the function looks like this:
```
-0x88: 2 byte buffer for ascii hex to decimal conversion function
-0x86: 100 byte buffer for receiving data, the payload will be loaded starting from here
-0x22: 2 bytes of padding to align the stack
-0x20: stored r3
-0x1C: stored r4
-0x18: stored r5
-0x14: stored r6
-0x10: stored r7
-0x0C: stored r8
-0x08: stored r9
-0x04: stored lr -> return address
```
It may be tempting to make the return address point to the payload data we just loaded in memory. But this doesn't work. The stack is located in DTCM, which is fast data memory inside the ARM9, which cannot be used for instruction fetches. As such we will have to copy data to somewhere in memory where we can execute from. (Note that in the v3.01 version of the function the stack is different and it puts the first argument of the function, r0, on the stack. This is a pointer to a buffer where the command and its payload are copied to. This is also a stack buffer, but by overwriting this pointer we can control where the payload is copied to. We can then jump into that code directly and use the `UART_Read` function at `0x0200FCF0` in v3.01 to load more code.)

Because we cannot directly execute code yet, we will use what is called return-oriented-programming (ROP). This technique uses useful snippets of code that are already in memory, often called gadgets, to perform the operations we want. What we essentially want to do is to call `UART_Read` (at `0x0200DA4C` in v0.60) with as destination (r0) a place in main memory and as length (r1) the size of our code. The stack from the function we exploit controls r3-r9, so ideally we could copy some of those to r0 and r1. For this a nice gadget was found at `0x0201DE98`.

```arm
mov r0, r8
mov r1, r4
mov r2, r6
blx r3
sub r7, r7, r6
cmp r7, #0
bne 0x0201DE88
pop {r4-r8,pc}
```
This snippet will set r0 to the value of r8 and r1 to the value of r4. Furthermore it will call the function pointed to by r3. This is perfect, as we wanted to call `UART_Read`. We do however need to make sure the `bne` jump is not taken. This can be done by setting both r7 and r6 to 0. We can then use the `pop` to jump into our freshly loaded code. This leads to the following UART data stream:

```
0x00 - command
0x08 - length of command payload in ascii, "9e"
=== start of stack data, command payload ===
0x0A - dataBuf, just fill with zeros
0x6E - padding (2)
0x70 - r3  -> 0x0200DA4C (UART_Read)
0x74 - r4  -> payload length (UART_Read r1)
0x78 - r5
0x7C - r6  -> 0
0x80 - r7  -> 0
0x84 - r8  -> destination address (UART_Read r0)
0x88 - r9
0x8C - pc  -> 0x0201DE98 (gadget)
=== stack for "pop {r4-r8,pc}" at 0x0201DEB4 ===
0x90 - r4
0x94 - r5
0x98 - r6
0x9C - r7
0xA0 - r8
0xA4 - pc  -> entrypoint, usually equal to destination address (at 0x84)
=== end of command payload, "payload length" (at 0x74) bytes of data follow ===
```

Putting this data in the UART ring at the start of the rom will yield ARM9 code execution within a few frames (you'll quickly see some text flash on screen). From here it is still needed to take over the ARM7 however. I modified [minitwlpayload](https://github.com/devkitPro/dsi/tree/master/exploits/minitwlpayload) for that.

## Taking over the ARM7
As this rom is a full-rights test cartridge Nintendo didn't use a normal twl limited ARM7 binary (racoon or ferret). Instead they use an ARM7 binary called armadillo. One of the differences of this binary is that the normal SDK reset mechanism was removed. Presumably to make it harder to take over the ARM7. All of the code in this binary runs in twl wram, and the ARM7 made sure to lock it with `REG_MBK9` (`0x4004060`), such that the ARM9 cannot remap it. Fortunately Nintendo left in PXI (Processor eXchange Interface, Nintendo's name for the IPC fifo) commands to undo the twl wram locking.

```
aaaa aabb 0000 0000 00mm mmmm mmcc cccc
aaaaaa = command; 13 = unlock twl wram
bb = block; 0 = WRAM A, 1 = WRAM B, 2 = WRAM C
cccccc = pxi channel; 18 = twl wram manager
mmmmmmmm = slot mask, 4 bits for WRAM A, 8 bits for WRAM B and C

As such the required commands are as follows:
Unlock all of WRAM A: 0x340003D2
Unlock all of WRAM B: 0x35003FD2
Unlock all of WRAM C: 0x36003FD2
```
With unlocked twl wram we can steal memory from the ARM7, filling it with some code (mainly jumps) and mapping it back in the hope that the ARM7 will happen to execute from there. This is a race condition. When twl wram slots are mapped to the arm9 instead of arm7, the arm7 will read zeros there, so if it executes from there the slot turns into a nop-slide. You also cannot be sure if the ARM7 is running arm or thumb code. The twl wram is mapped as follows on the ARM7:
```
0x03740000 - WRAM C
0x03780000 - WRAM B
0x037C0000 - WRAM A
```
Starting from `0x03740000` there's code and then data. Most code resides in WRAM C. I found that stealing blocks from WRAM A works poorly. There are stacks for various ARM7 threads in there, causing jumps to 0 which lead to unwanted results. A strategy that happened to work was to start from WRAM C slot 7 (`0x03778000`-`0x03780000`) and steal, fill and map back the slots one by one. We fill the slots with the value `0xE3A0F406`, which encodes for
```arm
mov pc, #0x06000000
```
The ARM7 payload is placed in VRAM C (and/or D) and mapped to the ARM7 such that it appears at address `0x06000000`. This should obviously be done before filling the slots with jumps.

## Conclusion
With WRFUxxed we have a full-rights DSi cartridge exploit that could be used by flashcards to gain full unlocked ARM7 and ARM9 code execution on unmodified DSi and 3DS systems. It can be used for running homebrew and retail DS and DSi games, for hacking DSi consoles by installing [unlaunch](https://problemkaputt.de/unlaunch.htm) and for hacking 3DS consoles using [b9sTool](https://github.com/zoogie/b9sTool) (access to 3DS nand from DSi mode).