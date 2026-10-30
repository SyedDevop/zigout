const std = @import("std");
const math = std.math;
const object = @import("object.zig");
const Game = @import("Game.zig");
const conf = @import("config.zig");

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
