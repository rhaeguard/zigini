const std = @import("std");

const AppErrors = error{ DelimiterNotFound, SyntaxError };

pub const Section = struct {
    const Self = @This();

    name: []const u8,
    entries: std.ArrayList(*Entry),

    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        var entries_size = self.entries.items.len;
        while (entries_size > 0) : (entries_size -= 1) {
            var entry = self.entries.items[entries_size - 1];
            allocator.destroy(entry);
        }
        self.entries.deinit();
    }
};

pub const Entry = struct { key: []const u8, value: []const u8 };

pub const IniFile = struct {
    const Self = @This();

    sections: std.ArrayList(*Section),
    allocator: std.mem.Allocator,
    lines: std.ArrayList([]u8),

    pub fn parse(filename: []const u8, alloc: std.mem.Allocator) anyerror!IniFile {
        var file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var current_section: *Section = undefined;
        var inifile: IniFile = .{ .sections = std.ArrayList(*Section).init(alloc), .allocator = alloc, .lines = std.ArrayList([]u8).init(alloc) };

        var buf: [1024]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |original| {
            var line = try alloc.alloc(u8, original.len);
            std.mem.copy(u8, line, original);
            try inifile.lines.append(line);

            if (is_empty_line(line)) {
                continue;
            }

            var first_char = line[0];
            if (first_char == ';') { // skip, it's a comment
                continue;
            }

            if (first_char == '[') {
                var current_section_name = try read_section_name(line);
                current_section = try alloc.create(Section);
                current_section.* = .{ .name = current_section_name, .entries = std.ArrayList(*Entry).init(alloc) };
                try inifile.sections.append(current_section);
                continue;
            }

            var pos = try find_equal_sign_pos(line);
            var key = trim_whitespaces(line[0..pos]);
            var value = trim_whitespaces(line[pos + 1 .. line.len]);
            var entry: *Entry = try alloc.create(Entry);
            entry.* = .{ .key = key, .value = value };
            try current_section.entries.append(entry);
        }

        return inifile;
    }

    pub fn deinit(self: Self) void {
        var size: usize = self.sections.items.len;
        while (size > 0) : (size -= 1) {
            var section: *Section = self.sections.items[size - 1];
            section.deinit(self.allocator);
            self.allocator.destroy(section);
        }
        self.sections.deinit();

        size = self.lines.items.len;
        while (size > 0) : (size -= 1) {
            var line = self.lines.items[size - 1];
            self.allocator.free(line);
        }

        self.lines.deinit();
    }

    pub fn get(self: Self, section_name: []const u8, key: []const u8) ?[]const u8 {
        var size = self.sections.items.len;
        while (size > 0) : (size -= 1) {
            var section: *Section = self.sections.items[size - 1];
            if (std.mem.eql(u8, section.name, section_name)) {
                var entries_size = section.entries.items.len;
                while (entries_size > 0) : (entries_size -= 1) {
                    var entry: *Entry = section.entries.items[entries_size - 1];
                    if (std.mem.eql(u8, key, entry.key)) {
                        return entry.value;
                    }
                }
            }
        }
        return null;
    }

    fn is_empty_line(line: []const u8) bool {
        var size = line.len;
        while (size > 0) : (size -= 1) {
            if (!is_whitespace(line[size - 1])) {
                return false;
            }
        }
        return true;
    }

    fn find_equal_sign_pos(slice: []u8) AppErrors!usize {
        var i: usize = 0;
        while (i < slice.len) : (i += 1) {
            if (slice[i] == '=') {
                return i;
            }
        }

        return AppErrors.DelimiterNotFound;
    }

    fn read_section_name(input: []u8) AppErrors![]const u8 {
        var trimmed_line = trim_whitespaces(input);
        // expect the first char to be [ and the last ]
        if (trimmed_line[0] != '[' or trimmed_line[trimmed_line.len - 1] != ']') {
            return AppErrors.SyntaxError;
        }

        var section_name: []const u8 = trimmed_line[1 .. trimmed_line.len - 1];
        section_name = trim_whitespaces(section_name);

        return section_name;
    }

    fn trim_whitespaces(slice: []const u8) []const u8 {
        var start: usize = 0;
        while (is_whitespace(slice[start])) : (start += 1) {}

        var end: usize = slice.len;
        while (is_whitespace(slice[end - 1])) : (end -= 1) {}

        return slice[start..end];
    }

    fn is_whitespace(ch: u8) bool {
        var is_space = ch == ' ';
        var is_tab = ch == '\t';
        var is_new_line = ch == '\n';
        var is_carriage_return = ch == 13;

        return is_space or is_tab or is_new_line or is_carriage_return;
    }
};
