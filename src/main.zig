const std = @import("std");
const ast = @import("ast.zig");
const token = @import("token.zig");
const parse = @import("parse.zig");

pub fn main() !void {
    // Gimmi an Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Get File Content
    const msg: []const u8 = try std.fs.cwd()
        .readFileAlloc(alloc, "main.js", 10 * 1024 * 1024);
    defer alloc.free(msg);

    // Parse the Actual File
    var tokenizer = token.Tokenizer.init(msg);
    std.debug.print("Let's Go!\n", .{});

    var allTokens: std.ArrayList(token.Token) = .empty;
    defer allTokens.deinit(alloc);
    while (true) {
        const nextToken = tokenizer.getNextToken() catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        try allTokens.append(alloc, nextToken);
    }

    // Chunkify it
    var chunkTree = 
        try ast.chunkify(alloc, allTokens.items, 0);
    defer chunkTree[1].deinit(alloc);


    chunkTree[1].printSubTree(0);

    std.debug.print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n", .{});
    std.debug.print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n", .{});
    std.debug.print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$\n", .{});

    var parser = parse.Parser.init(chunkTree[1].subchunk.items, alloc);
    try parser.parse();
}

