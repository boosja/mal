const tokenize = @import("tokenizer.zig").tokenize;
const Node = @import("types.zig").Node;
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Reader = struct {
    tokens: [][]const u8,
    pos: u32 = 0,

    fn next(self: *Reader) ?[]const u8 {
        if (self.pos == self.tokens.len)
            return null;

        const t = self.tokens[self.pos];
        self.pos += 1;
        return t;
    }

    fn peek(self: *Reader) ?[]const u8 {
        if (self.pos == self.tokens.len)
            return null;

        return self.tokens[self.pos];
    }
};

fn read_list(allocator: Allocator, reader: *Reader) !Node {
    var list = try ArrayList(Node).initCapacity(allocator, 0);
    errdefer list.deinit(allocator);

    while (reader.next()) |_| {
        if (reader.peek()) |token| {
            if (token[0] == ')')
                break;
        } else return error.EOF;

        try list.append(allocator, try read_form(allocator, reader));
    } else {
        return error.EOF;
    }

    return .{ .list = try list.toOwnedSlice(allocator) };
}

fn isNumber(s: []const u8) bool {
    return switch (s[0]) {
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => true,
        else => false,
    };
}

fn read_atom(reader: *Reader) !Node {
    const token = reader.peek().?;
    if (isNumber(token)) {
        return .{ .int = try std.fmt.parseInt(i32, token, 0) };
    } else {
        return .{ .symbol = token };
    }
}

const ReadFormError = error{
    OutOfMemory,
    EOF,
    Overflow,
    InvalidCharacter,
};

fn read_form(allocator: Allocator, reader: *Reader) ReadFormError!Node {
    if (reader.peek()) |token| {
        return switch (token[0]) {
            '(' => try read_list(allocator, reader),
            else => try read_atom(reader),
        };
    }

    return Node.nil;
}

pub fn read_str(allocator: Allocator, s: []const u8) !Node {
    const tokens = try tokenize(allocator, s);
    var reader = Reader{ .tokens = tokens };
    return try read_form(allocator, &reader);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    try read_str(allocator, "(+ 1 2)");

    //std.debug.print("read: {}\n", .{reader.next()});
    //std.debug.print("peek: {}\n", .{reader.peek()});
    //std.debug.print("peek: {}\n", .{reader.peek()});
    //std.debug.print("read: {}\n", .{reader.next()});
    //std.debug.print("read: {}\n", .{reader.next()});

}
