# WRFUxxed

This repository contains the code for the **WRFUxxed** exploit for "WRFU Tester". It is compatible with version 0.60 (SHA-1: `2d65fb7a0c62a4f08954b98c95f42b804fccfd26`).

For a detailed writeup of the exploit, see [wrfuxxed.md](wrfuxxed.md).

## Setup & Configuration
We recommend using WSL (Windows Subsystem for Linux), or MSYS2 to compile this repository.
The steps provided will assume you already have one of those environments set up.

1. Install [BlocksDS](https://blocksds.skylyrac.net/docs/setup/options/)

## Building
1. Run `make`

## Usage
Patch `uartBufv060.bin` with the DSpico DLDI. The `uartBufv060.bin` file can then be included in the DSpico firmware.

The exploit payload initializes the DSpico and then uses Pico Loader to boot `/_picoboot.nds` on the DSpico SD card. Make sure the Pico Loader files are in the `/_pico` folder.

## Errors
- Blue screen: Failed to mount the DSpico SD card.
- Red screen: Failed to open `/_pico/picoLoader9.bin` or `/_pico/picoLoader7.bin`.

## License

This project is licensed under the Zlib license. For details, see `LICENSE.txt`.

## Contributors
- [@Gericom](https://github.com/Gericom)
- [@XLuma](https://github.com/XLuma)
- [@lifehackerhansol](https://github.com/lifehackerhansol)
