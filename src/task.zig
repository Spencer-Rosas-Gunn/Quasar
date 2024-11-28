const vmm = @import("arch/vmm.zig");
const info = @import("arch/info.zig");
const page = @import("page.zig");

pub const pid_t = u32;

pub const Perms_t = enum(u8) {
	userspace = 0,
	driverspace = 1,	
};

export fn noop_msg(_: usize, _: *anyopaque) *anyopaque {
	return undefined;
}

export fn noop_err(_: usize, _: *anyopaque) void {}

pub const Task_t = struct {
	// Handle message passes for IPC
	msg_callback: *const fn(pid_t, usize, *anyopaque) *anyopaque,
	// Handle errors (e.g. page faults) raised by the kernel
	err_callback: *const fn(pid_t, usize, *anyopaque) void,
	// Handle memory share requests
	share_callback: *const fn(pid_t, usize, usize) bool,
	// Store the address space of the process
	addr_space: vmm.AddressSpace_t,
	// Store the current location of the process
	loc: *const fn() void,
	// Check if the task owns its address-space
	isChild: bool,
	// Check if the task is driverspace or userspace
	perms: Perms_t,
};

pub const TaskQueue_t = struct {
	const Node_t = struct {
		task: ?*Task_t,
		next: *Node_t,
	};

	head: *Node_t = undefined,
	tail: *Node_t = undefined,

	pub fn new() TaskQueue_t {
		var out: TaskQueue_t = .{};
		
		out.tail = page.Page_t.new().toPtr(*Node_t);
		out.head = out.tail;

		out.head.task = null;

		return out;
	}

	pub fn push(self: *TaskQueue_t, task: *Task_t) !void {
		const new_node: *Node_t = page.Page_t.new().toPtr(*Node_t);
		new_node.task = task;
		
		self.head.next = new_node;
		self.head = new_node;
	}

	pub fn pop(self: *TaskQueue_t) Task_t {
		const out = self.tail.task;
		
		var pg = page.Page_t.fromInt(@intFromPtr(self.tail) / info.page_size);
		defer pg.delete();

		self.tail = self.tail.next;

		// There will never be two null-tasks in a row, so the recursion is bounded
		// Also, there's zero overhead since this will just become a tail-call
		return out orelse self.pop();
	}

	pub fn top(self: *TaskQueue_t) Task_t {
		return self.tail.task orelse self.tail.next.task orelse undefined;
	}

	pub fn kill(self: *TaskQueue_t) void {
		const task = self.pop();
		if(!task.isChild) task.addr_space.delete();
	}
};
