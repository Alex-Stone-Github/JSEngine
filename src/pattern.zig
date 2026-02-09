const std = @import("std");
const astnode = @import("astnode.zig");
const pratt = @import("pratt.zig");

// Pattern Matching Functions
fn testExpressionStatement(alloc: std.mem.Allocator, nodes: []const pratt.PratNode) !?PatternMatch {
    var unparsedExpression: []const pratt.PratNode = nodes;
    unparsedExpression.len = 0;
    while (true) {
        if (unparsedExpression.len == nodes.len) return null; // eof - needs semicolon
        const nextNode = nodes[unparsedExpression.len];
        switch (nextNode) {
            .Token => |tok| {
                if (tok.token == .SemiColon) break;
            },
            else => {},
        }
        unparsedExpression.len += 1;
    }

    const parser = try pratt.ExpressionParser.init(unparsedExpression, alloc);
    if (parser.parse(unparsedExpression)) |expr| {
        return PatternMatch {
            .remainingNodes = nodes[unparsedExpression.len..],
            .statement = Statement {
                .ExpressionStatement = expr,
            },
        };
    } else |err| {
        switch (err) {
            error.OutOfMemory => return err,
            else => return null,
        }
    }
}



// Statment Types and Blocks Core
pub const AssignmentStatement = struct {
    lvalue: astnode.ASTExpression,
    expr: astnode.ASTExpression,
};
pub const BranchStatment = struct {
    conditions: []astnode.ASTExpression,
    branches: []Block,
};
pub const LoopStatement = struct {
    condition: astnode.ASTExpression,
    block: Block,
};
pub const Statement = union(enum) {
    ExpressionStatement: astnode.ASTExpression,
    AssignmentStatement: AssignmentStatement,
    BranchStatement: BranchStatment,
    LoopStatement: LoopStatement,
    ReturnStatement: astnode.ASTExpression,
};
pub const Block = struct {
    statements: []Statement,
};





// Pattern Matching Core
pub const PatternMatch = struct {
    remainingNodes: []const pratt.PratNode,
    statement: Statement,
};
pub const PatternTest = *const fn(std.mem.Allocator, []const pratt.PratNode) pratt.PrattError!?PatternMatch;

const patternTests= [_]PatternTest{
    .{ .testPattern = testExpressionStatement() },
};
