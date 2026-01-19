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
        .Mtc1 => |i| {
            // move to coprocessor 1
            // bitcast u32 to f32
            cpu.fregs[i.fs] = @as(f32, @bitCast(cpu.regs[i.rt]));
        },
        .@"cvt.s.w" => |i| {
            // cvt.s.w: convert integer in fs to float in fd
            // fs is likely bitcast from u32, so we treat it as i32
            const int_val: i32 = @bitCast(cpu.fregs[i.fs]);
            cpu.fregs[i.fd] = @as(f32, @floatFromInt(int_val));
        },
        .@"mov.s" => |i| cpu.fregs[i.fd] = cpu.fregs[i.fs],
        .@"mul.s" => |i| cpu.fregs[i.fd] = cpu.fregs[i.fs] * cpu.fregs[i.ft],
        .@"div.s" => |i| cpu.fregs[i.fd] = cpu.fregs[i.fs] / cpu.fregs[i.ft],
        .@"add.s" => |i| cpu.fregs[i.fd] = cpu.fregs[i.fs] + cpu.fregs[i.ft],
        .@"sub.s" => |i| cpu.fregs[i.fd] = cpu.fregs[i.fs] - cpu.fregs[i.ft],
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
        2 => { // print_float
            stdout.print("{d}", .{cpu.fregs[12]}) catch @panic("Failed to print float");
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
            // skip whitespace
            var line: ?[]const u8 = null;
            while (true) {
                line = stdin.takeDelimiter('\n') catch return;
                if (line) |l| {
                    const trimmed = std.mem.trim(u8, l, " \t\r");
                    if (trimmed.len > 0) {
                        line = trimmed;
                        break;
                    }
                } else return;
            }
            const value = std.fmt.parseInt(u32, line.?, 10) catch return;
            cpu.regs[@intFromEnum(Register.v0)] = value;
        },
        6 => { // read_float (into $f0)
            // skip whitespace
            var line: ?[]const u8 = null;
            while (true) {
                line = stdin.takeDelimiter('\n') catch return;
                if (line) |l| {
                    const trimmed = std.mem.trim(u8, l, " \t\r");
                    if (trimmed.len > 0) {
                        line = trimmed;
                        break;
                    }
                } else return;
            }
            const value = std.fmt.parseFloat(f32, line.?) catch return;
            cpu.fregs[0] = value;
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
        12 => { // read_char (into $v0)
            // skip whitespace/newlines
            var char: u8 = 0;
            while (true) {
                char = stdin.takeByte() catch 0;
                if (char == 0) break;
                // if char is not whitespace, break
                if (char != ' ' and char != '\t' and char != '\n' and char != '\r') break;
            }
            cpu.regs[@intFromEnum(Register.v0)] = char;
        },

        else => {},
    }
}

pub const RunResult = enum { Finished, Blocked };

pub fn runLoop(noalias cpu: *Cpu, noalias mem: *Memory.Memory, instructions: []const Instruction, noalias labels: *const LabelTable, check_block: ?*const fn () bool) RunResult {
    const TEXT_START = Memory.TEXT_START;
    while (true) {
        if (cpu.pc < TEXT_START) break;
        const pc_offset = cpu.pc - TEXT_START;
        const instr_idx = pc_offset / 4;

        if (instr_idx >= instructions.len) break;

        const instr = instructions[instr_idx];
        const old_pc = cpu.pc;

        execute(instr, cpu, mem, labels);

        if (check_block) |cb| {
            if (cb()) {
                // Determine if we need to advance PC.
                // If it was a syscall that caused the block, it didn't change PC (jump).
                // So we advance it to avoid re-executing it upon resume.
                if (cpu.pc == old_pc) {
                    cpu.pc += 4;
                }
                return .Blocked;
            }
        }

        if (cpu.pc == old_pc) {
            cpu.pc += 4;
        }
    }
    return .Finished;
}
