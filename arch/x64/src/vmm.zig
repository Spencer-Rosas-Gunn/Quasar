const info = @import("info.zig");
const page = @import("../page.zig");

const io = @import("../io.zig");

const PageTableEntry_t = packed struct {
    present: bool = true,
    writeable: bool = true,
    user_access: bool = true,
    write_through: bool = true,
    cache_disabled: bool = false,
    accessed: bool = true,
    dirty: bool = true,
    size: bool = true,
    global: bool = false,
    _rsvd1: u3 = 0,
    page_ppn: u40,
    _rsvd2: u11 = 0,
    execution_disabled: bool = false,

    pub fn index(self: *PageTableEntry_t) *[512]PageTableEntry_t {
        if (self.page_ppn == 0) {
            self.page_ppn = page.new().page;

            for(page.fromInt(self.page_ppn).toPtr(*[512]PageTableEntry_t)) |*entry| {
            	entry.* = .{ .page_ppn = 0, };
            }
        }

        return page.fromInt(self.page_ppn).toPtr(*[512]PageTableEntry_t);
    }

    pub fn fromInt(ptr: anytype) PageTableEntry_t {
    	return PageTableEntry_t { .page_ppn = @intCast(ptr), };
    }
};

const Pointer_t = packed struct {
    pml4: u9,
    pdpt: u9,
    pdt: u9,
    pt: u9,
    offset: u12,
    _rsvd: u16 = 0,
};

// Address Space
pub const AddressSpace_t = struct {
	data: *anyopaque,

	pub fn new() AddressSpace_t {
		var mem = page.new();
		
		const entries = mem.toPtr(*[512]PageTableEntry_t);
		
		for(entries) |*entry| {
			entry.* = PageTableEntry_t.fromInt(0);
		}

		return AddressSpace_t { .data = mem.toPtr(*anyopaque), };
	}

	pub fn delete(self: *AddressSpace_t) void {
		@as(*page, @ptrCast(@alignCast(self.data))).delete();
	}

	pub fn use(self: *AddressSpace_t) void {
		const data = self.data;
		asm volatile("movq %%cr3, [data]" : [data]"=r"(data) ::);
	}
};

// Map physical address "src" to virtual address "dest"
pub fn mmap(src: *anyopaque, dest: *anyopaque, addr_space: AddressSpace_t) void {
	var buf: [4096]u8 = undefined;

    const page_num = @intFromPtr(src) / info.page_size;
    const ptr: Pointer_t = @bitCast(@intFromPtr(dest));
    const space: *[512]PageTableEntry_t = @ptrCast(@alignCast(addr_space.data));

    const pml4 = space[ptr.pml4].index();    
    const pdpt = pml4[ptr.pdpt].index();
    const pdt = pdpt[ptr.pdt].index();
    const pt = &pdt[ptr.pt].index()[0];

    pt.* = PageTableEntry_t.fromInt(page_num);
}

// Unmap virtual address "ptr"
pub fn munmap(src: *anyopaque, addr_space: AddressSpace_t) void {
	const ptr: Pointer_t = @bitCast(@intFromPtr(src));
	const space: *[512]PageTableEntry_t = @ptrCast(@alignCast(addr_space.data));

	const pml4 = space[ptr.pml4].index();
	const pdpt = pml4[ptr.pdpt].index();
	const pdt = pdpt[ptr.pdt].index();
	const pt = &pdt[ptr.pt].index()[0];

	pt.page_ppn = 0;
}
