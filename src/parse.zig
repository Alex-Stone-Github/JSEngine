const std = @import("std");
const astnode = @import("astnode.zig");
const token = @import("token.zig");


pub const PratNode = union(enum) {
    const Self = @This();

    Token: token.Token,
    Block: std.ArrayList(Self),
    Mini: astnode.ASTExpression,

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

    pub fn transformStep(chnk: *PratNode) void {
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
                    .NumberLiteral => |numLiteral| {
                        const miniTree = PratNode {
                            .Mini = astnode.ASTExpression {
                                .Literal = astnode.JSValueType {
                                    .JSNumber = numLiteral,
                                },
                            }
                        };
                        chnk.* = miniTree;
                    },
                    .BoolLiteral => |boolLiteral| {
                        const miniTree = PratNode {
                            .Mini = astnode.ASTExpression {
                                .Literal = astnode.JSValueType {
                                    .JSBoolean = boolLiteral,
                                },
                            }
                        };
                        chnk.* = miniTree;
                    },
                    .Null => {
                        const miniTree = PratNode {
                            .Mini = astnode.ASTExpression {
                                .Literal = .JSNull
                            }
                        };
                        chnk.* = miniTree;
                    },
                    else => {},
                }
            },
            else => {},
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
    pub fn parse(self: *Self) !void {
        for (0..1) |i| {
            std.debug.print("Unparsed Expression {}:\n", .{i});
            const unparsedStatement = self.getUnparsedStatement();
            for (unparsedStatement) |*chnk| {
                transformStep(chnk);
                chnk.printSubTree(0);
            }
            // Why don't we just parse it like an expression right away
            var expressionParser = 
                try ExpressionParser.init(unparsedStatement, self.alloc);
            defer expressionParser.deinit();
        }
    }
};

pub const ExpressionParser = struct {

    const Tabletype = std.AutoHashMap(token.TokenType.Tag, u32);

    chunks: []PratNode,
    alloc: std.mem.Allocator,
    index: usize,
    precedence: Tabletype,

    const Self = @This();

    pub fn parse(self: *Self) void {
        _ = self;
    }

    fn initPrecedenceTable(self: *Self) !void {
        try self.precedence.put(.Plus, 20);
        try self.precedence.put(.Minus, 20);
        try self.precedence.put(.Star, 40);
        try self.precedence.put(.Slash, 40);
    }

    pub fn init(chunks: []PratNode, alloc: std.mem.Allocator) !Self {
        var self =  Self {
            .chunks = chunks,
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
