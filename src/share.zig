const pmm = @import("page.zig");
const info = @import("arch/info.zig");

pub const SharedPool_t = struct {
	page: pmm.Page_t,

	pub fn new(size: usize) SharedPool_t {
		const out: SharedPool_t = .{ .page = pmm.Page_t.new(), };
		const array = out.page.toPtr(*[512]usize);

		array[0] = size;
		array[1] = 1;

		var i: usize = 2;
		while(i < size + 2) : (i += 1) {
			array[i] = pmm.Page_t.new().page;
		}

		@memset((out.page.toPtr([*]usize) + i)[(size + 2)..512], 0);

		return out;
	}

	pub fn reduce(self: *SharedPool_t) void {
		if(@atomicRmw(usize, &self.page.toPtr([*]usize)[1], .Sub, 1, .acq_rel) == 1) {
			for(self.page.toPtr([*]usize)[2..512]) |i| {
				if(i == 0) {
					continue;
				}

				var pg = pmm.Page_t.fromInt(i);
				pg.delete();
			}

			self.page.delete();
		}
	}

	pub fn retain(self: *SharedPool_t) void {
		_ = @atomicRmw(usize, &self.page.toPtr([*]usize)[1], .Add, 1, .acq_rel);
	}

	pub fn write(self: *SharedPool_t, no: usize, dest: pmm.Page_t) void {
		const array = self.page.toPtr([*]usize);
		@memcpy((array + 2)[no].toPtr(*[512]usize), dest.toPtr(*[512]usize));
	}

	pub fn read(self: *SharedPool_t, no: usize, dest: pmm.Page_t) void {
		const array = self.page.toPtr([*]usize);
		@memcpy(dest.toPtr(*[512]usize), (array + 2)[no].toPtr(*[512]usize));
	}
};
