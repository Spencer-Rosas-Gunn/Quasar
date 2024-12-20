const uefi = @import("std").os.uefi;
const tables = @import("uefi-tables.zig");
const info = @import("arch/info.zig");
const atomic = @import("std").builtin.AtomicOrder;
const io = @import("io.zig");

const Node_t = struct {
	value: usize,
	next: *Node_t
};

const alloc = struct {
	var bump_index: usize = 0;
	var page_heap: [*]Node_t = undefined;
	var head: *Node_t = undefined;

	pub fn new() *Node_t {
		_ = @atomicRmw(usize, &bump_index, .Add, 1, .release);
		return &page_heap[bump_index];
	}

	pub fn delete() void {
		_ = @atomicRmw(usize, &bump_index, .Sub, 1, .acquire);
	}
};

pub const Page_t = struct {
	page: usize,
	count: usize = 1,

	pub fn fromInt(int: anytype) Page_t {
		var out: Page_t = undefined;
		out.page = @intCast(int);
		return out;
	}

	pub fn fromPtr(ptr: anytype) Page_t {
		var out: Page_t = undefined;
		out.page = @intCast(@intFromPtr(ptr));
		return out;
	}

	pub fn toPtr(self: *const Page_t, t: type) t {
		return @ptrFromInt(@as(usize, @intCast(self.page)) * info.page_size);
	}

	pub fn new() Page_t {
		const out = @atomicRmw(*Node_t, &alloc.head, .Xchg, alloc.head.next, .acq_rel).value;
		defer alloc.delete();
		return Page_t.fromInt(out);
	}

	pub fn retain(self: *Page_t) void {
		_ = @atomicRmw(usize, &self.count, .Add, 1, .acq_rel);
	}

	pub fn reduce(self: *Page_t) void {
		if(1 == @atomicRmw(usize, &self.count, .Sub, 1, .acq_rel)) {
			self.delete();
		}
	}

	pub fn delete(self: *const Page_t) void {	
		var node = alloc.new();
		node.value = self.page;

		node.next = @atomicRmw(*Node_t, &alloc.head, .Xchg, node, .acq_rel);
	}
};

pub const PageRef_t = struct {
	idx: usize,

	pub var prt: []Page_t = undefined;

	pub fn new(loc: usize) PageRef_t {
		const page = Page_t.fromInt(loc);
		defer page.delete();
		prt[page.page] = page;
		return .{ .idx = page.page, };
	}

	pub fn retain(self: *const PageRef_t) void {
		prt[self.idx].retain();
	}

	pub fn reduce(self: *const PageRef_t) void {
		prt[self.idx].reduce();
	}
};

pub fn init() void {
	var mmap: [*]uefi.tables.MemoryDescriptor = undefined;
	var mmap_size: usize = 0;
	var desc_size: usize = undefined;
	var desc_version: u32 = undefined;

	while (uefi.Status.BufferTooSmall == tables.boot_services.getMemoryMap(&mmap_size, mmap, &tables.mmap_key, &desc_size, &desc_version)) {
		_ = tables.boot_services.allocatePool(uefi.tables.MemoryType.BootServicesData, mmap_size, @ptrCast(&mmap));
	}

	var total_mem: usize = 0;

	var i: usize = 0;
	var max: usize = 0;
	while(i < mmap_size / desc_size) : (i += 1) {
		mmap = @alignCast(@ptrCast(&@as([*]u8, @alignCast(@ptrCast(mmap)))[desc_size]));

		// Double check that memory isn't MMIO, write-protected, read-protected, execute-protected, readonly, or shared with other devices
		if (mmap[0].attribute.uce or mmap[0].attribute.wp or mmap[0].attribute.rp or mmap[0].attribute.xp or mmap[0].attribute.ro or mmap[0].attribute.sp) {
			continue;
		}
		
		// Ensure memory is intended for runtime use
		if (!mmap[0].attribute.memory_runtime) {
			continue;
		}

		total_mem += mmap[0].number_of_pages;
		max = mmap[0].physical_start / info.page_size + mmap[0].number_of_pages;
	}

	// Initialize alloc.page_heap & alloc.head
	const mem = uefi.pool_allocator.alloc(Node_t, total_mem) catch unreachable;
	alloc.page_heap = @ptrCast(&mem[0]);
	alloc.head = &alloc.page_heap[0];
	alloc.bump_index = 0;

	// Initialize page reference table (prt)
	PageRef_t.prt = uefi.pool_allocator.alloc(Page_t, max) catch unreachable;

	// Reread the memory map, since allocating memory messes with it
	while (uefi.Status.BufferTooSmall == tables.boot_services.getMemoryMap(&mmap_size, mmap, &tables.mmap_key, &desc_size, &desc_version)) {
		_ = tables.boot_services.allocatePool(uefi.tables.MemoryType.BootServicesData, mmap_size, @ptrCast(&mmap));
	}

	i = 0;
	while (i < mmap_size / desc_size) : (i += 1) {
		// *(char**)&mmap += desc_size
		mmap = @alignCast(@ptrCast(&@as([*]u8, @alignCast(@ptrCast(mmap)))[desc_size]));
	
		// Double check that memory isn't MMIO, write-protected, read-protected, execute-protected, readonly, or shared with other devices
		if (mmap[0].attribute.uce or mmap[0].attribute.wp or mmap[0].attribute.rp or mmap[0].attribute.xp or mmap[0].attribute.ro or mmap[0].attribute.sp) {
			continue;
		}

		// Ensure memory is intended for runtime use
		if (!mmap[0].attribute.memory_runtime) {
			continue;
		}

		// Add those pages to the freelist
		const start = mmap[0].physical_start / info.page_size;

		var j: usize = 0;
		while (j < mmap[0].number_of_pages) : (j += 1) {
			var out: Page_t = .{ .page = @intCast(start + j) };
			out.delete();
		}
	}
}
