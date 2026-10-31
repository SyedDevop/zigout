const std = @import("std");
const Io = std.Io;
const Ast = std.zig.Ast;
const Color = std.zig.Color;
const fatal = std.process.fatal;
const AstGen = std.zig.AstGen;
const Zir = std.zig.Zir;

const ArrayTypes = std.ArrayList(TypeKind);
const ArrayString = std.ArrayList(u8);

const CodeBase = struct {
    path: []const u8,
    source: [:0]const u8,
};

pub const TypeKind = union(enum) {
    unknown,
    void,
    bool,
    number,
    bigint,
    pointer,
    array,
    optional,

    pub fn getJsTypeInfo(tk: TypeKind) struct { []const u8, ?[]const u8 } {
        return switch (tk) {
            .bool, .void, .number, .bigint => .{ @tagName(tk), null },
            .unknown => .{ "any", "Unknown or unresolved type" },
            .pointer => .{ "number", "WASM memory address" },
            .array => .{ "number", "Pointer to data in WASM memory" },
            .optional => .{ "number", "WASM representation of optional" },
        };
    }
};

fn classifyType(tree: *const Ast, node: Ast.Node.Index, file_path: []const u8) TypeKind {
    switch (tree.nodeTag(node)) {
        .optional_type => return .optional,
        .array_type => return .array,
        .ptr_type_aligned => return .pointer,
        .identifier => {
            const name = tree.tokenSlice(tree.nodeMainToken(node));
            if (name.len <= 0) unreachable;
            const n = name[0];
            if (isType(name, "bool")) {
                return .bool;
            } else if (isType(name, "void")) {
                return .void;
            } else if (isType(name, "usize") or isType(name, "isize") or isNumberType(n, name[1..])) {
                return .number;
            } else if (isBigNumberType(n, name[1..])) {
                return .bigint;
            } else return .unknown;
        },
        else => {
            myLog(file_path, tree, node, .war, "Unknown Tag: {t}, Source: {s}\n", .{ tree.nodeTag(node), tree.getNodeSource(node) });
            return .unknown;
        },
    }
}

pub fn findDeclarations(
    allocator: std.mem.Allocator,
    ast: *const Ast,
    file_path: []const u8,
    exports_array: *ArrayString,
    extern_array: *ArrayString,
) !usize {
    var declarations: usize = 0;

    var comments: ArrayString = .empty;
    defer comments.deinit(allocator);

    var buffer: [1]Ast.Node.Index = undefined;
    loop: for (ast.rootDecls()) |decl| {
        if (ast.fullFnProto(&buffer, decl)) |proto| {
            if (isExportOrExtern(ast, proto.extern_export_inline_token)) {
                const var_name = if (proto.name_token) |nt| ast.tokenSlice(nt) else {
                    myLog(file_path, ast, decl, .war, "No Name for the function {s}\n", .{ast.getNodeSource(decl)});
                    continue :loop;
                };
                const is_extern = isExtern(ast, proto.extern_export_inline_token);
                declarations += 1;
                const target_array = if (is_extern) extern_array else exports_array;
                const target_array_len = target_array.items.len;
                const pad = if (is_extern) "   " else " ";

                comments.clearRetainingCapacity();
                try comments.print(allocator, "{s}/**\n", .{pad});
                const comment_size = comments.items.len;

                try target_array.print(allocator, "{s}{s} : (", .{ pad, var_name });
                var it = proto.iterate(ast);
                while (it.next()) |ita| {
                    if (ita.name_token) |nt| try target_array.print(allocator, "{s}: ", .{ast.tokenSlice(nt)});
                    if (ita.type_expr) |te| {
                        const type_kind = classifyType(ast, te, file_path);
                        const js_type, const description = type_kind.getJsTypeInfo();
                        if (description) |desc| {
                            try comments.print(
                                allocator,
                                "{s}* @param {{{s}}} {s} - {s}: `{s}`\n",
                                .{ pad, js_type, var_name, desc, ast.getNodeSource(te) },
                            );
                        }
                        try target_array.print(allocator, "{s}, ", .{js_type});
                    }
                }
                try target_array.print(allocator, ") => ", .{});
                if (proto.ast.return_type.unwrap()) |rt| {
                    const type_kind = classifyType(ast, rt, file_path);
                    const js_type, const description = type_kind.getJsTypeInfo();
                    if (description) |desc| {
                        try comments.print(
                            allocator,
                            "{s}* @return {{{s}}} {s} - {s}: `{s}`\n",
                            .{ pad, js_type, var_name, desc, ast.getNodeSource(rt) },
                        );
                    }
                    try target_array.print(allocator, "{s},\n", .{js_type});
                }
                if (comments.items.len > comment_size) {
                    try comments.print(allocator, "{s}*/\n", .{pad});
                    const comments_slice = try comments.toOwnedSlice(allocator);
                    defer allocator.free(comments_slice);

                    try target_array.insertSlice(allocator, target_array_len, comments_slice);
                }
            }
        } else if (ast.fullVarDecl(decl)) |var_decl| {
            if (isExportOrExtern(ast, var_decl.extern_export_token)) {
                const var_name = ast.tokenSlice(var_decl.ast.mut_token + 1);
                var js_type: []const u8 = undefined;
                var description: ?[]const u8 = undefined;

                if (var_decl.ast.type_node.unwrap()) |tn| {
                    const type_kind = classifyType(ast, tn, file_path);
                    js_type, description = type_kind.getJsTypeInfo();
                } else {
                    myLog(file_path, ast, decl, .war, "This variable has no type, Source: `{s}`\n", .{ast.getNodeSource(decl)});
                    continue :loop;
                }
                declarations += 1;
                const is_extern = isExtern(ast, var_decl.extern_export_token);
                const target_array = if (is_extern) extern_array else exports_array;
                const pad = if (is_extern) "   " else " ";
                if (description) |desc| {
                    const main_tok = ast.firstToken(decl);
                    const loc = ast.tokenLocation(0, main_tok);
                    try target_array.print(allocator, "{s}/**\n", .{pad});
                    try target_array.print(
                        allocator,
                        "{s}* @type {{{s}}} {s} - {s}: \n",
                        .{ pad, js_type, var_name, desc },
                    );
                    try target_array.print(
                        allocator,
                        "{s}* `{s}:{d}:{d} {s}`\n",
                        .{ pad, file_path, loc.line + 1, loc.column, ast.getNodeSource(decl) },
                    );
                    try target_array.print(allocator, "{s}*/\n", .{pad});
                }
                try target_array.print(allocator, "{s}{s} : {s},\n", .{ pad, var_name, js_type });
            }
        }
    }
    return declarations;
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const out_file = "./web/wasm.ts";
    var write_buffer: [1024]u8 = undefined;
    var stdout_w = Io.File.stdout().writer(io, &write_buffer);
    var stdout = &stdout_w.interface;

    const cwd = std.Io.Dir.cwd();
    var code_base = [_]CodeBase{
        .{ .path = "./src/wasm.zig", .source = undefined },
        .{ .path = "./src/Game.zig", .source = undefined },
        .{ .path = "./src/config.zig", .source = undefined },
    };
    defer {
        for (code_base) |cd| allocator.free(cd.source);
    }
    var read_buffer: [1024]u8 = undefined;

    var exports_array: ArrayString = .empty;
    var externs_array: ArrayString = .empty;

    for (&code_base) |*cb| {
        const source_file = try cwd.openFile(io, cb.path, .{});
        var file_closed = false;
        errdefer if (!file_closed) source_file.close(io);

        const stat = try source_file.stat(io);
        if (stat.kind == .directory) return {
            std.log.err("Path `{s}` is a directory", .{cb.path});

            continue;
        };

        var file_reader: Io.File.Reader = source_file.reader(io, &read_buffer);
        file_reader.size = stat.size;

        cb.source = std.zig.readSourceFileToEndAlloc(allocator, &file_reader) catch |err| switch (err) {
            error.ReadFailed => return file_reader.err.?,
            else => |e| return e,
        };
        source_file.close(io);
        file_closed = true;

        var tree = try Ast.parse(allocator, cb.source, .{});
        defer tree.deinit(allocator);
        if (tree.errors.len > 0) {
            const format_error: FormatAstError = .{
                .parse_error = tree.errors[0],
                .tree = &tree,
            };
            std.log.err("{f}", .{format_error});
            return;
        }

        var zir = try AstGen.generate(allocator, tree);
        defer zir.deinit(allocator);
        if (zir.hasCompileErrors()) {
            var wip_errors: std.zig.ErrorBundle.Wip = try .init(allocator);
            defer wip_errors.deinit();
            try wip_errors.addZirErrorMessages(zir, tree, cb.source, cb.path);
            var error_bundle = try wip_errors.toOwnedBundle("");
            defer error_bundle.deinit(allocator);
            try error_bundle.renderToStderr(io, .{}, .on);
            return;
        }

        const found = try findDeclarations(allocator, &tree, cb.path, &exports_array, &externs_array);
        const root = tree.rootDecls();
        try stdout.print("{s: <30} [{d:0>2}/{d:0>2}] declarations\n", .{ cb.path, found, root.len });
    }

    var exports = try exports_array.toOwnedSlice(allocator);
    defer allocator.free(exports);
    {
        try exports_array.appendSlice(allocator, "export interface WasmExports {\n");
        try exports_array.appendSlice(allocator, exports);
        allocator.free(exports);
        try exports_array.appendSlice(allocator,
            \\ /**
            \\ * Zig modules expose their linear memory back to JS
            \\ */ 
            \\ readonly memory: WebAssembly.Memory;
        );
        try exports_array.append(allocator, '\n');
        try exports_array.appendSlice(allocator, "};\n");
        exports = try exports_array.toOwnedSlice(allocator);
    }
    var externs = try externs_array.toOwnedSlice(allocator);
    defer allocator.free(externs);
    {
        try externs_array.appendSlice(allocator, "export interface WasmImports extends WebAssembly.Imports {\n");
        try externs_array.appendSlice(allocator, "  env: {\n");

        try externs_array.appendSlice(allocator, externs);
        allocator.free(externs);

        try externs_array.appendSlice(allocator, "  },\n");
        try externs_array.appendSlice(allocator, "};\n");

        externs = try externs_array.toOwnedSlice(allocator);
    }

    const ts_declaration = try cwd.createFile(init.io, out_file, .{ .truncate = true });
    defer ts_declaration.close(init.io);
    var file_write_buf: [1024]u8 = undefined;
    var ts_writer = ts_declaration.writer(init.io, &file_write_buf);
    try ts_writer.interface.writeAll(exports);
    try ts_writer.interface.writeAll("\n\n");
    try ts_writer.interface.writeAll(externs);
    try ts_writer.interface.writeAll(
        \\
        \\
        \\/**
        \\ * Type-safe interface mirroring the native WebAssemblyInstantiatedSource structure
        \\ */
        \\export interface ZigInstantiatedSource {
        \\  instance: Omit<WebAssembly.Instance, 'exports'> & { exports: WasmExports };
        \\  module: WebAssembly.Module;
        \\}
        \\
        \\
        \\export async function loadWasm(url: string, imports: WasmImports): Promise<ZigInstantiatedSource> {
        \\  // Explicitly cast the resulting promise structure to your target interfaces
        \\  return (await WebAssembly.instantiateStreaming(
        \\    fetch(url),
        \\    imports,
        \\  )) as unknown as ZigInstantiatedSource;
        \\}
    );
    try ts_writer.flush();

    try stdout.print("\n\n", .{});
    try stdout.print("Generated: {s}\n", .{out_file});
    try stdout.flush();
}

fn isDigit(dig: []const u8) bool {
    for (dig) |d| {
        if (!std.ascii.isDigit(d)) return false;
    }
    return true;
}

fn isNumberType(integer_sign: u8, integer_bit: []const u8) bool {
    if (integer_sign != 'u' and integer_sign != 'i' and integer_sign != 'f') return false;
    return isDigit(integer_bit);
}

fn isBigNumberType(integer_sign: u8, integer_bit: []const u8) bool {
    if (integer_sign != 'u' and integer_sign != 'i') return false;
    const num = std.fmt.parseInt(usize, integer_bit, 10) catch return false;
    if (num < 64) return false;
    return true;
}

fn isType(a: []const u8, b: []const u8) bool {
    const at = std.mem.trim(u8, a, " \n");
    const bt = std.mem.trim(u8, b, " \n");
    return std.mem.eql(u8, at, bt);
}

fn isExportOrExtern(ast: *const Ast, token: ?Ast.TokenIndex) bool {
    return if (token) |t| {
        const tag = ast.tokenTag(t);
        return tag == .keyword_export or tag == .keyword_extern;
    } else false;
}

fn isExtern(ast: *const Ast, token: ?Ast.TokenIndex) bool {
    return if (token) |t| {
        const tag = ast.tokenTag(t);
        return tag == .keyword_extern;
    } else false;
}

fn myLog(
    path: []const u8,
    ast: *const Ast,
    node: Ast.Node.Index,
    level: enum { err, war },
    comptime fmt: []const u8,
    args: anytype,
) void {
    const main_tok = ast.firstToken(node);
    const loc = ast.tokenLocation(0, main_tok);
    const PRINT_FMT = "{s}:{d}:{d} " ++ fmt;
    const PRINT_ARG = .{ path, loc.line + 1, loc.column } ++ args;
    if (level == .err) {
        std.log.err(PRINT_FMT, PRINT_ARG);
    } else std.log.warn(PRINT_FMT, PRINT_ARG);
}
const FormatAstError = struct {
    parse_error: Ast.Error,
    tree: *const Ast,

    pub fn format(
        ctx: FormatAstError,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try ctx.tree.renderError(ctx.parse_error, writer);
    }
};
