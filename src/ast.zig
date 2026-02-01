const std = @import("std");
const token = @import("token.zig");

pub const BracketChunkNode = union(enum) {
    const Self = @This();

    token: token.Token,
    subchunk: std.ArrayList(Self),

    const levelDepth = 4;

    pub fn deinit(self: Self, alloc: std.mem.Allocator) void {
        switch (self) {
            .token => {},
            .subchunk => {
                for (self.subchunk.items) |lower| {
                    lower.deinit(alloc);
                }
                // Deinit behind immutable ref
                var thearraylist = self.subchunk;
                thearraylist.deinit(alloc);
            },
        }

    }
    pub fn printSubTree(self: Self, padlevel: usize) void {
        // Pad
        switch (self) {
            .token => |t| {
                t.printRepr();
            },
            .subchunk => |subchunk| {
                for (0..padlevel) |_| std.debug.print(" ", .{});
                for (subchunk.items) |element| {
                    element.printSubTree(padlevel + levelDepth);
                }
            },
        }
    }
};


pub fn chunkify(alloc: std.mem.Allocator, 
    allTokens: []const token.Token,
    start: usize) !struct{usize, BracketChunkNode} {
    var idx = start;
    var tokenList: std.ArrayList(BracketChunkNode) = .empty;

    while (true) {
        const currentToken = allTokens[idx];
        idx += 1;

        switch (currentToken.token) {
            .LBracket => { // Form a subchunk
                const nidx, const subchunk = 
                    try chunkify(alloc, allTokens, idx);
                idx = nidx;
                try tokenList.append(alloc, subchunk);
            },
            .RBracket => { // End of the current chunk
                if (tokenList.items.len == 0) {
                    return .{idx, BracketChunkNode {
                            .token = token.Token{
                                .start = currentToken.start, 
                                .end = currentToken.end,
                                .token = .SemiColon,
                            }}
                    };
                }
                return .{idx, BracketChunkNode {.subchunk = tokenList}};
            },
            else => { // Normal token
                try tokenList.append(alloc, BracketChunkNode { .token = currentToken});
            }
        }

        if (idx == allTokens.len)
            return .{idx, BracketChunkNode {.subchunk = tokenList}};
    }
}

pub const Statement = union(enum) {
    Assignment,
    Expression,
};


