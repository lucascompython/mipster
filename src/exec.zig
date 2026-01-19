const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;
const Memory = @import("memory.zig");
const Instruction = @import("instruction.zig").Instruction;
const Register = @import("cpu.zig").Register;
const LabelTable = @import("labels.zig").LabelTable;

const builtin = @import("builtin");

pub fn execute(instr: Instruction, noalias cpu: *Cpu, noalias mem: *Memory.Memory, noalias labels: *const LabelTable) void {
    switch (instr) {
        .Add => |i| cpu.regs[i.rd] = cpu.regs[i.rs] + cpu.regs[i.rt],
        .Addi => |i| cpu.regs[i.rt] = cpu.regs[i.rs] +% @as(u32, @bitCast(@as(i32, i.imm))),
        .Subi => |i| cpu.regs[i.rt] = cpu.regs[i.rs] -% @as(u32, @bitCast(@as(i32, i.imm))),
        .Andi => |i| cpu.regs[i.rt] = cpu.regs[i.rs] & i.imm,
        .Lui => |i| cpu.regs[i.rt] = @as(u32, @intCast(i.imm)) << 16,
        .Ori => |i| cpu.regs[i.rt] = cpu.regs[i.rs] | @as(u32, @intCast(i.imm)),
        .Li => |i| cpu.regs[i.rt] = @bitCast(i.imm),
        .La => |i| {
            const addr = labels.get(i.label) orelse 0;
            cpu.regs[i.rt] = addr;
        },
        .Lbu => |i| {
            const offset = cpu.regs[@intCast(i.offset)];
            const base = cpu.regs[i.base];

            const addr = base + offset;

            const byte = mem.data[(addr - Memory.DATA_START)];
            cpu.regs[i.rt] = @as(u32, byte);
        },
        .Move => |i| cpu.regs[i.rd] = cpu.regs[i.rs],
        .And => |i| cpu.regs[i.rd] = cpu.regs[i.rs] & cpu.regs[i.rt],
        .Or => |i| cpu.regs[i.rd] = cpu.regs[i.rs] | cpu.regs[i.rt],
        .Nor => |i| cpu.regs[i.rd] = ~(cpu.regs[i.rs] | cpu.regs[i.rt]),
        .Xor => |i| cpu.regs[i.rd] = cpu.regs[i.rs] ^ cpu.regs[i.rt],
        .Sll => |i| cpu.regs[i.rd] = cpu.regs[i.rt] << i.shamt,

        .J => |i| {
            const addr = labels.get(i.label) orelse return;
            cpu.pc = addr;
        },
        .Jr => |i| {
            cpu.pc = cpu.regs[i.rs];
        },
        .Jal => |i| {
            const addr = labels.get(i.label) orelse return;
            cpu.regs[@intFromEnum(Register.ra)] = cpu.pc + 4; // save next instruction address
            cpu.pc = addr;
        },
        .Beq => |i| {
            if (cpu.regs[i.rs] == cpu.regs[i.rt]) {
                const addr = labels.get(i.label) orelse return;
                cpu.pc = addr;
            }
        },
        .Bne => |i| {
            if (cpu.regs[i.rs] != cpu.regs[i.rt]) {
                const addr = labels.get(i.label) orelse return;
                cpu.pc = addr;
            }
        },
        .Bgez => |i| {
            const signed_val: i32 = @bitCast(cpu.regs[i.rs]);
            if (signed_val >= 0) {
                const addr = labels.get(i.label) orelse return;
                cpu.pc = addr;
            }
        },
        .Beqz => |i| {
            if (cpu.regs[i.rs] == 0) {
                const addr = labels.get(i.label) orelse return;
                cpu.pc = addr;
            }
        },

        .Syscall => {
            if (comptime builtin.target.cpu.arch.isWasm()) {
                @import("wasm.zig").handleSyscallWasm(cpu, mem);
            } else {
                handleSyscall(cpu, mem);
            }
        },
    }
}

// TODO: this is duplicate from main
var threaded: std.Io.Threaded = .init_single_threaded;
const io = threaded.io();

var stdout_buffer: [1024]u8 = undefined;
var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
const stdout = &stdout_writer.interface;

var stdin_buffer: [1024]u8 = undefined;
var stdin_reader = std.Io.File.stdin().reader(io, &stdin_buffer);
const stdin = &stdin_reader.interface;

// table of syscall handlers
fn handleSyscall(noalias cpu: *Cpu, noalias mem: *Memory.Memory) void {
    const v0 = cpu.regs[@intFromEnum(Register.v0)];
    const a0 = cpu.regs[@intFromEnum(Register.a0)];
    switch (v0) {
        1 => { // print_int
            stdout.print("{d}", .{cpu.regs[@intFromEnum(Register.a0)]}) catch @panic("Failed to print integer");
            stdout.flush() catch @panic("Failed to flush stdout");
        },
        // TODO: see why '\n' is not printed correctly
        4 => { // print_str
            var addr = a0;
            while (true) {
                const c = mem.data[(addr - Memory.DATA_START)];
                if (c == 0) {
                    break;
                }
                stdout.print("{c}", .{c}) catch @panic("Failed to print character");
                addr += 1;
            }
            stdout.flush() catch @panic("Failed to flush stdout");
        },
        5 => { // read_int
            const line = stdin.takeDelimiter('\n') catch return;
            const value = std.fmt.parseInt(u32, line.?, 10) catch return;
            cpu.regs[@intFromEnum(Register.v0)] = value;
        },
        8 => { // read str
            const len = cpu.regs[@intFromEnum(Register.a1)];
            const addr = a0;
            var i: u32 = 0;
            while (i < len - 1) : (i += 1) {
                const c = stdin.takeByte() catch 0;
                if (c == '\n') break;
                mem.data[(addr - Memory.DATA_START) + i] = c;
            }
            mem.data[(addr - Memory.DATA_START) + i] = 0; // null-terminate
        },

        10 => { // exit
            std.process.exit(0);
        },

        else => {},
    }
}
