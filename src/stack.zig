const Page_t = @import("page.zig").Page_t;
const info = @import("arch/info.zig");

pub fn new(t: type) type {
	if(@sizeOf(t) != @sizeOf(usize)) {
		@compileError("Item must be 64-bit aligned!");
	}

	return struct {
		const Self = @This();

		list: Page_t,
		index: usize,

		pub fn new() Self {
			const out: Self = .{
				.list = Page_t.new(),
				.index = 0,
			};

			out.list.toPtr(*usize).* = 0;

			return out;
		}

		pub fn push(self: *Self, item: t) void {
			if(self.index < info.page_size / @sizeOf(usize)) {
				self.index += 1;
				self.list.toPtr([*]t)[self.index] = item;
			}
			else {
				const last = self.list;
				self.list = Page_t.new();
				self.index = 1;
				self.list.toPtr(*t).* = @intCast(@as(info.RawPage_t, @bitCast(last)));
				self.list.toPtr([*]t)[1] = item;
			}
		}

		pub fn pop(self: *Self) t {
			if(self.index > 0) {
				const out = self.list.toPtr([*]t)[self.index];
				self.index -= 1;
				return out;
			}
			else {
				var mem: Page_t = @bitCast(self.list);
				defer mem.delete();
				self.list = mem.toPtr(*Page_t).*;
				self.index = info.page_size / @sizeOf(usize) - 1;
				return self.list.toPtr([*]t)[info.page_size / @sizeOf(usize)];
			}
		}

		pub fn delete(self: *Self) void {
			self.list.delete();
		
			if(self.list.toPtr(*usize).* != 0) {
				self.list.toPtr(*Self).delete();
			}
		}
	};
}

