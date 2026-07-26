# Simplified Conversion Tool

A small 16-bit DOS assembly program that converts numbers between decimal, binary, and hexadecimal formats through a simple text menu.

## Features

- Decimal to binary
- Decimal to hexadecimal
- Binary to decimal
- Hexadecimal to decimal
- Menu-driven DOS interface

## Requirements

This project targets a 16-bit DOS environment.

- MASM or a compatible assembler such as TASM
- A DOS-compatible runtime such as DOSBox

## How It Works

The program repeatedly displays a menu and lets you choose one of four conversions:

1. Decimal to Binary
2. Decimal to Hexadecimal
3. Binary to Decimal
4. Hexadecimal to Decimal
5. Exit

After each conversion, the result is shown on screen and the program waits for a keypress before returning to the menu.

## Input Notes

- Decimal input is expected in the range `0-65535`
- Binary input should contain only `0` and `1`
- Hex input should contain only `0-9` and `A-F` or `a-f`
- Invalid hexadecimal input is detected and reported

## Building and Running

The source file is [tool.asm](tool.asm).

Example workflow in a DOS environment:

```text
masm tool.asm;
link tool.obj;
tool.exe
```

If you are using DOSBox, mount the project folder first, then run the assembler and executable from inside DOSBox.

## Notes

- This is a 16-bit real-mode DOS program and will not run natively on modern 64-bit systems without an emulator or compatibility layer.
- The conversion routines operate on unsigned 16-bit values.

