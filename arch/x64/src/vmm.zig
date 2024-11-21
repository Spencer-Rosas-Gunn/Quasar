const info = @import("info.zig");
const Page_t = @import("../page.zig").Page_t;

const io = @import("../io.zig");

var buf: [256]u8 = undefined;

const PageTableEntry_t = packed struct {
	present: bool = true,
	writeable: bool,
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

	pub fn fromInt(ptr: anytype, writeable: bool) PageTableEntry_t {	
		const out: PageTableEntry_t = .{ .page_ppn = @intCast(ptr), .writeable = writeable, };

		io.kprintf(&buf, "mem = {*}\n", .{ Page_t.fromInt(out.page_ppn).toPtr([*]usize) });
		const mem = Page_t.fromInt(out.page_ppn).toPtr([*]usize);
		@memset(mem[0..512], 0);

		return out;
	}

	pub fn index(self: *PageTableEntry_t) *[512]PageTableEntry_t {	
		var page = Page_t.new();

		if(@cmpxchgStrong(PageTableEntry_t, self, @as(PageTableEntry_t, @bitCast(@as(usize, 0))), fromInt(page.page, true), .acq_rel, .acquire) != null) {
			page.delete();
		} else {
			for(Page_t.fromInt(self.page_ppn).toPtr(*[512]PageTableEntry_t)) |*entry| {
				entry.* = @bitCast(@as(usize, 0));
			}
		}

		return Page_t.fromInt(self.page_ppn).toPtr(*[512]PageTableEntry_t);
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
		var mem = Page_t.new();

		@memset(mem.toPtr([*]usize)[0..512], 0);

		return AddressSpace_t { .data = mem.toPtr(*anyopaque), };
	}

	pub fn delete(self: *AddressSpace_t) void {
		const space: *[512]PageTableEntry_t = @ptrCast(@alignCast(self.data));
		
		for(1..512) |w| {
			const pml4 = space[w].index();

			for(1..512) |x| {
				const pdpt = pml4[x].index();

				for(1..512) |y| {
					const pdt = pdpt[y].index();

					for(1..512) |z| {
						var page = Page_t.fromInt(pdt[z].page_ppn);
						page.delete();
					}

					var page = Page_t.fromInt(pdpt[y].page_ppn);
					page.delete();
				}

				var page = Page_t.fromInt(pml4[x].page_ppn);
				page.delete();
			}

			var page = Page_t.fromInt(space[w].page_ppn);
			page.delete();
		}
	
		@as(*Page_t, @ptrCast(@alignCast(self.data))).delete();
	}

	pub fn use(self: *AddressSpace_t) void {
		const data = self.data;
		asm volatile("movq %%cr3, [data]" : [data]"=r"(data) ::);
	}
};

// Map physical address "src" to virtual address "dest"
pub fn mmap(src: *anyopaque, dest: *anyopaque, addr_space: AddressSpace_t, writeable: bool) void {
	const page_num = @intFromPtr(src) / info.page_size;
	const ptr: Pointer_t = @bitCast(@intFromPtr(dest));
	const space: *[512]PageTableEntry_t = @ptrCast(@alignCast(addr_space.data));

	const pml4 = space[ptr.pml4].index();	   
	const pdpt = pml4[ptr.pdpt].index();	
	const pdt = pdpt[ptr.pdt].index();	
	const pt = &pdt[ptr.pt].index()[0];

	io.kprintf(&buf, "{*}.* = PageTableEntry_t.fromInt({}, {})\n", .{ pt, page_num, writeable })

	const entry = PageTableEntry_t.fromInt(page_num, writeable);

	io.kprintf(&buf, "Entry Computed!\n", .{});
	
	pt.* = entry;

	io.kprintf(&buf, "MMap\n", .{});
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
