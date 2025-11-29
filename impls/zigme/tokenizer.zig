const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

fn nth(s: []const u8, i: usize) ?u8 {
    return if (i < s.len) s[i] else null;
}

inline fn inc(i: usize) usize {
    return i + 1;
}

pub fn tokenize(allocator: Allocator, s: []const u8) ![][]const u8 {
    var tokens = try ArrayList([]const u8).initCapacity(allocator, 0);
    defer tokens.deinit(allocator);

    var start: usize = 0;
    var unquoteSplicing = false;
    var withinString = false;
    var withinComment = false;
    for (s, 0..) |c, i| {
        if (unquoteSplicing) {
            try tokens.append(allocator, "~@");
            start = inc(i);
            unquoteSplicing = false;
            continue;
        }

        if (withinString) {
            if (c == '"' and s[i - 1] != '\\') {
                try tokens.append(allocator, s[start..inc(i)]);
                start = inc(i);
                withinString = false;
            }
            continue;
        }

        if (withinComment) {
            if (c == 10) {
                try tokens.append(allocator, s[start..i]);
                start = inc(i);
                withinComment = false;
            }
            continue;
        }

        if (c == '~' and nth(s, inc(i)) == '@') {
            unquoteSplicing = true;
            continue;
        }

        switch (c) {
            // whitespace
            ' ', ',', '\t', '\n', 11, 12, '\r' => {
                if (start != i)
                    try tokens.append(allocator, s[start..i]);
                start = inc(i);
            },
            // delimiter
            '(', ')', '[', ']', '{', '}', '\'', '`', '~', '^', '@' => {
                if (start != i)
                    try tokens.append(allocator, s[start..i]);
                try tokens.append(allocator, s[i..inc(i)]);
                start = inc(i);
            },
            '"' => withinString = true,
            ';' => withinComment = true,
            else => {},
        }
    }

    if (start != s.len) {
        try tokens.append(allocator, s[start..s.len]);
    }

    return tokens.toOwnedSlice(allocator);
}

test "tokenizes symbol" {
    const input = "token";
    const tokens = try tokenize(std.testing.allocator, input);
    defer std.testing.allocator.free(tokens);

    const expected = &[_][]const u8{"token"};
    try std.testing.expectEqual(expected.len, tokens.len);
    try std.testing.expectEqualStrings(expected[0], tokens[0]);
}

test "tokenizes number with multiple digits" {
    const input = "42";
    const tokens = try tokenize(std.testing.allocator, input);
    defer std.testing.allocator.free(tokens);

    const expected = &[_][]const u8{"42"};
    try std.testing.expectEqualStrings(expected[0], tokens[0]);
}

test "tokenizes multiple numbers" {
    const input = "42 23 51";
    const tokens = try tokenize(std.testing.allocator, input);
    defer std.testing.allocator.free(tokens);

    const expected = &[_][]const u8{ "42", "23", "51" };
    try std.testing.expectEqualStrings(expected[0], tokens[0]);
}

test "tokenizes vector" {
    const input = "[1 2 3]";
    const tokens = try tokenize(std.testing.allocator, input);
    defer std.testing.allocator.free(tokens);

    const expected = &[_][]const u8{ "[", "1", "2", "3", "]" };
    for (expected, tokens) |exp, actual| {
        try std.testing.expectEqualStrings(exp, actual);
    }
}

test "tokenizes unquote-splicing delimiter" {
    const input = "~@(abc)";
    const tokens = try tokenize(std.testing.allocator, input);
    defer std.testing.allocator.free(tokens);

    const expected = &[_][]const u8{ "~@", "(", "abc", ")" };
    for (expected, tokens) |exp, actual| {
        try std.testing.expectEqualStrings(exp, actual);
    }
}

test "tokenizes string" {
    const input = "\"hello\n\\\"world\\\"'~@\"";
    const tokens = try tokenize(std.testing.allocator, input);
    defer std.testing.allocator.free(tokens);

    const expected = &[_][]const u8{"\"hello\n\\\"world\\\"'~@\""};
    for (expected, tokens) |exp, actual| {
        try std.testing.expectEqualStrings(exp, actual);
    }
}

test "tokenizes multiline string" {
    const input =
        \\"hello,
        \\world!
        \\It sees back!"
    ;
    const tokens = try tokenize(std.testing.allocator, input);
    defer std.testing.allocator.free(tokens);

    const expected = &[_][]const u8{"\"hello,\nworld!\nIt sees back!\""};
    for (expected, tokens) |exp, actual| {
        try std.testing.expectEqualStrings(exp, actual);
    }
}

test "tokenizes comments" {
    const input =
        \\; func
        \\(+ 1 2)
        \\;; comment
    ;
    const tokens = try tokenize(std.testing.allocator, input);
    defer std.testing.allocator.free(tokens);

    const expected = &[_][]const u8{ "; func", "(", "+", "1", "2", ")", ";; comment" };
    for (expected, tokens) |exp, actual| {
        try std.testing.expectEqualStrings(exp, actual);
    }
}

test "final boss" {
    const input =
        \\;; adds numbers
        \\(defn add [& numbers]
        \\  (apply + numbers))
        \\
        \\(defn get-token-frequencies
        \\  "Removes comments and gets frequencies of tokens"
        \\  [tokens]
        \\  (->> tokens
        \\       (remove comment?)
        \\       frequencies))
        \\
    ;
    const tokens = try tokenize(std.testing.allocator, input);
    defer std.testing.allocator.free(tokens);

    const expected = &[_][]const u8{
        ";; adds numbers",
        "(",
        "defn",
        "add",
        "[",
        "&",
        "numbers",
        "]",
        "(",
        "apply",
        "+",
        "numbers",
        ")",
        ")",
        "(",
        "defn",
        "get-token-frequencies",
        "\"Removes comments and gets frequencies of tokens\"",
        "[",
        "tokens",
        "]",
        "(",
        "->>",
        "tokens",
        "(",
        "remove",
        "comment?",
        ")",
        "frequencies",
        ")",
        ")",
    };
    for (expected, tokens) |exp, actual| {
        try std.testing.expectEqualStrings(exp, actual);
    }
}
