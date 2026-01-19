const std = @import("std");
const Memory = @import("memory.zig").Memory;
const LabelTable = @import("labels.zig").LabelTable;
const DATA_START = @import("memory.zig").DATA_START;

pub const ParsedProgram = struct {
    text: []const []const u8, // raw instruction strings for now
    labels: LabelTable,
    data_end: u32,
};

pub fn parseProgram(allocator: std.mem.Allocator, noalias src: []const u8, noalias mem: *Memory) !ParsedProgram {
    var lines = std.mem.tokenizeAny(u8, src, "\r\n");
    var labels = LabelTable.init(allocator);
    var text_instructions: std.ArrayList([]const u8) = .empty;
    defer text_instructions.deinit(allocator);
    var in_data = false;
    var in_text = false;
    var data_ptr: u32 = DATA_START;
    var text_instruction_count: u32 = 0;

    while (lines.next()) |line_raw| {
        var line = std.mem.trim(u8, line_raw, " \t");
        if (line.len == 0) continue;

        // strip comments
        if (std.mem.indexOfScalar(u8, line, '#')) |comment_idx| {
            line = std.mem.trim(u8, line[0..comment_idx], " \t");
            if (line.len == 0) continue;
        }

        if (std.mem.eql(u8, line, ".data")) {
            in_data = true;
            in_text = false;
            continue;
        }
        if (std.mem.eql(u8, line, ".text")) {
            in_data = false;
            in_text = true;
            continue;
        }

        // handle label definitions
        if (std.mem.findScalar(u8, line, ':')) |colon_idx| {
            const label = line[0..colon_idx];
            if (in_data) {
                try labels.put(label, data_ptr);
            } else if (in_text) {
                const text_addr = @import("memory.zig").TEXT_START + (text_instruction_count * 4);
                try labels.put(label, text_addr);
            }

            if (colon_idx + 1 < line.len) {
                line = std.mem.trim(u8, line[colon_idx + 1 ..], " \t");
                if (line.len == 0) continue;
                // Fall through to process the rest of the line
            } else {
                continue;
            }
        }

        if (in_data) {
            // example: msg1: .asciiz "Hello"
            // or
            // msg1:
            // .asciiz "Hello"
            if (std.mem.find(u8, line, ".asciiz")) |index| {
                const quote_start = std.mem.findScalar(u8, line[index..], '"').?;
                const quote_end = std.mem.findScalarLast(u8, line[index..], '"').?;
                const str = line[quote_start + 1 .. quote_end];
                var i: usize = 0;
                while (i < str.len) : (i += 1) {
                    var char = str[i];
                    if (char == '\\' and i + 1 < str.len) {
                        const next_char = str[i + 1];
                        switch (next_char) {
                            'n' => char = '\n',
                            't' => char = '\t',
                            'r' => char = '\r',
                            '0' => char = 0,
                            '\\' => char = '\\',
                            '"' => char = '"',
                            else => {},
                        }
                        if (char != str[i]) i += 1;
                    }
                    mem.data[(data_ptr - DATA_START)] = char;
                    data_ptr += 1;
                }
                mem.data[(data_ptr - DATA_START)] = 0;
                data_ptr += 1;
            } else if (std.mem.find(u8, line, ".space")) |index| {
                var parts = std.mem.tokenizeAny(u8, line[index + 6 ..], " \t");
                const size_str = parts.next().?;
                const size = std.fmt.parseInt(u32, size_str, 0) catch continue;
                for (0..size) |i| {
                    mem.data[(data_ptr - DATA_START) + i] = 0;
                }
                data_ptr += size;
            }
        } else if (in_text) {
            try text_instructions.append(allocator, line);
            text_instruction_count += 1;
        }
    }

    return ParsedProgram{
        .text = try text_instructions.toOwnedSlice(allocator),
        .labels = labels,
        .data_end = data_ptr,
    };
}
