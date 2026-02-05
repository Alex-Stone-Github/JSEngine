const std = @import("std");

pub const Token = struct {
    token: TokenType,
    start: usize,
    end: usize,

    pub fn printRepr(self: @This()) void {
        std.debug.print("[{}:{}]", .{self.start, self.end});
        self.token.printRepr();
    }
};

pub const TokenType = union(enum) {
    pub const Tag = std.meta.Tag(@This());

    Await,
    Break,
    Case,
    Catch,
    Class,
    Const,
    Continue,
    Debugger,
    Default,
    Delete,
    Do,
    Else,
    Export,
    Extends,
    Finally,
    For,
    Function,
    If,
    Import,
    In,
    Instanceof,
    New,
    Return,
    Super,
    Switch,
    This,
    Throw,
    Try,
    Typeof,
    Var,
    Void,
    While,
    With,
    Yield,

    LBracket,
    RBracket,
    LBrace,
    RBrace,
    LParen,
    RParen,
    Comma,
    Dot,
    SemiColon,

    Plus,
    Minus,
    Star,
    Slash,

    PlusEql,
    MinusEql,
    StarEql,
    SlashEql,

    PPlus,
    MMinus,

    Modulus,
    Eql,
    DEql,
    TEql,

    And,
    Or,
    Not,

    BitAnd,
    BitOr,
    BitXor,
    BitNot,

    Label: []const u8,
    StringLiteral: []const u8,
    NumberLiteral: f64,
    BoolLiteral: bool,
    Null,

    pub fn printRepr(self: @This()) void {
        switch (self) {
            .StringLiteral => |string| std.debug.print("\"{s}\"\n", .{string}),
            .Label => |label| std.debug.print("Label({s})\n", .{label}),
            else => std.debug.print("{s}\n", .{@tagName(self)}),
        }
    }
};

const oneHits = std.StaticStringMap(TokenType).initComptime(.{

    .{ "await", .Await},
    .{ "break", .Break},
    .{ "case", .Case},
    .{ "catch", .Catch},
    .{ "class", .Class},
    .{ "const", .Const},
    .{ "continue", .Continue},
    .{ "debugger", .Debugger},
    .{ "default", .Default},
    .{ "delete", .Delete},
    .{ "do", .Do},
    .{ "else", .Else},
    .{ "export", .Export},
    .{ "extends", .Extends},
    .{ "finally", .Finally},
    .{ "for", .For},
    .{ "function", .Function},
    .{ "if", .If},
    .{ "import", .Import},
    .{ "in", .In},
    .{ "instanceof", .Instanceof},
    .{ "new", .New},
    .{ "return", .Return},
    .{ "super", .Super},
    .{ "switch", .Switch},
    .{ "this", .This},
    .{ "throw", .Throw},
    .{ "try", .Try},
    .{ "typeof", .Typeof},
    .{ "var", .Var},
    .{ "void", .Void},
    .{ "while", .While},
    .{ "with", .With},
    .{ "yield", .Yield},

    .{ "{", .LBracket},
    .{ "}", .RBracket},
    .{ "[", .LBrace},
    .{ "]", .RBrace},
    .{ "(", .LParen},
    .{ ")", .RParen},
    .{ ",", .Comma},
    .{ ".", .Dot},
    .{ ";", .SemiColon},

    .{ "+", .Plus},
    .{ "-", .Minus},
    .{ "*", .Star},
    .{ "/", .Slash},

    .{ "+=", .PlusEql},
    .{ "-=", .MinusEql},
    .{ "*=", .StarEql},
    .{ "/=", .SlashEql},


    .{ "++", .PPlus},
    .{ "--", .MMinus},
    
    .{ "%", .Modulus},
    .{ "=", .Eql},
    .{ "==", .DEql},
    .{ "===", .TEql},


    .{ "&&", .And},
    .{ "||", .Or},
    .{ "!", .Not},

    .{ "&", .BitAnd},
    .{ "|", .BitOr},
    .{ "^", .BitXor},
    .{ "~", .BitNot},
});
fn strLenCmp(_: void, lhs: []const u8, rhs: []const u8) bool {
    return lhs.len > rhs.len;
}

fn getLengthSortedOneHits(alloc: std.mem.Allocator) ![]const[]const u8 {
    const unsortedKeys = try alloc.dupe([]const u8, oneHits.keys());
    std.mem.sort([]const u8, unsortedKeys, {}, strLenCmp);
    return unsortedKeys;
}
fn isNumberLiteral(characters: []const u8) ?f64 {
    // All Number Characters
    for (characters) |char| {
        if (char == '.' or std.ascii.isDigit(char)) continue;
        return null;
    }

    // Only one dot
    const dotCount = 
        std.mem.count(u8, characters, &[_]u8{'.'});
    if (dotCount > 1) return null;

    return std.fmt.parseFloat(f64, characters);
}


pub const Tokenizer = struct {
    textRef: []const u8,
    index: usize,

    const Self = @This();

    pub fn init(text: []const u8) Self {
        return Self {
            .textRef = text,
            .index = 0,
        };
    }
    pub fn advance(self: *Self, cChars: usize) void {
        self.index += cChars;
    }
    pub fn peekChar(self: *const Self, offset: usize) ?u8 {
        const idx = self.index + offset;
        if (idx >= self.textRef.len) return null;
        return self.textRef[idx];
    }
    pub fn peekStr(self: *const Self, buffer: []u8) ?[]const u8 {
        for (0..buffer.len) |off| {
            const char = peekChar(self, off) orelse return null;
            buffer[off] = char;
        }
        return buffer;
    }
    pub fn getNextToken(self: *Self) !Token {
        // What do we have to do?
        // 1. Filter out comments and whitespace (skip)
        self.skipNonCounted() catch |err| {
            if (err == error.EndOfStream) return err;
        };

        const tokenStartIndex = self.index;

        // 2. Test if string (return)
        if (self.getStringToken()) |st| {
            return Token {.token = st, 
                .start = tokenStartIndex, .end = self.index};
        }
        else |err| {
            if (err != error.NotAStringToken) return err;
        }

        // 3. Test for keywords and symbols
        if (self.getOneHitToken()) |onehit| {
            return Token {.token = onehit, 
                .start = tokenStartIndex, .end = self.index};
        }
        else |err| {
            if (err != error.NotAOneHitToken) return err;
        }

        // 4. Classify Label 
        if (self.getAtomToken()) |atom| {
            return Token {.token = atom, 
                .start = tokenStartIndex, .end = self.index};
        }
        else |err| {
            if (err != error.NotAAtomToken) return err;
        }
        return error.InvalidSyntax;
    }
    pub fn getAtomToken(self: *Self) !TokenType {
        // How long can a variable or number actually be
        var fullWindowBuffer: [128]u8 = undefined;
        var currentWindowBuffer: []u8 = &fullWindowBuffer;
        currentWindowBuffer.len = 0;

        var window = self.peekStr(currentWindowBuffer) orelse unreachable;

        while (true) {
            // Expand the window and check
            currentWindowBuffer.len += 1;
            if (currentWindowBuffer.len == fullWindowBuffer.len) return error.AtomTooBig;
            window = self.peekStr(currentWindowBuffer) orelse return error.EndOfStream;

            // Are we still a valid label
            // TODO: REVIEW DOUBLE LOOP
            var isValidAtom = true;
            for (window) |char| {
                if (std.ascii.isAlphanumeric(char) or char == '_' or char == '.')
                    continue;
                isValidAtom = false;
            }

            // If we are not a valid label, we want to scale the window back
            // and say that the variable is done
            if (!isValidAtom) {
                window = 
                    self.textRef[self.index..self.index + currentWindowBuffer.len - 1];
                var atomToken = TokenType { .Label = window };

                // Number Literal Special Case
                var isValidNumberLiteral = true;
                for (window) |char| {
                    if (std.ascii.isDigit(char) or char == '.') continue;
                    isValidNumberLiteral = false;
                }
                if (isValidNumberLiteral) {
                    const num = try std.fmt.parseFloat(f64, window);
                    atomToken = TokenType {.NumberLiteral = num};
                }

                // Boolean Literal Special Case
                if (std.mem.eql(u8, "false", window))
                    atomToken = TokenType {.BoolLiteral = false};
                if (std.mem.eql(u8, "true", window))
                    atomToken = TokenType {.BoolLiteral = true};

                // Null & Undefined
                if (std.mem.eql(u8, "undefined", window))
                    atomToken = .Null;
                if (std.mem.eql(u8, "null", window))
                    atomToken = .Null;

                if (window.len == 0) return error.NotAAtomToken;
                self.advance(window.len);
                return atomToken;
            }
        }
    }
    pub fn getOneHitToken(self: *Self) !TokenType {
        var buffer: [1024 * 4]u8 = undefined;
        var fixedAllocator = 
            std.heap.FixedBufferAllocator.init(&buffer);
        const alloc = fixedAllocator.allocator();

        // Get Memory for both the actual keyword and the slice we are testing against
        const testKeywords = try getLengthSortedOneHits(alloc);
        const longesteyWordLength = testKeywords[0].len;
        var testStringBuffer = try alloc.alloc(u8, longesteyWordLength);
        defer alloc.free(testStringBuffer);

        for (testKeywords) |testKeyword| {
            // Is safe because no matter what the length of this buffer is eql to 
            // or greater than the length of the keyword we are comparing against.
            testStringBuffer.len = testKeyword.len; 
            const testString = self.peekStr(testStringBuffer) orelse continue;
            // We have two strings of equal length, are they equal?
            const isAKeyword = std.mem.eql(u8, testKeyword, testString);

            if (!isAKeyword) continue;
            if (self.peekChar(testKeyword.len)) |continuationChar| {
                const lastChar = testKeyword[testKeyword.len - 1];
                if (std.ascii.isAlphanumeric(lastChar) 
                    and std.ascii.isAlphanumeric(continuationChar)) 
                    return error.NotAOneHitToken;
            }

            // We are dealing with a keyword
            const token = oneHits.get(testKeyword).?;
            self.advance(testKeyword.len);
            return token;
        }
        return error.NotAOneHitToken;
    }
    pub fn getStringToken(self: *Self) !TokenType {
        const hdr = self.peekChar(0) orelse return error.EndOfStream;
        const isStrHdr = hdr == '\'' or hdr == '\"';
        if (!isStrHdr) return error.NotAStringToken;

        // We know we are dealing with a "string" or 'string'
        // TODO: Does not support escape sequences
        self.advance(1); // skip ' or "
        const ptrOff = self.index;
        while ((self.peekChar(0) orelse return error.EndOfStream) != hdr) 
            : (self.advance(1)) {}
        // We are pointing to a hdr byte
        const strBytes = self.textRef[ptrOff..self.index];
        self.advance(1); // skip end footer of string ' or "
        
        return TokenType { .StringLiteral = strBytes };
    }
    /// Returns error if end of stream is reached
    pub fn skipNonCounted(self: *Self) !void {
        while (true) {
            // Where did we start skipping?
            const startPosition = self.index;

            // Eat Whitespace
            while (std.ascii.isWhitespace(self.peekChar(0) 
                    orelse return error.EndOfStream))
                : (self.advance(1)) {}

            // Eat One Line Comment
            var cmntTest: [2]u8 = undefined;
            const isLineCommentStart = 
                std.mem.eql(u8, "//", 
                    self.peekStr(&cmntTest) orelse return error.EndOfStream);
            while (isLineCommentStart) {
                self.advance(1);
                const isEndOfLine = 
                    (self.peekChar(0) orelse return error.EndOfStream) == '\n';
                if (isEndOfLine) {
                    self.advance(1);
                    break;
                }
            }
            
            // Eat Multi Line Comment
            var cmntTestHd: [2]u8 = undefined;
            var cmntTestTl: [2]u8 = undefined;
            const isMLCmntStart = 
                std.mem.eql(u8, "/*", 
                    self.peekStr(&cmntTestHd) orelse return error.EndOfStream);
            while (isMLCmntStart) {
                self.advance(1);
                const isEnd = 
                    std.mem.eql(u8, "*/", 
                        self.peekStr(&cmntTestTl) orelse return error.EndOfStream);
                if (isEnd) {
                    self.advance(2);
                    break;
                }
            }

            // Check if we are done
            const endPosition = self.index;
            const skippedAnything = startPosition != endPosition;
            // We are done skipping, and the file is obviously not done
            if (!skippedAnything) return;
        }
    }
};
