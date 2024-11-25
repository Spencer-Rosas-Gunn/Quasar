const info = @import("info.zig");
const Page_t = @import("../page.zig").Page_t;
const PageRef_t = @import("../page.zig").PageRef_t;
const io = @import("../io.zig");

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
		return PageTableEntry_t { .page_ppn = @intCast(ptr), .writeable = writeable, };
	}

	pub fn index(self: *PageTableEntry_t) *[512]PageTableEntry_t {	
		var page = Page_t.new();

		if(@cmpxchgStrong(PageTableEntry_t, self, @as(PageTableEntry_t, @bitCast(@as(usize, 0))), fromInt(page.page, true), .acq_rel, .acquire) != null) {
			page.delete();
		} else {
			@memset(Page_t.fromInt(self.page_ppn).toPtr([*]usize)[0..512], 0);
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

pub const AddressSpace_t = struct {
	data: Page_t,

	pub fn new() AddressSpace_t {	
		const out = AddressSpace_t { .data = Page_t.new(), };

		@memset(out.data.toPtr([*]usize)[0..512], 0);

		return out;
	}

	pub fn delete(self: *AddressSpace_t) void {
		var pml4 = self.data;
	
		for(pml4.toPtr(*[512]PageTableEntry_t)) |*pdpt_entry| {
			if(pdpt_entry.page_ppn == 0) {
				continue;
			}
			
			var pdpt = Page_t.fromInt(pdpt_entry.page_ppn);

			for(pdpt.toPtr(*[512]PageTableEntry_t)) |*pdt_entry| {
				if(pdt_entry.page_ppn == 0) {
					continue;
				}
			
				var pdt = Page_t.fromInt(pdt_entry.page_ppn);

				for(pdt.toPtr(*[512]PageTableEntry_t)) |*pt_entry| {
					if(pt_entry.page_ppn == 0) {
						continue;
					}
				
					var pt = Page_t.fromInt(pt_entry.page_ppn);

					for(pt.toPtr(*[512]PageTableEntry_t)) |*entry| {
						PageRef_t.new(entry.page_ppn).reduce();
					}

					pt.delete();
				}

				pdt.delete();
			}

			pdpt.delete();
		}

		pml4.delete();
	}

	pub fn use(self: *AddressSpace_t) void {
		const data = self.data.toPtr(*anyopaque);
		asm volatile("movq %%cr3, [data]" : [data]"=r"(data) ::);
	}
};

pub fn mmap(src: *anyopaque, dest: *anyopaque, addr_space: AddressSpace_t, writeable: bool) void {
	const page_num = @intFromPtr(src) / info.page_size;
	const ptr: Pointer_t = @bitCast(@intFromPtr(dest));
	const space = addr_space.data.toPtr(*[512]PageTableEntry_t);

	const pml4 = space[ptr.pml4].index();	   
	const pdpt = pml4[ptr.pdpt].index();	
	const pdt = pdpt[ptr.pdt].index();	
	const pt = &pdt[ptr.pt].index()[0];

	pt.* = PageTableEntry_t.fromInt(page_num, writeable);
}

pub fn munmap(src: *anyopaque, addr_space: AddressSpace_t) void {
	const ptr: Pointer_t = @bitCast(@intFromPtr(src));
	const space = addr_space.data.toPtr(*[512]PageTableEntry_t);
	
	const pml4 = space[ptr.pml4].index();
	const pdpt = pml4[ptr.pdpt].index();
	const pdt = pdpt[ptr.pdt].index();
	const pt = &pdt[ptr.pt].index()[0];

	pt.page_ppn = 0;
}
