const std = @import("std");
const token = @import("token.zig");

pub const JSValueTypeHashContext = struct {
    pub fn hash(self: @This(), tohash: JSValueType) u64 {
        var h = std.hash.Wyhash.init(0);
        const enumInt = @intFromEnum(tohash);
        h.update(std.mem.asBytes(&enumInt));

        switch (tohash) {
            .JSNumber => |num| {
                h.update(std.mem.asBytes(&num));
            },
            .JSBoolean => |boolean| {
                h.update(std.mem.asBytes(&boolean));
            },
            .JSString => |string| {
                h.update(string);
            },
            .JSArray => |arr| {
                for (arr.items) |element| {
                    const elementHash = self.hash(element);
                    h.update(std.mem.asBytes(&elementHash));

                }
            },
            .JSObject => |obj| {
                var iter = obj.iterator();
                while (iter.next()) |entry| {
                    const keyHash = self.hash(entry.key_ptr.*);
                    h.update(std.mem.asBytes(&keyHash));
                    const valueHash = self.hash(entry.value_ptr.*);
                    h.update(std.mem.asBytes(&valueHash));
                }
            },
            .JSFunction => {},
            .JSNull => {},
        }
        return h.final();
    }
    pub fn eql(self: @This(), a: JSValueType, b: JSValueType) bool {
        // Check if they are of different varieties, otherwise should be same hash
        if (@intFromEnum(a) != @intFromEnum(b))
            return false;
        return self.hash(a) == self.hash(b);
    }
};
test "basic hash check" {
    const a = JSValueType {
        .JSNumber = 3,
    };
    const b = JSValueType {
        .JSNumber = 4,
    };
    const hasher = JSValueTypeHashContext {};
    std.debug.assert(!hasher.eql(a, b));
}

pub const JSValueType = union(enum) {
    JSNumber: f64,
    JSBoolean: bool,
    JSString: []const u8,
    JSNull,

    JSArray: std.ArrayList(JSValueType),
    JSObject: JSOBjectType,
    JSFunction,

    const JSOBjectType = std.HashMap(JSValueType, JSValueType, JSValueTypeHashContext, 80);


    const Self = @This();

    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .JSString => |str| alloc.free(str),
            .JSArray => |*arr| {
                for (arr.items) |*element|
                    element.deinit(alloc);
                arr.deinit(alloc);
            },
            .JSObject => |*obj| {
                var iter = obj.iterator();
                while (iter.next()) |*entry| {
                    entry.key_ptr.deinit(alloc);
                    entry.value_ptr.deinit(alloc);
                }
                obj.deinit();
            },
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
            .JSArray => |arr| {
                var newList = 
                    try std.ArrayList(JSValueType).initCapacity(alloc, arr.items.len);
                for (arr.items) |element| {
                    try newList.append(alloc, try element.clone(alloc));
                }
                return JSValueType {
                    .JSArray = newList,
                };
            },
            .JSObject => |obj| {
                var newObj: JSOBjectType= JSOBjectType.init(alloc);
                var iter = obj.iterator();
                while (iter.next()) |*entry| {
                    const newKey = try entry.key_ptr.clone(alloc);
                    const newValue = try entry.value_ptr.clone(alloc);
                    try newObj.put(newKey, newValue);
                }
                return JSValueType {
                    .JSObject = newObj
                };
            },
            else => return self.*,
        }
    }

    pub fn printRepr(self: *const Self) void {
        switch (self.*) {
            .JSNumber => |number| {
                std.debug.print("JSNumber({})", .{number});
            },
            .JSBoolean => |boolean| {
                std.debug.print("JSBoolean({})", .{boolean});
            },
            .JSString => |string| {
                std.debug.print("JSString(\"{s}\")", .{string});
            },
            .JSNull => {
                std.debug.print("JSNull(NULL)", .{});
            },
            .JSObject => {
                std.debug.print("JSObjectType(NULL)", .{});
            },
            .JSArray => {
                std.debug.print("JSArrayType(NULL)", .{});
            },
            .JSFunction => {
                std.debug.print("JSFunctionType(NULL)", .{});
            },
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
    ArrayLiteral,
    ObjectLiteral,
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
                std.debug.print("\n", .{});
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
