const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;
const Memory = @import("memory.zig").Memory;
const TEXT_START = @import("memory.zig").TEXT_START;
const parser = @import("parser.zig");
const Instruction = @import("instruction.zig").Instruction;
const decode = @import("instruction.zig").decode;
const Register = @import("cpu.zig").Register;
const LabelTable = @import("labels.zig").LabelTable;
const exec = @import("exec.zig");
const executeInstruction = exec.execute;

const allocator = std.heap.wasm_allocator;
var cpu: Cpu = undefined;
var mem: Memory = undefined;
var output_buffer: [4096]u8 = undefined;
var output_len: usize = 0;
var input_buffer: [256]u8 = undefined;
var input_len: usize = 0;
var pending_syscall: u32 = 0;
var parsed_labels: LabelTable = undefined;
var instructions_list: std.ArrayList(Instruction) = .empty;

export fn init() void {
    cpu = Cpu.init();
    mem = Memory.init();
    output_len = 0;
    input_len = 0;
    pending_syscall = 0;
}

export fn getOutputPtr() [*]const u8 {
    return &output_buffer;
}

export fn getOutputLen() usize {
    return output_len;
}

export fn clearOutput() void {
    output_len = 0;
}

export fn isWaitingForInput() bool {
    return pending_syscall != 0;
}

export fn provideInput(noalias ptr: [*]const u8, len: usize) void {
    const bytes = ptr[0..len];
    const to_copy = @min(len, input_buffer.len);
    @memcpy(input_buffer[0..to_copy], bytes[0..to_copy]);
    input_len = to_copy;
    // Don't reset pending_syscall here, it's needed in continueAfterInput
}

export fn getInputValue() i32 {
    if (input_len == 0) return 0;
    const value = std.fmt.parseInt(i32, input_buffer[0..input_len], 10) catch 0;
    // Don't reset input_len here if we want to reuse it? strictly it's one-shot usually
    // But let's keep behavior similar for now or just rely on continueAfterInput
    return value;
}

fn appendOutput(noalias str: []const u8) void {
    const remaining = output_buffer.len - output_len;
    const to_copy = @min(remaining, str.len);
    @memcpy(output_buffer[output_len .. output_len + to_copy], str[0..to_copy]);
    output_len += to_copy;
}

pub fn handleSyscallWasm(noalias cpu_ptr: *Cpu, noalias mem_ptr: *Memory) void {
    const v0 = cpu_ptr.regs[@intFromEnum(Register.v0)];
    const a0 = cpu_ptr.regs[@intFromEnum(Register.a0)];

    switch (v0) {
        1 => { // print_int
            var buf: [32]u8 = undefined;
            const str = std.fmt.bufPrint(&buf, "{d}", .{cpu_ptr.regs[@intFromEnum(Register.a0)]}) catch "?";
            appendOutput(str);
        },
        2 => { // print_float
            var buf: [64]u8 = undefined;
            const str = std.fmt.bufPrint(&buf, "{d}", .{cpu_ptr.fregs[12]}) catch "?";
            appendOutput(str);
        },
        4 => { // print_str
            var addr = a0;
            const DATA_START = @import("memory.zig").DATA_START;
            while (addr < DATA_START + mem_ptr.data.len) {
                const c = mem_ptr.data[addr - DATA_START];
                if (c == 0) break;
                appendOutput(&[_]u8{c});
                addr += 1;
            }
        },
        5 => { // read_int
            pending_syscall = 5;
        },
        6 => { // read_float
            pending_syscall = 6;
        },
        10 => { // exit
            cpu_ptr.pc = 0; // Set PC to 0 to trigger termination in runLoop
        },
        11 => { // print_char
            appendOutput(&[_]u8{@as(u8, @intCast(a0))});
        },
        12 => { // read_char
            pending_syscall = 12;
        },
        else => {},
    }
}

fn checkInputStatus() bool {
    return isWaitingForInput();
}

pub fn runUntilBlockOrExit() ?i32 {
    const res = exec.runLoop(&cpu, &mem, instructions_list.items, &parsed_labels, &checkInputStatus);
    if (res == .Blocked) return 1;
    return null;
}

export fn run(noalias code_ptr: [*]const u8, code_len: usize) i32 {
    init();

    const code = code_ptr[0..code_len];

    const parsed = parser.parseProgram(allocator, code, &mem) catch {
        const err_msg = "Parse error\n";
        appendOutput(err_msg);
        return -1;
    };

    parsed_labels = parsed.labels;

    instructions_list = std.ArrayList(Instruction).empty;

    for (parsed.text) |line| {
        const instr = decode(line) orelse continue;
        instructions_list.append(allocator, instr) catch {
            const err_msg = "Memory error\n";
            appendOutput(err_msg);
            return -1;
        };
    }

    const result = runUntilBlockOrExit();
    if (result) |r| {
        return r;
    }

    allocator.free(parsed.text);

    return 0;
}

export fn continueAfterInput() i32 {
    if (input_len > 0) {
        const input_slice = input_buffer[0..input_len];
        if (pending_syscall == 5) { // read_int
             const value = std.fmt.parseInt(i32, input_slice, 10) catch 0;
             cpu.regs[@intFromEnum(Register.v0)] = @bitCast(value);
        } else if (pending_syscall == 6) { // read_float
             const value = std.fmt.parseFloat(f32, input_slice) catch 0.0;
             cpu.fregs[0] = value;
        } else if (pending_syscall == 12) { // read_char
             // check if we got a valid char, if not (e.g. empty or just whitespace if we want)
             // but usually for WASM prompt we get the whole string user typed.
             // if user just typed enter, we might get empty string or just newline
             if (input_slice.len > 0) {
                 cpu.regs[@intFromEnum(Register.v0)] = input_slice[0];
             } else {
                 // nothing provided? keep waiting? or return 0?
                 // Let's assume we got something.
                 cpu.regs[@intFromEnum(Register.v0)] = 0;
             }
        }
    }
    pending_syscall = 0;
    input_len = 0;

    const result = runUntilBlockOrExit();
    if (result) |r| {
        return r;
    }

    instructions_list.deinit(allocator);

    return 0;
}

export fn getRegister(reg: u8) u32 {
    if (reg >= 32) return 0;
    return cpu.regs[reg];
}

export fn getPC() u32 {
    return cpu.pc;
}
