pub export fn memset(dest: [*]u8, src: c_int, n: usize) [*]u8 {
    var i: usize = 0;

    while (i < n) : (i += 1) {
        dest[i] = @intCast(src);
    }

    return dest;
}

pub export fn memcpy(dest: [*]u8, src: [*]u8, n: usize) [*]u8 {
    var i: usize = 0;

    while (i < n) : (i += 1) {
        dest[i] = src[i];
    }

    return dest;
}
