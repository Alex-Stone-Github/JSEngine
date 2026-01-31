const std = @import("std");
const ast = @import("ast.zig");
const token = @import("token.zig");

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

    while (true) {
        const nextToken = tokenizer.getNextToken() catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        nextToken.printRepr();
    }

}

