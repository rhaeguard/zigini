// Import standard library, reachable through the "std" constant.
const std = @import("std");

// "info" now refers to the "std.log.info" function.
const info = std.log.info;

const AppErrors = error{ DelimiterNotFound, SyntaxError };

pub const IniFile = struct { 
    sections: std.ArrayList(*Section),

    pub fn create(filename: []const u8) {

    }
};

pub const Section = struct { name: []const u8, entries: std.ArrayList(*Entry) };

pub const Entry = struct { key: []const u8, value: []const u8 };

pub fn main() anyerror!void {
    var file = try std.fs.cwd().openFile("./examples/example_1.ini", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var alloc = std.heap.page_allocator;

    var current_section: *Section = undefined;
    var inifile: *IniFile = try alloc.create(IniFile);
    inifile.* = .{ .sections = std.ArrayList(*Section).init(alloc) };

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |original| {
        var line = try alloc.alloc(u8, original.len);
        std.mem.copy(u8, line, original);

        var first_char = line[0];
        if (first_char == ';') { // it's a comment
            continue;
        }

        if (first_char == '[') {
            var current_section_name = try read_section_name(line);
            current_section = try alloc.create(Section);
            current_section.* = .{ .name = current_section_name, .entries = std.ArrayList(*Entry).init(alloc) };
            try inifile.sections.append(current_section);
        }

        var maybe_pos = find_equal_sign_pos(line);
        if (maybe_pos != null) {
            var pos = maybe_pos.?;

            var key = trim_whitespaces(line[0..pos]);
            var value = trim_whitespaces(line[pos + 1 .. line.len]);
            var entry: *Entry = try alloc.create(Entry);
            entry.*.key = key;
            entry.*.value = value;
            try current_section.entries.append(entry);
        }
    }

    info("section: {any}\n\n\n", .{inifile.sections.items[0].entries.items});
    info("section: {any}\n", .{inifile.sections.items[1].entries.items});

    // inifile.sections.deinit();
}

pub fn find_equal_sign_pos(slice: []u8) ?usize {
    var i: usize = 0;
    while (i < slice.len) : (i += 1) {
        if (slice[i] == '=') {
            return i;
        }
    }

    return null;
}

pub fn read_section_name(input: []u8) AppErrors![]const u8 {
    var trimmed_line = trim_whitespaces(input);
    // expect the first char to be [ and the last ]
    if (trimmed_line[0] != '[' or trimmed_line[trimmed_line.len - 1] != ']') {
        return AppErrors.SyntaxError;
    }

    var section_name: []const u8 = trimmed_line[1 .. trimmed_line.len - 1];
    section_name = trim_whitespaces(section_name);

    return section_name;
}

pub fn trim_whitespaces(slice: []const u8) []const u8 {
    var start: usize = 0;
    while (is_whitespace(slice[start])) : (start += 1) {}

    var end: usize = slice.len;
    while (is_whitespace(slice[end - 1])) : (end -= 1) {}

    return slice[start..end];
}

pub fn is_whitespace(ch: u8) bool {
    var is_space = ch == ' ';
    var is_tab = ch == '\t';
    var is_new_line = ch == '\n';
    var is_carriage_return = ch == 13;

    return is_space or is_tab or is_new_line or is_carriage_return;
}
