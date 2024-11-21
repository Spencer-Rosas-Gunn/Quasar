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

pub fn main() void {
	// Initialize UEFI Tables
	tables.con_out = uefi.system_table.con_out.?;
	_ = tables.con_out.reset(false);
	tables.boot_services = uefi.system_table.boot_services.?;

	var buf: [256]u8 = undefined;
	
	page.init();

	var toMe: usize = undefined;
	
	var addr_space = vmm.AddressSpace_t.new();

	io.kprintf(&buf, "var addr_space = vmm.AddressSpace_t.new()\n", .{});
	
	vmm.mmap(&toMe, &toMe, addr_space, true);

	io.kprintf(&buf, "vmm.mmap(&toMe, &toMe, addr_space, true)\n", .{});
	
	vmm.munmap(&toMe, addr_space);

	io.kprintf(&buf, "vmm.munmap(&toMe, addr_space)\n", .{});
	
	addr_space.delete();

	io.kprintf(&buf, "vmm.AddressSpace_t.delete(&addr_space)\n", .{});

	io.kprintf(&buf, "The program runs!", .{});

	while (true) {}
}
