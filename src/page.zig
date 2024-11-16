const uefi = @import("std").os.uefi;
const tables = @import("uefi-tables.zig");
const info = @import("arch/info.zig");

pub const Page_t = packed struct {
	page: info.RawPage_t,

	pub var head: struct {
		list: Page_t = undefined,
		index: usize = 0,
	} = .{};

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
	    if (head.index > 0) {
	        const out = fromInt(head.list.toPtr([*]usize)[head.index]);
	        head.index -= 1;
	        return out;
	    }
	
	    const out = head.list;
	    head.list = fromInt(head.list.toPtr([*]usize)[head.index]);
	    head.index = info.page_size / @sizeOf(usize);
	    return out;
	}

	pub fn delete(self: *Page_t) void {
	    if (head.index < info.page_size / @sizeOf(usize)) {
	        head.index += 1;
	        head.list.toPtr([*]usize)[head.index] = @intCast(self.page);
	        return;
	    }

 	   const last = head.list;
 	   head.list = fromInt(self.page);
 	   head.index = 0;
 	   head.list.toPtr(*usize).* = @intCast(last.page);
	}
};

pub fn init() void {
	const static = struct {
        var buf: [info.page_size / @sizeOf(usize)]usize = undefined;
    };
    
    Page_t.head.list.page = @intCast(@intFromPtr(&static.buf));
	
	var mmap: [*]uefi.tables.MemoryDescriptor = undefined;
    var mmap_size: usize = 0;
    var mmap_key: usize = undefined;
    var desc_size: usize = undefined;
    var desc_version: u32 = undefined;

    while (uefi.Status.BufferTooSmall == tables.boot_services.getMemoryMap(&mmap_size, mmap, &mmap_key, &desc_size, &desc_version)) {
        _ = tables.boot_services.allocatePool(uefi.tables.MemoryType.BootServicesData, mmap_size, @ptrCast(&mmap));
  	}

	var i: usize = 0;
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
