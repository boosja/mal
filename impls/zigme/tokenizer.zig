const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

fn isWhitespace(c: u8) bool {
    return switch (c) {
        ' ',
        ',',
        9, // horizontal tab \t
        10, // line feed \n
        11, // vertical tab \v
        12, // form feed \f
        13, // carriage return \r
        => true,
        else => false,
    };
}

test "checks if whitespace" {
    try std.testing.expect(isWhitespace(' '));
    try std.testing.expect(isWhitespace(','));
    try std.testing.expect(isWhitespace(9));
    try std.testing.expect(isWhitespace(10));
    try std.testing.expect(isWhitespace(11));
    try std.testing.expect(isWhitespace(12));
    try std.testing.expect(isWhitespace(13));
    try std.testing.expect(!isWhitespace('a'));
}

fn isDelimiter(c: u8) bool {
    return switch (c) {
        '(', ')', '[', ']', '{', '}', '\'', '`', '~', '^', '@' => true,
        else => false,
    };
}

test "checks if delimiter" {
    try std.testing.expect(isDelimiter('('));
    try std.testing.expect(isDelimiter(')'));
    try std.testing.expect(isDelimiter('['));
    try std.testing.expect(isDelimiter(']'));
    try std.testing.expect(isDelimiter('{'));
    try std.testing.expect(isDelimiter('}'));
    try std.testing.expect(isDelimiter('\''));
    try std.testing.expect(isDelimiter('`'));
    try std.testing.expect(isDelimiter('~'));
    try std.testing.expect(isDelimiter('^'));
    try std.testing.expect(isDelimiter('@'));
    try std.testing.expect(!isDelimiter('a'));
}

fn getChar(i: usize, s: []const u8) ?u8 {
    return if (i < s.len) s[i] else null;
}

fn appendIfPopulated(allocator: Allocator, tokens: *ArrayList([]const u8), token: *ArrayList(u8)) !void {
    if (token.items.len > 0) {
        try tokens.append(allocator, try token.toOwnedSlice(allocator));
    }
}

pub fn tokenize(allocator: Allocator, s: []const u8) ![][]const u8 {
    var tokens = try ArrayList([]const u8).initCapacity(allocator, 0);

    var currentToken = try ArrayList(u8).initCapacity(allocator, 0);
    defer currentToken.deinit(allocator);

    var i: usize = 0;
    while (getChar(i, s)) |c| : (i += 1) {
        if (isWhitespace(c)) {
            try appendIfPopulated(allocator, &tokens, &currentToken);
        } else if (c == '~' and getChar(i + 1, s) == '@') {
            var unquoteSplicing = try allocator.alloc(u8, 2);
            unquoteSplicing[0] = c;
            unquoteSplicing[1] = '@';
            try tokens.append(allocator, unquoteSplicing);
            i += 1;
        } else if (isDelimiter(c)) {
            try appendIfPopulated(allocator, &tokens, &currentToken);

            var delim = try allocator.alloc(u8, 1);
            delim[0] = c;
            try tokens.append(allocator, delim);
        } else if (c == '"') {
            try currentToken.append(allocator, c);
            i += 1;
            while (getChar(i, s)) |sc| : (i += 1) {
                try currentToken.append(allocator, sc);
                if (sc == '"' and getChar(i - 1, s) != '\\') {
                    try appendIfPopulated(allocator, &tokens, &currentToken);
                    break;
                }
            }
        } else if (c == ';') {
            try currentToken.append(allocator, c);
            i += 1;
            while (getChar(i, s)) |sc| : (i += 1) {
                if (sc == 10) {
                    try appendIfPopulated(allocator, &tokens, &currentToken);
                    break;
                }
                try currentToken.append(allocator, sc);
            }
        } else {
            try currentToken.append(allocator, c);
        }
    }

    try appendIfPopulated(allocator, &tokens, &currentToken);

    return tokens.toOwnedSlice(allocator);
}

test "tokenizes symbol" {
    const input = "token";
    const tokens = try tokenize(std.testing.allocator, input);
    defer {
        for (tokens) |token| {
            std.testing.allocator.free(token);
        }
        std.testing.allocator.free(tokens);
    }

    const expected = &[_][]const u8{"token"};
    try std.testing.expectEqual(expected.len, tokens.len);
    try std.testing.expectEqualStrings(expected[0], tokens[0]);
}

test "tokenizes number with multiple digits" {
    const input = "42";
    const tokens = try tokenize(std.testing.allocator, input);
    defer {
        for (tokens) |token| {
            std.testing.allocator.free(token);
        }
        std.testing.allocator.free(tokens);
    }

    const expected = &[_][]const u8{"42"};
    try std.testing.expectEqualStrings(expected[0], tokens[0]);
}

test "tokenizes multiple numbers" {
    const input = "42 23 51";
    const tokens = try tokenize(std.testing.allocator, input);
    defer {
        for (tokens) |token| {
            std.testing.allocator.free(token);
        }
        std.testing.allocator.free(tokens);
    }

    const expected = &[_][]const u8{ "42", "23", "51" };
    try std.testing.expectEqualStrings(expected[0], tokens[0]);
}

test "tokenizes vector" {
    const input = "[1 2 3]";
    const tokens = try tokenize(std.testing.allocator, input);
    defer {
        for (tokens) |token| {
            std.testing.allocator.free(token);
        }
        std.testing.allocator.free(tokens);
    }

    const expected = &[_][]const u8{ "[", "1", "2", "3", "]" };
    for (expected, tokens) |exp, actual| {
        try std.testing.expectEqualStrings(exp, actual);
    }
}

test "tokenizes unquote-splicing delimiter" {
    const input = "~@(abc)";
    const tokens = try tokenize(std.testing.allocator, input);
    defer {
        for (tokens) |token| {
            std.testing.allocator.free(token);
        }
        std.testing.allocator.free(tokens);
    }

    const expected = &[_][]const u8{ "~@", "(", "abc", ")" };
    for (expected, tokens) |exp, actual| {
        try std.testing.expectEqualStrings(exp, actual);
    }
}

test "tokenizes string" {
    const input = "\"hello\n\\\"world\\\"'~@\"";
    const tokens = try tokenize(std.testing.allocator, input);
    defer {
        for (tokens) |token| {
            std.testing.allocator.free(token);
        }
        std.testing.allocator.free(tokens);
    }

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
    defer {
        for (tokens) |token| {
            std.testing.allocator.free(token);
        }
        std.testing.allocator.free(tokens);
    }

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
    defer {
        for (tokens) |token| {
            std.testing.allocator.free(token);
        }
        std.testing.allocator.free(tokens);
    }

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
    defer {
        for (tokens) |token| {
            std.testing.allocator.free(token);
        }
        std.testing.allocator.free(tokens);
    }

    const expected = &[_][]const u8{ ";; adds numbers", "(", "defn", "add", "[", "&", "numbers", "]", "(", "apply", "+", "numbers", ")", ")", "(", "defn", "get-token-frequencies", "\"Removes comments and gets frequencies of tokens\"", "[", "tokens", "]", "(", "->>", "tokens", "(", "remove", "comment?", ")", "frequencies", ")", ")" };
    for (expected, tokens) |exp, actual| {
        try std.testing.expectEqualStrings(exp, actual);
    }
}
