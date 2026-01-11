const std = @import("std");

pub const Node = union(enum) {
    nil: void,
    int: i32,
    symbol: []const u8,
    list: []Node,

    fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        switch (self) {
            .list => |items| allocator.free(items),
            else => {},
        }
    }
};
