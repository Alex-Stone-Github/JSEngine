const std = @import("std");
const token = @import("token.zig");

pub const JSValueType = union(enum) {
    JSNumber: f64,
    JSBoolean: bool,
    JSString: []const u8,

    pub fn printRepr(self: @This()) void {
        switch (self) {
            .JSNumber => |number| {
                std.debug.print("{}\n", .{number});
            },
            .JSBoolean => |boolean| {
                std.debug.print("{}\n", .{boolean});
            },
            .JSString => |string| {
                std.debug.print("{s}\n", .{string});
            }
        }
    }
};

pub const ASTFunctionCall = struct {
    name: []const u8,
    arguments: std.ArrayList(ASTExpression),
};

pub const ASTExpression = union(enum) {
    Literal: JSValueType,
    Label: []const u8,
    Operation: ASTFunctionCall,

    const Self = @This();

    const levelDepth = 4; 

    pub fn printSubTree(self: Self, padlevel: usize) void {
        switch (self) {
            .Literal => |lit| {
                lit.printRepr();
            },
            .Label => |label| {
                std.debug.print("{s}\n", .{label});
            },
            .Operation => |op| {
                std.debug.print("Operation: {s}\n", .{op.name});
                for (op.arguments.items) |argument| {
                    for (0..padlevel+levelDepth) |_| std.debug.print(" ", .{});
                    argument.printSubTree(padlevel + levelDepth);
                }
            },
        }
    }
    pub fn deinit(self: Self, alloc: std.mem.Allocator) void {
        switch (self) {
            .Operation => |op| {
                for (op.arguments.items) |argument| {
                    argument.deinit(alloc);
                }
                var argumentMut = op.arguments;
                argumentMut.deinit(alloc);
            },
            else => {},
        }
    }
};
