const std = @import("std");
const Cpu = @import("cpu.zig").Cpu;
const Memory = @import("memory.zig").Memory;
const parser = @import("parser.zig");
const exec = @import("exec.zig");
const Instruction = @import("instruction.zig");

pub fn main(init: std.process.Init.Minimal) !void {
    // TODO: checkout smp_allocator or maybe even FixedBufferAllocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const init_args = init.args;

    const args = try std.process.Args.toSlice(init_args, allocator);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <assembly_file>\n", .{args[0]});
        return;
    }

    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    const io = threaded.io();

    const asm_file_path = args[1];
    const asm_source = try std.Io.Dir.cwd().readFileAlloc(io, asm_file_path, allocator, std.Io.Limit.unlimited);

    var cpu = Cpu.init();
    const mem = try allocator.create(Memory);
    mem.* = Memory.init();
    const parsed = try parser.parseProgram(allocator, asm_source, mem);

    var instructions: std.ArrayList(Instruction.Instruction) = .empty;
    defer instructions.deinit(allocator);

    for (parsed.text) |line| {
        const instr = Instruction.decode(line) orelse {
            std.debug.print("Warning: could not decode instruction: {s}\n", .{line});
            continue;
        };
        try instructions.append(allocator, instr);
    }

    const res = exec.runLoop(&cpu, mem, instructions.items, &parsed.labels, null);
    _ = res; // no blocking in main
}
