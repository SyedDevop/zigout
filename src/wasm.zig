const std = @import("std");
const math = std.math;
const object = @import("object.zig");
const Game = @import("Game.zig");
const conf = @import("config.zig");

// The default std.log writer needs OS I/O, which wasm32-freestanding lacks,
// so route logs to the JS console instead.
pub const std_options: std.Options = .{ .logFn = wasmLog };

/// level: 0 = err, 1 = warn, 2 = info, 3 = debug (matches std.log.Level).
extern fn logJs(level: u8, ptr: [*]const u8, len: usize) void;

fn wasmLog(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix = if (scope == .default) "" else "(" ++ @tagName(scope) ++ "): ";
    var buf: [1024]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    // On overflow the message is truncated; whatever fit is still logged.
    w.print(prefix ++ format, args) catch {};
    const msg = w.buffered();
    logJs(@intFromEnum(level), msg.ptr, msg.len);
}

extern fn drawReactJs(x: f32, y: f32, width: f32, height: f32, r: u8, g: u8, b: u8, a: u8) void;
extern fn randomFloatJs() f32;

fn randomFloat() f32 {
    return randomFloatJs();
}
fn drawReact(react: object.Rectangle, color: object.Color) void {
    drawReactJs(react.x, react.y, react.width, react.height, color.r, color.g, color.b, color.a);
}

export fn init() void {
    const game_init_config = Game.InitConfig{
        .drawReact = drawReact,
        .randomFloat = randomFloat,
    };
    Game.init(game_init_config);
}
export fn update(dt: f32) void {
    Game.update(dt);
}

export fn reset() void {
    Game.reset();
}

export fn render() void {
    Game.render();
}

export fn killAll() void {
    Game.killAll();
}

export fn getScore() u32 {
    return Game.score;
}
