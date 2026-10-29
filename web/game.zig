const std = @import("std");
pub const String = struct {
    size: usize,
    ptr: [*]const u8,
};

pub export fn StringLen(str: String) usize {
    return str.size;
}

pub export fn StringData(str: String) [*]const u8 {
    return str.ptr;
}
pub export fn allocString() *String {
    return std.heap.wasm_allocator.create(String) catch unreachable;
}

pub export fn allocUsize() *usize {
    return std.heap.wasm_allocator.create(usize) catch unreachable;
}

pub export fn helloWorld() *String {
    var out = allocString();
    const val = "Hello World";
    out.ptr = val.ptr;
    out.size = val.len;
    return out;
}
