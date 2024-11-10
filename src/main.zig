const uefi = @import("std").os.uefi;

// Link runtime functions
const memcpy = @import("rt.zig").memcpy;
const memset = @import("rt.zig").memset;

pub fn main() void {
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.reset(false);

    _ = con_out.outputString(&[_:0]u16{ 'H', 'e', 'l', 'l', 'o', ',', ' ', 'w', 'o', 'r', 'l', 'd', '\r', '\n' });

    const boot_services = uefi.system_table.boot_services.?;
    _ = boot_services;

    while (true) {}
}
