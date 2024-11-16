// Import UEFI Interface
const uefi = @import("std").os.uefi;

// Link runtime functions
const memcpy = @import("rt.zig").memcpy;
const memset = @import("rt.zig").memset;

// Import Modules
const tables = @import("uefi-tables.zig");
const info = @import("arch/info.zig");
const io = @import("io.zig");
const page = @import("page.zig");
const vmm = @import("arch/vmm.zig");
const Stack_t = @import("stack.zig").new;

pub fn main() void {
    // Initialize UEFI Tables
    tables.con_out = uefi.system_table.con_out.?;
    _ = tables.con_out.reset(false);
    tables.boot_services = uefi.system_table.boot_services.?;

    page.init();

	var toMe: usize = undefined;
   	
    var addr_space = vmm.AddressSpace_t.new();
    vmm.mmap(&toMe, &toMe, addr_space);
    
    vmm.munmap(&toMe, addr_space);
    addr_space.delete();

    var stack: Stack_t(isize) = Stack_t(isize).new();
   	defer stack.delete();
    stack.push(0);
    _ = stack.pop();

	var buf: [256]u8 = undefined;
    io.kprintf(&buf, "The program runs!", .{});

    while (true) {}
}
