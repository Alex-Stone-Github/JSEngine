const std = @import("std");
const astnode = @import("astnode.zig");
const chunk = @import("ast.zig");


pub const Parser = struct {
    allChunks: []const chunk.BracketChunkNode,
    alloc: std.mem.Allocator,
    index: usize,

    const Self = @This();

    pub fn init(chunks: []const chunk.BracketChunkNode, alloc: std.mem.Allocator) Self {
        return Self {
            .allChunks = chunks,
            .alloc = alloc,
            .index = 0,
        };
    }

    pub fn parse(self: *Self) !void {
        for (0..3) |i| {
            std.debug.print("Unparsed Expression {}:\n", .{i});
            const unparsedStatement = self.getUnparsedStatement();
            for (unparsedStatement) |chnk| chnk.printSubTree(0);
        }
    }
    pub fn getUnparsedStatement(self: *Self) []const chunk.BracketChunkNode {
        var unparsedStatement: []const chunk.BracketChunkNode = self.allChunks[self.index..];
        unparsedStatement.len = 0;

        while (true) {
            const chnk = self.allChunks[self.index+unparsedStatement.len];
            if (chnk.token.token == .SemiColon) {
                self.index += unparsedStatement.len + 1;
                return unparsedStatement;
            }
            unparsedStatement.len += 1;
        }
    }
};
