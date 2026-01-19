pub const TEXT_START: u32 = 0x00400000;
pub const DATA_START: u32 = 0x10010000;
pub const MEM_SIZE: usize = 1024 * 1024 * 8; // 8 MB
pub const STACK_START: u32 = TEXT_START + MEM_SIZE - 4;

pub const Memory = struct {
    data: [MEM_SIZE]u8,

    pub fn init() Memory {
        return Memory{ .data = [_]u8{0} ** MEM_SIZE };
    }

    /// reads a 32-bit word from memory at the specified address, bit by bit, big-endian
    pub fn readWord(noalias self: *Memory, addr: u32) u32 {
        const offset = addr - TEXT_START;
        return (@as(u32, self.data[offset]) << 24) |
            (@as(u32, self.data[offset + 1]) << 16) |
            (@as(u32, self.data[offset + 2]) << 8) |
            @as(u32, self.data[offset + 3]);
    }

    /// writes a 32-bit word to memory at the specified address, bit by bit, big-endian
    pub fn writeWord(noalias self: *Memory, addr: u32, val: u32) void {
        const offset = addr - TEXT_START;
        self.data[offset] = @truncate(val >> 24);
        self.data[offset + 1] = @truncate(val >> 16);
        self.data[offset + 2] = @truncate(val >> 8);
        self.data[offset + 3] = @truncate(val);
    }
};
