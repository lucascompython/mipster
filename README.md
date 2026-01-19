# Mipster, a small MIPS Simulator in Zig

This is a simple MIPS simulator written in Zig. It supports a subset of MIPS instructions and is intended for educational purposes.

**[Try it online!](https://lucascompython.github.io/mipster/)** - Run Mipster in your browser!

## Features

- Basic MIPS instruction set support (see [instruction.zig](src/instruction.zig#L4) for details)
- Basic system calls (see [exec.zig](src/exec.zig#L131))
- Parse MIPS assembly code
- WebAssembly support - runs in the browser
- Interactive web editor with syntax highlighting

## Building

### Native Binary

Build and run the native executable:

```bash
zig build run -- ./tests/add.s
```

### WebAssembly

Build the WebAssembly module for the web interface:

```bash
zig build wasm
```

This will generate `mipster.wasm` in the `web/public/` directory.

To test locally:

```bash
cd web
bun install
bun run dev
```

## TODO:

- [x] Refactor wasm zig code
- [x] Re-write the web interface in Astro, with typescript
- [x] Support syntax highlighting in the web editor
