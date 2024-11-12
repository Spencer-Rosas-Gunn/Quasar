const uefi = @import("std").os.uefi;
const info = @import("arch/info.zig");

// Link runtime functions
const memcpy = @import("rt.zig").memcpy;
const memset = @import("rt.zig").memset;

const tables = @import("uefi-tables.zig");

const io = @import("io.zig");
const pmm = @import("pmm.zig");

pub fn main() void {
    // Initialize UEFI Tables
    tables.con_out = uefi.system_table.con_out.?;
    _ = tables.con_out.reset(false);
    tables.boot_services = uefi.system_table.boot_services.?;

    pmm.init();
    var page = pmm.new();
    page.delete();

    var buf: [256]u8 = undefined;
    io.kprintf(&buf, "Hello World!\n", .{});

    while (true) {}
}
