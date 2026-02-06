const std = @import("std");
const token = @import("token.zig");
const astnode = @import("astnode.zig");

pub const PratNode = union(enum) {
    const Self = @This();

    Token: token.Token,
    Block: std.ArrayList(Self),
    Mini: astnode.ASTExpression,

    const levelDepth = 4;

    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        switch (self.*) {
            .Mini => {
                // In this special case the tree is always a expression with stack allcoated
                // values and so we do not need to deinit it
            },
            .Block => {
                for (self.Block.items) |*lower| {
                    lower.deinit(alloc);
                }
                // Deinit behind immutable ref
                var thearraylist = self.Block;
                thearraylist.deinit(alloc);
            },
            else => {},

        }

    }
    pub fn printSubTree(self: Self, padlevel: usize) void {
        switch (self) {
            .Token => |t| {
                for (0..padlevel) |_| std.debug.print(" ", .{});
                std.debug.print("UToken.", .{});
                t.printRepr();
            },
            .Mini => |mini| {
                mini.printSubTree(padlevel + levelDepth);
            },
            .Block => |block| {
                for (block.items) |element| {
                    element.printSubTree(padlevel + levelDepth);
                }
            },
        }
    }
};

pub const ExpressionParser = struct {
    pub const OperatorInfo = struct {
        precedence: u32,
        primitive: astnode.ASTOperationPrimitive,
    };

    const Tabletype = std.AutoHashMap(token.TokenType.Tag, OperatorInfo);
    const Self = @This();

    nodes: []PratNode,
    alloc: std.mem.Allocator,
    index: usize,
    precedence: Tabletype,

    pub fn parse(self: *Self) !astnode.ASTExpression {
        return self.pratt(1);
    }

    /// Basically a prefix operation
    pub fn consumeNullDescriptor(self: *Self) !astnode.ASTExpression {
        const expr = switch(self.peekToken().?) {
            .Mini => |mini| Value: {
                const value = try mini.clone(self.alloc);
                break :Value value;
            },
            .Token => |tok| 
            switch (tok.token) {
                .Minus => {
                    self.advance();
                    const args: [1]astnode.ASTExpression = .{
                        try self.consumeNullDescriptor(),
                    };
                    const operation = astnode.ASTOperation {
                        .primitive = .Negate,
                        .arguments = 
                            try self.alloc.dupe(astnode.ASTExpression, &args)
                    };
                    return astnode.ASTExpression {
                        .Operation = operation,
                    };
                },
                .LParen => {
                    // Skip the first and last parenthesis
                    self.advance();
                    const inner = try self.pratt(1);
                    return inner;
                },
                else => return error.ExpectedUnaryOperator,
            },
            else => return error.InvalidSyntax,
        };
        self.advance();
        return expr;
    }
    const ExpressionError = error {
        OutOfMemory,
        InvalidSyntax,
        ExpectedBinaryOperator,
        ExpectedUnaryOperator,
        ExpectedLabel,
    };
    pub fn pratt(self: *Self, rbp: u32) ExpressionError!astnode.ASTExpression {
        // Should handle nud prefix operations
        var leftNode = try self.consumeNullDescriptor();

        // Continue to add to the treee
        while (rbp  <= (try self.peekOperator()).precedence) {
            // Get the operator
            const operatorInfo = try self.peekOperator();

            // What are we going to do with the operator
            if (operatorInfo.primitive == .Eof) {
                self.advance();
                return leftNode;
            }
            self.advance();

            const rightNode = try switch(operatorInfo.primitive) {
                .IndexBrace => InnerBrace: {
                    break :InnerBrace self.pratt(1);
                },
                .IndexLabel => Label: {
                    const label = try self.consumeNullDescriptor();
                    if (label != .Label) return error.ExpectedLabel;
                    break :Label label;
                },
                else => self.pratt(operatorInfo.precedence),
            };

            // Binary Operation
            const tmpArgs: [2]astnode.ASTExpression = .{
                leftNode, rightNode
            };
            const ownedArgs = 
                try self.alloc.dupe(astnode.ASTExpression, &tmpArgs);

            const binaryOp = astnode.ASTOperation {
                .primitive = operatorInfo.primitive,
                .arguments = ownedArgs,
            };
            leftNode = astnode.ASTExpression {.Operation = binaryOp};
        }
        return leftNode;
    }
    pub fn isRClosingToken(self: *const Self) bool {
        const node = self.peekToken() orelse return false;
        const tok = switch (node) {
            .Token => |t| t,
            else => return false,
        };
        const tokenType = tok.token;
        if (tokenType == .RBrace) return true;
        if (tokenType == .RParen) return true;
        return false;
    }
    pub fn peekOperator(self: *const Self) !OperatorInfo {
        // Give me a token
        const eofInfo = OperatorInfo {
            .precedence = 1000000000,
            .primitive = .Eof,
        };

        const node = self.peekToken() orelse return eofInfo;
        const tokenInfo = switch (node) {
            .Token => |t| t,
            else => return error.ExpectedBinaryOperator,
        };
        const tok = tokenInfo.token;

        if (tok == .RParen) return eofInfo;
        if (tok == .RBrace) return eofInfo;

        if (self.precedence.get(tok)) |opInfo| 
            return opInfo;
        return error.ExpectedBinaryOperator;
    }
    pub fn peekToken(self: *const Self) ?PratNode {
        if (self.index >= self.nodes.len) return null;
        return self.nodes[self.index];
    }
    pub fn advance(self: *Self) void {
        self.index += 1;
    }

    fn initPrecedenceTable(self: *Self) !void {
        try self.precedence.put(.Plus, 
            OperatorInfo{.precedence = 20, .primitive = .Add });
        try self.precedence.put(.Minus, 
            OperatorInfo{.precedence = 20, .primitive = .Sub });
        try self.precedence.put(.Star, 
            OperatorInfo{.precedence = 40, .primitive = .Mul });
        try self.precedence.put(.Slash, 
            OperatorInfo{.precedence = 40, .primitive = .Div });
        try self.precedence.put(.Dot, 
            OperatorInfo{.precedence = 140, .primitive = .IndexLabel });
        try self.precedence.put(.LBrace, 
            OperatorInfo{.precedence = 140, .primitive = .IndexBrace });
    }

    pub fn init(nodes: []PratNode, alloc: std.mem.Allocator) !Self {
        var self =  Self {
            .nodes = nodes,
            .alloc = alloc,
            .index = 0,
            .precedence = Tabletype.init(alloc)
        };
        try self.initPrecedenceTable();
        return self;
    }
    pub fn deinit(self: *Self) void {
        self.precedence.deinit();
    }
};
