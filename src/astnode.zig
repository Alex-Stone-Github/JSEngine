const std = @import("std");
const token = @import("token.zig");

pub const JSValueType = union(enum) {
    JSNumber: f64,
    JSBoolean: bool,
    JSString: []const u8,
    JSNull,

    const Self = @This();

    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .JSString => |str| alloc.free(str),
            else => {},
        }
    }

    pub fn clone(self: *const Self, alloc: std.mem.Allocator) !Self {
        switch (self.*) {
            .JSString => |str| {
                return JSValueType {
                    .JSString = try alloc.dupe(u8, str)
                };
            },
            else => return self.*,
        }
    }

    pub fn printRepr(self: *const Self) void {
        switch (self.*) {
            .JSNumber => |number| {
                std.debug.print("JSValueType({})\n", .{number});
            },
            .JSBoolean => |boolean| {
                std.debug.print("JSValueType({})\n", .{boolean});
            },
            .JSString => |string| {
                std.debug.print("JSValueType(\"{s}\")\n", .{string});
            },
            .JSNull => {
                std.debug.print("JSValueType(NULL)", .{});
            }
        }
    }
};

pub const ASTOperation = struct {
    arguments: []ASTExpression,
    primitive: ASTOperationPrimitive,

    const Self = @This();

    const CloneError = error { OutOfMemory };
    pub fn clone(self: *const Self, alloc: std.mem.Allocator) CloneError!Self {
        var newSelf: Self = undefined;
        newSelf.arguments = try alloc.dupe(ASTExpression, self.arguments);
        for (0..self.arguments.len) |i| {
            newSelf.arguments[i] = try self.arguments[i].clone(alloc);
        }
        newSelf.primitive = self.primitive;
        return newSelf;
    }

    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        for (self.arguments) |*argument| {
            argument.deinit(alloc);
        }
        alloc.free(self.arguments);
    }
};
pub const ASTOperationPrimitive = enum {
    Add,
    Sub,
    Mul,
    Div,

    Eql,
    NEql,
    Lt,
    Gt,
    LtEql,
    GtEql,

    And,
    Or,

    BitAnd,
    BitOr,
    BitXor,

    // Unary
    Negate,
    Not,

    // Special
    FunctionCall,
    IndexLabel,
    IndexBrace,
    Eof,
};

pub const ASTExpression = union(enum) {
    Value: JSValueType,
    Label: []const u8,
    Operation: ASTOperation,

    const Self = @This();
    const levelDepth = 4; 

    pub fn clone(self: *const Self, alloc: std.mem.Allocator) !Self {
        switch (self.*) {
            .Value => |val| {
                return Self {
                    .Value = try val.clone(alloc),
                };
            },
            .Operation => |op| {
                return Self {
                    .Operation = try op.clone(alloc),
                };
            },
            .Label => |label| {
                return Self{
                    .Label = 
                        try alloc.dupe(u8, label) 
                };
            },
        }
    }

    pub fn printSubTree(self: *const Self, padlevel: usize) void {
        switch (self.*) {
            .Value => |val| {
                val.printRepr();
            },
            .Label => |label| {
                std.debug.print("ASTLabel({s})\n", .{label});
            },
            .Operation => |op| {
                std.debug.print("ASTOperation({s}):\n", .{@tagName(op.primitive)});
                for (op.arguments) |argument| {
                    for (0..padlevel+levelDepth) |_| std.debug.print(" ", .{});
                    argument.printSubTree(padlevel + levelDepth);
                }
            },
        }
    }
    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .Operation => |op| {
                for (op.arguments) |*argument| {
                    argument.deinit(alloc);
                }
                alloc.free(op.arguments);
            },
            .Value => |*val| val.deinit(alloc),
            .Label => |label| alloc.free(label),
        }
    }
};
