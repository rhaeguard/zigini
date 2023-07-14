# zigini

experimental ini file parser for zig.

example:

```zig
pub fn main() anyerror!void {
    var inifile = try IniFile.parse("./examples/example_1.ini", std.heap.page_allocator);
    defer inifile.deinit();

    var result = inifile.get("owner", "name");

    std.log.info("result : {s}", .{result.?});
}
```