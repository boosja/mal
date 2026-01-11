const std = @import("std");
const Allocator = std.mem.Allocator;
const reader = @import("reader.zig");
const printer = @import("printer.zig");
const Node = @import("types.zig").Node;

var stdin_buffer: [512]u8 = undefined;
var stdin_reader_wrapper = std.fs.File.stdin().reader(&stdin_buffer);
const stdin: *std.Io.Reader = &stdin_reader_wrapper.interface;

var stdout_buffer: [512]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout: *std.Io.Writer = &stdout_writer.interface;

fn readline(prompt: []const u8) ![]const u8 {
    defer stdin.tossBuffered();

    try stdout.writeAll(prompt);
    try stdout.flush();
    return try stdin.takeDelimiterExclusive('\n');
}

fn READ(allocator: Allocator, input: []const u8) !Node {
    return try reader.read_str(allocator, input);
}

fn EVAL(input: Node) Node {
    return input;
}

fn PRINT(allocator: Allocator, input: Node) !void {
    const str = try printer.pr_str(allocator, input);

    try stdout.writeAll(str);
    try stdout.writeAll("\n");
    try stdout.flush();
}

fn rep(allocator: Allocator, input: []const u8) !void {
    const read_input = try READ(allocator, input);
    const eval_input = EVAL(read_input);
    try PRINT(allocator, eval_input);
}

pub fn main() !void {
    while (readline("user> ")) |line| {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const allocator = arena.allocator();

        rep(allocator, line) catch |e| switch (e) {
            error.EOF => {
                try stdout.writeAll("Parentheses are unbalanced!\n");
                try stdout.flush();
            },
            else => return e,
        };
    } else |err| switch (err) {
        error.WriteFailed => return err,
        error.EndOfStream => {},
        error.StreamTooLong => return err,
        error.ReadFailed => return err,
    }
}
