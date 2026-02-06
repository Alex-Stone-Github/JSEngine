const std = @import("std");
const astnode = @import("astnode.zig");
const token = @import("token.zig");
const pratt = @import("pratt.zig");

pub fn chunkify(alloc: std.mem.Allocator, 
    allTokens: []const token.Token,
    start: usize) !struct{usize, pratt.PratNode} {
    var idx = start;
    var tokenList: std.ArrayList(pratt.PratNode) = .empty;

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
                    return .{idx, pratt.PratNode {
                            .Token = token.Token{
                                .start = currentToken.start, 
                                .end = currentToken.end,
                                .token = .SemiColon,
                            }}
                    };
                }
                return .{idx, pratt.PratNode {.Block = tokenList}};
            },
            else => { // Normal token
                try tokenList.append(alloc, pratt.PratNode { .Token = currentToken});
            }
        }

        if (idx == allTokens.len)
            return .{idx, pratt.PratNode {.Block = tokenList}};
    }
}


pub const ASTGenerator = struct {
    allChunks: []pratt.PratNode,
    alloc: std.mem.Allocator,
    index: usize,

    const Self = @This();

    pub fn init(chunks: []pratt.PratNode, alloc: std.mem.Allocator) Self {
        return Self {
            .allChunks = chunks,
            .alloc = alloc,
            .index = 0,
        };
    }

    pub fn transformStep(chnk: *pratt.PratNode) void {
        switch (chnk.*) {
            .Token => |utoken| {
                switch (utoken.token) {
                    .Label => |newLabelName| {
                        const miniTree = pratt.PratNode {
                            .Mini = astnode.ASTExpression {
                                .Label = newLabelName,
                            }
                        };
                        chnk.* = miniTree;
                    },
                    .StringLiteral => |stringLiteral| {
                        const miniTree = pratt.PratNode {
                            .Mini = astnode.ASTExpression {
                                .Value = astnode.JSValueType {
                                    .JSString = stringLiteral,
                                },
                            }
                        };
                        chnk.* = miniTree;
                    },
                    .NumberLiteral => |numLiteral| {
                        const miniTree = pratt.PratNode {
                            .Mini = astnode.ASTExpression {
                                .Value = astnode.JSValueType {
                                    .JSNumber = numLiteral,
                                },
                            }
                        };
                        chnk.* = miniTree;
                    },
                    .BoolLiteral => |boolLiteral| {
                        const miniTree = pratt.PratNode {
                            .Mini = astnode.ASTExpression {
                                .Value = astnode.JSValueType {
                                    .JSBoolean = boolLiteral,
                                },
                            }
                        };
                        chnk.* = miniTree;
                    },
                    .Null => {
                        const miniTree = pratt.PratNode {
                            .Mini = astnode.ASTExpression {
                                .Value = .JSNull
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
    pub fn getUnparsedStatement(self: *Self) []pratt.PratNode {
        var unparsedStatement: []pratt.PratNode = self.allChunks[self.index..];
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
    pub fn generate(self: *Self) !void {
        for (0..7) |i| {
            std.debug.print("--------\n", .{});
            std.debug.print("Unparsed Expression {}:\n", .{i});
            std.debug.print("--------\n", .{});
            const unparsedStatement = self.getUnparsedStatement();
            for (unparsedStatement) |*chnk| {
                transformStep(chnk);
                chnk.printSubTree(0);
            }
            // Why don't we just parse it like an expression right away
            if (true) {
                var expressionParser = 
                    try pratt.ExpressionParser.init(unparsedStatement, self.alloc);
                defer expressionParser.deinit();

                var ast = try expressionParser.parse();
                defer ast.deinit(self.alloc);

                std.debug.print("--------\n", .{});
                std.debug.print("Printing generated AST{}:\n", .{i});
                std.debug.print("--------\n", .{});
                ast.printSubTree(0);
            }
        }
    }
};

