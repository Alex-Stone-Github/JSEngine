const std = @import("std");
const astnode = @import("astnode.zig");
const token = @import("token.zig");
const pratt = @import("pratt.zig");
const transform = @import("transform.zig");
const pattern = @import("pattern.zig");

pub const ProgramParser = struct {
    allChunks: []transform.PratNode,
    alloc: std.mem.Allocator,
    index: usize,

    const Self = @This();

    pub fn init(chunks: []transform.PratNode, alloc: std.mem.Allocator) Self {
        return Self {
            .allChunks = chunks,
            .alloc = alloc,
            .index = 0,
        };
    }

    pub fn getUnparsedStatement(self: *Self) []transform.PratNode {
        var unparsedStatement: []transform.PratNode = self.allChunks[self.index..];
        unparsedStatement.len = 0;

        while (true) {
            const node = self.allChunks[self.index+unparsedStatement.len];
            switch (node) {
                .Token => |tok| {
                    if (tok.token == .SemiColon) {
                        self.index += unparsedStatement.len + 1;
                        return unparsedStatement;
                    }
                    unparsedStatement.len += 1;
                },
                else => {
                    unparsedStatement.len += 1;
                },
            }
        }
    }
    pub fn generate(self: *Self) !void {
        for (0..11) |i| {
            std.debug.print("--------\n", .{});
            std.debug.print("Unparsed Expression {}:\n", .{i});
            std.debug.print("--------\n", .{});
            const unparsedStatement = self.getUnparsedStatement();
            for (unparsedStatement) |*chnk| {
                transform.transformStep(chnk);
                chnk.printSubTree(0);
            }
            // Why don't we just parse it like an expression right away
            if (true) {
                var expressionParser = 
                    try pratt.ExpressionParser.init(unparsedStatement, self.alloc);
                defer expressionParser.deinit();

                var ast = try expressionParser.parse();
                defer ast.deinit(self.alloc);

                std.debug.print("Printing generated AST{} ----\n", .{i});
                ast.printSubTree(0);
            }
        }
    }
};



// - JSARRAYVALUE
// - JSOBJECT
// - function and class parsing
// - WHAT IS A REFCOUNTED VARIABLE
