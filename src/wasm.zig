const std = @import("std");
const math = std.math;
const object = @import("object.zig");
const Game = @import("Game.zig");
const conf = @import("config.zig");
// The default std.log writer needs OS I/O, which wasm32-freestanding lacks,
// so route logs to the JS console instead.
pub const std_options: std.Options = .{ .logFn = wasmLog };

/// level: 0 = err, 1 = warn, 2 = info, 3 = debug (matches std.log.Level).
extern fn jsLog(level: u8, ptr: [*]const u8, len: usize) void;
extern fn jsDrawReact(x: f32, y: f32, width: f32, height: f32, r: u8, g: u8, b: u8, a: u8) void;
extern fn jsRandomFloat() f32;
extern fn jsDrawText(text: [*]const u8, text_len: usize, pos_x: u32, pos_y: u32, font_size: u32, r: u8, g: u8, b: u8, a: u8) void;
extern fn jsMeasureText(text: [*]const u8, text_len: usize, font_size: u32) usize;
/// This will emmit
/// const Collision = enum(u32) {
///  border_left,    -> 1
///  border_right,   -> 2
///  border_top,     -> 3
///  border_bottom,  -> 4
///  bar,            -> 5
///  target,         -> 6>..n
///  _
///  }
///
extern fn jsEmitCollision(event: u32) void;
/// this enum event will be emitted
/// pub const StateKind = enum {
///     // Waiting until the player proves that they can move (with A/D keys)
///     START,
///     // The ball from the life bar rapidly moving towards the paddle to attach to it
///     ATTACH,
///     // The ball is attached to the paddle and waiting until the player presses SPACE
///     READY,
///     // Just the usual game play until the ball hits the bottom
///     PLAY,
///     // Ran out of lifes before destroying all the targets
///     GAMEOVER,
///     // Start the whole game from scratch
///     RESTART,
///     // Destroyed all the targets
///     VICTORY,
///     RESTORE_TARGETS,
/// };
extern fn jsEmitGameState(event: u32) void;

fn wasmLog(comptime level: std.log.Level, comptime scope: @EnumLiteral(), comptime format: []const u8, args: anytype) void {
    const prefix = if (scope == .default) "" else "(" ++ @tagName(scope) ++ "): ";
    var buf: [1024]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    // On overflow the message is truncated; whatever fit is still logged.
    w.print(prefix ++ format, args) catch {};
    const msg = w.buffered();
    jsLog(@backingInt(level), msg.ptr, msg.len);
}

fn randomFloat() f32 {
    return jsRandomFloat();
}

fn drawReact(react: object.Rectangle, color: object.Color) void {
    jsDrawReact(react.x, react.y, react.width, react.height, color.r, color.g, color.b, color.a);
}

fn drawText(text: []const u8, posX: u32, posY: u32, fontSize: u32, color: object.Color) void {
    jsDrawText(text.ptr, text.len, posX, posY, fontSize, color.r, color.g, color.b, color.a);
}

fn measureText(text: []const u8, fontSize: u32) usize {
    return jsMeasureText(text.ptr, text.len, fontSize);
}

fn emitCollision(c: Game.Collision) void {
    return jsEmitCollision(@backingInt(c));
}
fn emitGameState(c: object.StateKind) void {
    return jsEmitGameState(@backingInt(c));
}

export fn init() void {
    const game_init_config = Game.InitConfig{
        .drawReact = drawReact,
        .randomFloat = randomFloat,
        .drawText = drawText,
        .measureText = measureText,
        .emitCollision = emitCollision,
        .emitGameState = emitGameState,
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
