const std = @import("std");
const ini = @import("ini.zig");

fn test_equals(inifile: ini.IniFile, expected: []const u8, section_name: []const u8, key: []const u8) void {
    std.debug.assert(std.mem.eql(u8, expected, (inifile.get(section_name, key)).?));
}

test "given ini file should parse correctly" {
    var inifile = try ini.IniFile.parse("./examples/example_1.ini", std.testing.allocator);
    defer inifile.deinit();
    test_equals(inifile, "John Doe", "owner", "name");
    test_equals(inifile, "Acme Widgets Inc.", "owner", "organization");
    test_equals(inifile, "192.0.2.62", "database", "server");
    test_equals(inifile, "143", "database", "port");
    test_equals(inifile, "\"payroll.dat\"", "database", "file");
}
