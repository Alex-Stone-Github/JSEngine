const std = @import("std");
const astnode = @import("astnode.zig");
const token = @import("token.zig");

pub fn transformStep(chnk: *PratNode) void {
    switch (chnk.*) {
        .Block => |blk| {
            for (blk.items) |*node| {
                transformStep(node);
            }
        },
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
                            .Value = astnode.JSValueType {
                                .JSString = stringLiteral,
                            },
                        }
                    };
                    chnk.* = miniTree;
                },
                .NumberLiteral => |numLiteral| {
                    const miniTree = PratNode {
                        .Mini = astnode.ASTExpression {
                            .Value = astnode.JSValueType {
                                .JSNumber = numLiteral,
                            },
                        }
                    };
                    chnk.* = miniTree;
                },
                .BoolLiteral => |boolLiteral| {
                    const miniTree = PratNode {
                        .Mini = astnode.ASTExpression {
                            .Value = astnode.JSValueType {
                                .JSBoolean = boolLiteral,
                            },
                        }
                    };
                    chnk.* = miniTree;
                },
                .Null => {
                    const miniTree = PratNode {
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
                return .{idx, PratNode 
                    {.Block = tokenList}};
            },
            else => { // Normal token
                try tokenList.append(alloc, 
                    PratNode { .Token = currentToken});
            }
        }

        if (idx == allTokens.len)
            return .{idx, PratNode 
                {.Block = tokenList}};
    }
}

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
                std.debug.print("\n", .{});
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
