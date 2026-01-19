const std = @import("std");
const TEXT_START = @import("memory.zig").TEXT_START;

pub const Register = enum(u8) {
    zero = 0,
    at,
    v0,
    v1,
    a0,
    a1,
    a2,
    a3,
    t0,
    t1,
    t2,
    t3,
    t4,
    t5,
    t6,
    t7,
    s0,
    s1,
    s2,
    s3,
    s4,
    s5,
    s6,
    s7,
    t8,
    t9,
    k0,
    k1,
    gp,
    sp,
    fp,
    ra,
};

pub const REGISTER_MAP = blk: {
    const fields = @typeInfo(Register).@"enum".fields;
    var kvs: [fields.len]struct { []const u8, u8 } = undefined;

    for (fields, 0..) |field, i| {
        kvs[i] = .{ field.name, i };
    }

    break :blk std.StaticStringMap(u8).initComptime(kvs);
};

pub fn parseReg(noalias name: []const u8) u8 {
    if (name.len < 2 or name[0] != '$') return 0;

    const r = name[1..]; // remove '$'
    return REGISTER_MAP.get(r) orelse 0;
}

pub const Cpu = struct {
    regs: [32]u32,
    fregs: [32]f32,
    pc: u32,

    pub fn init() Cpu {
        var cpu = Cpu{
            .regs = [_]u32{0} ** 32,
            .fregs = [_]f32{0} ** 32,
            .pc = TEXT_START,
        };
        cpu.regs[@intFromEnum(Register.sp)] = @import("memory.zig").STACK_START; // stack pointer
        return cpu;
    }
};
