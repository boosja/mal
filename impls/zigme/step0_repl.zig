const std = @import("std");

var stdin_buffer: [512]u8 = undefined;
var stdin_reader_wrapper = std.fs.File.stdin().reader(&stdin_buffer);
const reader: *std.Io.Reader = &stdin_reader_wrapper.interface;

var stdout_buffer: [512]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const stdout: *std.Io.Writer = &stdout_writer.interface;

fn readline(prompt: []const u8) ![]const u8 {
    try stdout.writeAll(prompt);
    try stdout.flush();
    return try reader.takeDelimiterExclusive('\n');
}

fn READ(input: []const u8) []const u8 {
    return input;
}

fn EVAL(input: []const u8) []const u8 {
    return input;
}

fn PRINT(input: []const u8) !void {
    try stdout.writeAll(input);
    try stdout.writeAll("\n");
}

fn rep(input: []const u8) !void {
    const read_input = READ(input);
    const eval_input = EVAL(read_input);
    try PRINT(eval_input);
}

pub fn main() !void {
    while (readline("user> ")) |line| {
        try rep(line);
    } else |err| switch (err) {
        error.WriteFailed => return err,
        error.EndOfStream => {},
        error.StreamTooLong => return err,
        error.ReadFailed => return err,
    }
}
