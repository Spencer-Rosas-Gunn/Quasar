const uefi = @import("std").os.uefi;
const fmt = @import("std").fmt;
const tables = @import("uefi-tables.zig");

pub fn kprintf(buf: []u8, comptime format: []const u8, args: anytype) void {
	const msg = fmt.bufPrint(buf, format, args) catch unreachable;

	for (msg) |c| {
		if (c == '\n') {
			const out = [3]u16{ '\r', '\n', 0 };
			_ = tables.con_out.outputString(@ptrCast(&out));
		} else {
			const out = [2]u16{ c, 0 };
			_ = tables.con_out.outputString(@ptrCast(&out));
		}
	}
}
