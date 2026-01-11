const std = @import("std");
const Node = @import("types.zig").Node;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn pr_str(allocator: Allocator, tree: Node) ![]const u8 {
    var result = try ArrayList(u8).initCapacity(allocator, 0);
    errdefer result.deinit(allocator);

    switch (tree) {
        .nil => {},
        .int => |number| {
            const numStr = try std.fmt.allocPrint(allocator, "{d}", .{number});
            defer allocator.free(numStr);

            try result.appendSlice(allocator, numStr);
        },
        .symbol => |s| try result.appendSlice(allocator, s),
        .list => |nodes| {
            try result.append(allocator, '(');

            for (nodes, 0..) |node, i| {
                const s = try pr_str(allocator, node);
                defer allocator.free(s);

                try result.appendSlice(allocator, s);

                // if not last?
                if (i < nodes.len - 1) {
                    try result.append(allocator, ' ');
                }
            }

            try result.append(allocator, ')');
        },
    }

    return try result.toOwnedSlice(allocator);
}

test "pr_str" {
    var list = [_]Node{
        .{ .symbol = "+" },
        .{ .int = 1 },
        .{ .int = 2 },
    };
    const ast: Node = .{ .list = list[0..] };

    const str = try pr_str(std.testing.allocator, ast);
    defer std.testing.allocator.free(str);

    try std.testing.expectEqualStrings("(+ 1 2)", str);
}
