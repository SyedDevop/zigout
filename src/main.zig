const std = @import("std");
const rl = @import("raylib");
const object = @import("object.zig");
const config = @import("config.zig");
const Game = @import("Game.zig");

var rand: std.Random = undefined;

extern fn keyPressed(key: u8) void;
extern fn keyReleased(key: u8) void;

pub fn randomFloat() f32 {
    return rand.float(f32);
}
pub fn drawReact(react: object.Rectangle, color: object.Color) void {
    rl.drawRectangleRec(.{
        .x = react.x,
        .y = react.y,
        .width = react.width,
        .height = react.height,
    }, .{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = color.a,
    });
}

fn drawText(text: []const u8, posX: u32, posY: u32, fontSize: u32, color: object.Color) void {
    rl.drawText(
        rl.textFormat("%.*s", .{ text.len, text.ptr }),
        @intCast(posX),
        @intCast(posY),
        @intCast(fontSize),
        .{
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = color.a,
        },
    );
}

fn measureText(text: []const u8, fontSize: u32) usize {
    return @intCast(rl.measureText(rl.textFormat("%.*s", .{ text.len, text.ptr }), @intCast(fontSize)));
}

pub var collid_sound: rl.Sound = undefined;
pub var death_sound: rl.Sound = undefined;
pub var lose_sound: rl.Sound = undefined;
pub var win_sound: rl.Sound = undefined;
pub fn main(init: std.process.Init) !void {
    {
        var seed: u64 = undefined;
        init.io.random(std.mem.asBytes(&seed));
        var prng = std.Random.DefaultPrng.init(seed);
        rand = prng.random();
    }
    var show_alive_particle: bool = false;
    rl.initWindow(config.WINDOW_WIDTH, config.WINDOW_HEIGHT, "[Z]brake");
    rl.initAudioDevice();

    {
        collid_sound = try rl.loadSound("assets/sounds/collide.wav");
        death_sound = try rl.loadSound("assets/sounds/die.wav");
        lose_sound = try rl.loadSound("assets/sounds/lose.wav");
        win_sound = try rl.loadSound("assets/sounds/win.wav");
    }

    defer rl.closeWindow(); // Close window and OpenGL context
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    const game_init_config = Game.InitConfig{
        .drawReact = drawReact,
        .randomFloat = randomFloat,
        .drawText = drawText,
        .measureText = measureText,
    };
    Game.init(game_init_config);
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        const dt: f32 = rl.getFrameTime();
        if (rl.isKeyPressed(.f3)) show_alive_particle = !show_alive_particle;
        if (rl.isKeyPressed(.f4)) Game.show_fps = !Game.show_fps;
        while (true) {
            const key = rl.getKeyPressed();
            if (key == .null) break;
            const key_caped: u8 = switch (key) {
                .left => 37,
                .right => 38,
                else => brk: {
                    const ket_to_num: u32 = @intCast(@backingInt(key));
                    if (ket_to_num < 0 or ket_to_num > 90) break :brk 0;
                    break :brk @intCast(ket_to_num);
                },
            };
            keyPressed(key_caped);
        }
        if (rl.isKeyReleased(.a) or rl.isKeyReleased(.left)) keyReleased('a');
        if (rl.isKeyReleased(.d) or rl.isKeyReleased(.right)) keyReleased('d');
        Game.update(dt);
        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.getColor(config.BACKGROUND_COLOR));

        Game.render();
        if (Game.god_mode) rl.drawText("God Mode", config.WINDOW_WIDTH - 150, 40, 20, .{ .r = 255, .b = 50, .g = 50, .a = 255 });
        if (show_alive_particle) {
            rl.drawText(rl.textFormat("Alive Particles: %d", .{Game.alive_particles}), config.WINDOW_WIDTH - 200, 60, 20, .{ .r = 50, .b = 155, .g = 150, .a = 255 });
        }
        if (Game.show_fps) rl.drawFPS(config.WINDOW_WIDTH - 150, 10);
    }
}
