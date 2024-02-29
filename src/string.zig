const std = @import("std");
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub inline fn align_len(length: usize) usize {
    return (length - (length % 4));
}

fn increase_capacity(capacity: usize) usize {
    const aligned_cap = align_len(capacity);
    var doubled =  aligned_cap << 1;
    doubled -= align_len(doubled / 4);
    return doubled;
}
/// Heap allocated string struct
pub const String = struct {
    const Self = @This();
    const Error = error{
        OutOfBounds,
    };

    data: [*]u8,
    len: usize,
    capacity: usize,
    allocator: Allocator,

    /// Allocates memory on heap and copies `string` into that memory
    pub fn init(string: []const u8, allocator: Allocator) !Self {
        const capacity = align_len(string.len + 8);
        const mem = try Self.alloc_mem(allocator, capacity);
        std.mem.copyForwards(u8, mem, string);

        return String{
            .data = mem.ptr,
            .len = string.len,
            .capacity = capacity,
            .allocator = allocator,
        };
    }

    /// Does not allocate memory on heap.
    /// Stores `string` provided directly.
    /// Make sure the allocator is the same.
    pub fn from_alloced(string: []u8, allocator: Allocator) Self {
        return String{
            .data = string.ptr,
            .capacity = string.len,
            .len = string.len,
            .allocator = allocator,
        };
    }

    pub fn concat(self: *Self, string: []const u8) !Self {
        var new = try self.clone();
        try new.push_str(string);
        return new;
    }

    pub fn get(self: *Self, index: usize) ?u8 {
        if (self.len == 0) return null;
        if (index >= self.len) return null;
        return self.data[index];
    }

    pub fn set(self: *Self, char: u8, index: usize) Error!void {
        if (self.len <= index) return Error.OutOfBounds;
        self.data[index] = char;
    }

    pub fn split(self: *Self, delim: u8) !ArrayList([]u8) {
        var list = ArrayList([]u8).init(self.allocator);

        var start: usize = 0;

        for (self.data[0..self.len], 0..) |char, i| {
            if (char == delim) {
                try list.append(self.data[start..i]);
                start = i + 1;
            }
        }

        try list.append(self.data[start..self.len]);

        return list;
    }

    pub fn slice(self: *Self, start: usize, end: usize) Error![]u8 {
        if (start >= self.len() or end >= self.len()) return Error.OutOfBounds;
        return self.data[start..end];
    }

    fn preprocess_pattern(self: *Self, pattern: []const u8) ![]usize {
        var lps = try self.allocator.alloc(usize, pattern.len);
        lps[0] = 0;

        var prefix_len: usize = 0;
        var i: usize = 1;
        while (i < pattern.len) {
            if (pattern[i] == pattern[prefix_len]) {
                prefix_len += 1;
                lps[i] = prefix_len;
                i += 1;
            } else {
                if (prefix_len != 0) {
                    prefix_len = lps[prefix_len - 1];
                } else {
                    lps[i] = 0;
                    i += 1;
                }
            }
        }

        return lps;
    }

    pub fn includes(self: *Self, matcher: []const u8) !bool {
        if (self.len < matcher.len) return false;
        const lps = try self.preprocess_pattern(matcher);
        defer self.allocator.free(lps);
        var i:usize = 0;
        var j:usize = 0;
        while (self.len - i >= matcher.len - j) {
            if (matcher[j] == self.data[i]) {
                i += 1;
                j += 1;
            }

            if (j == matcher.len) {
                return true;
            } else if (i < self.len and matcher[j] != self.data[i]) {
                if (j != 0) { j = lps[j - 1]; }
                else i += 1;
            }
        }

        return false;
    }

    pub fn repeat(self: *Self, times: usize) !void {
        if (times == 0) {
            self.len = 0;
            return;
        }
        const initial_len = self.len;
        const new_size = initial_len * times;
        if (new_size >= self.capacity) {
            try self.realloc(new_size);
        }

        for (1..times) |i| {
            std.mem.copyForwards(
                u8, 
                self.data[(initial_len * i)..self.capacity], 
                self.data[0..initial_len]
            );
        }
        self.len *= times;
    }

    pub fn push_char(self: *Self, char: u8) !void {
        if (self.capacity <= self.len + 1) {
            try self.realloc(self.len + 1);
        }

        self.data[self.len] = char;
        self.len += 1;
    }

    pub fn push_str(self: *Self, string: []const u8) !void {
        if (self.capacity <= self.len + string.len) {
            try self.realloc(self.len + string.len);
        }

        std.mem.copyForwards(u8, self.remaining_slice(), string);
        self.len += string.len;
    }

    pub fn clone(self: *Self) !Self {
        return String.init(self.as_slice(), self.allocator);
    }

    fn realloc(self: *Self, new_size: usize) !void {
        const old_cap = self.capacity;
        self.capacity = increase_capacity(self.capacity + new_size);
        const mem = try self.allocator.realloc(self.data[0..old_cap], self.capacity);
        self.data = mem.ptr;
    }

    fn alloc_mem(allocator: Allocator, size: usize) ![]u8 {
        return allocator.alloc(u8, size);
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}", .{self.data[0..self.len]});
    }

    pub fn as_ptr(self: *Self) *u8 {
        return self.data.ptr;
    }

    pub fn clear(self: *Self) void {
        self.len = 0;
    }

    pub fn push_int(self: *Self, value: usize) !void {
        const buf_len = std.fmt.count("{}", .{value});
        if ((self.len + buf_len) >= self.capacity) try self.realloc(self.len + buf_len);
        _ = try std.fmt.bufPrint(self.remaining_slice(), "{d}", .{value});
        self.len += buf_len;
    }

    pub fn as_slice(self: *Self) []u8 {
        return self.data[0..self.len];
    }


    fn full_slice(self: *Self) []u8 {
        return self.data[0..self.capacity];
    }

    fn remaining_slice(self: *Self) []u8 {
        return self.data[self.len..self.capacity];
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data[0..self.capacity]);
    }
};

test "String -- init" {
    const allocator = std.testing.allocator;
    var str = try String.init("abc test", allocator);
    const fmt = try std.fmt.allocPrint(allocator, "{s}", .{str});
    defer {
        str.deinit();
        allocator.free(fmt);
    }

    try std.testing.expectEqualStrings(fmt, "abc test");
}

test "String -- concat" {
    const allocator = std.testing.allocator;
    var str = try String.init("abc test", allocator);
    var new = try str.concat(" hello yay");
    defer {
        str.deinit();
        new.deinit();
    }

    try expect(std.mem.eql(u8, new.as_slice(), "abc test hello yay"));
    try expect(std.mem.eql(u8, str.as_slice(), "abc test"));
}

test "String -- split" {
    const allocator = std.testing.allocator;
    var str = try String.init("abc test ewd awd", allocator);
    const list = try str.split(' ');

    defer {
        str.deinit();
        list.deinit();
    }

    try std.testing.expectEqual(list.items.len, 4);
    try std.testing.expectEqualStrings("abc", list.items[0]);
    try std.testing.expectEqualStrings("test", list.items[1]);
    try std.testing.expectEqualStrings("ewd", list.items[2]);
    try std.testing.expectEqualStrings("awd", list.items[3]);
}

test "String -- includes" {
    const allocator = std.testing.allocator;
    var str = try String.init("abc test ewd awd", allocator);
    defer str.deinit();

    try expect(try str.includes("ab") == true);
    try expect(try str.includes("xy") == false);
    try expect(try str.includes("awd") == true);
}

test "String -- repeat" {
    const allocator = std.testing.allocator;
    var str = try String.init("abc", allocator);
    defer str.deinit();

    try str.repeat(3);
    try std.testing.expectEqualStrings(str.as_slice(), "abcabcabc");
}

test "String -- push_char" {
    const allocator = std.testing.allocator;
    var str = try String.init("abc", allocator);
    defer str.deinit();

    try str.push_char('d');
    try std.testing.expectEqualStrings(str.as_slice(), "abcd");
}

test "String -- push_str" {
    const allocator = std.testing.allocator;
    var str = try String.init("abc", allocator);
    defer str.deinit();

    try str.push_str("def");
    try std.testing.expectEqualStrings(str.as_slice(), "abcdef");
}

test "String -- push_int" {
    const allocator = std.testing.allocator;
    var str = try String.init("abc", allocator);
    defer str.deinit();

    try str.push_int(12);

    try std.testing.expectEqualStrings("abc12", str.as_slice());
}
