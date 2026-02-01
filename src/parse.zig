const std = @import("std");
const astnode = @import("astnode.zig");
const token = @import("token.zig");

const PratOperator = struct {
    name: []const u8,
    leftForce: f64,
    rightForce: f64,

    pub fn printRepr(self: @This()) void {
        std.debug.print("POperator.({}[{s}]{})\n", 
            .{self.leftForce, self.name, self.rightForce});
    }
};

pub const PratNode = union(enum) {
    const Self = @This();

    Token: token.Token,
    Block: std.ArrayList(Self),
    Mini: astnode.ASTExpression,
    Operator: PratOperator,

    const levelDepth = 4;

    pub fn deinit(self: Self, alloc: std.mem.Allocator) void {
        switch (self) {
            .Block => {
                for (self.Block.items) |lower| {
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
            .Operator => |op| {
                for (0..padlevel) |_| std.debug.print(" ", .{});
                op.printRepr();
            },
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


pub fn chunkify(alloc: std.mem.Allocator, 
    allTokens: []const token.Token,
    start: usize) !struct{usize, PratNode} {
    var idx = start;
    var tokenList: std.ArrayList(PratNode) = .empty;

    while (true) {
        const currentToken = allTokens[idx];
        idx += 1;

        switch (currentToken.token) {
            .LBracket => { // Form a subchunk
                const nidx, const block = 
                    try chunkify(alloc, allTokens, idx);
                idx = nidx;
                try tokenList.append(alloc, block);
            },
            .RBracket => { // End of the current chunk
                if (tokenList.items.len == 0) {
                    return .{idx, PratNode {
                            .Token = token.Token{
                                .start = currentToken.start, 
                                .end = currentToken.end,
                                .token = .SemiColon,
                            }}
                    };
                }
                return .{idx, PratNode {.Block = tokenList}};
            },
            else => { // Normal token
                try tokenList.append(alloc, PratNode { .Token = currentToken});
            }
        }

        if (idx == allTokens.len)
            return .{idx, PratNode {.Block = tokenList}};
    }
}


pub const Parser = struct {
    allChunks: []PratNode,
    alloc: std.mem.Allocator,
    index: usize,

    const Self = @This();

    pub fn init(chunks: []PratNode, alloc: std.mem.Allocator) Self {
        return Self {
            .allChunks = chunks,
            .alloc = alloc,
            .index = 0,
        };
    }

    pub fn parse(self: *Self) !void {
        for (0..4) |i| {
            std.debug.print("Unparsed Expression {}:\n", .{i});
            const unparsedStatement = self.getUnparsedStatement();
            for (unparsedStatement) |*chnk| {
                switch (chnk.*) {
                    .Token => |utoken| {
                        switch (utoken.token) {
                            .Label => |newLabelName| {
                                const miniTree = PratNode {
                                    .Mini = astnode.ASTExpression {
                                        .Label = newLabelName,
                                    }
                                };
                                chnk.* = miniTree;
                            },
                            .StringLiteral => |stringLiteral| {
                                const miniTree = PratNode {
                                    .Mini = astnode.ASTExpression {
                                        .Literal = astnode.JSValueType {
                                            .JSString = stringLiteral,
                                        },
                                    }
                                };
                                chnk.* = miniTree;
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
                chnk.printSubTree(0);
            }
            // Why don't we just parse it like an expression right away
        }
    }
    pub fn getUnparsedStatement(self: *Self) []PratNode {
        var unparsedStatement: []PratNode = self.allChunks[self.index..];
        unparsedStatement.len = 0;

        while (true) {
            const chnk = self.allChunks[self.index+unparsedStatement.len];
            if (chnk.Token.token == .SemiColon) {
                self.index += unparsedStatement.len + 1;
                return unparsedStatement;
            }
            unparsedStatement.len += 1;
        }
    }
};
