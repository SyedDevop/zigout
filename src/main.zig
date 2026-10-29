const std = @import("std");
const rl = @import("raylib");
const object = @import("object.zig");
const config = @import("config.zig");
const Game = @import("Game.zig");

var rand: std.Random = undefined;

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
    // rl.toggleBorderlessWindowed();
    rl.initAudioDevice();
    const game_init_config = Game.InitConfig{
        .drawReact = drawReact,
        .randomFloat = randomFloat,
    };
    Game.init(game_init_config);

    {
        collid_sound = try rl.loadSound("assets/sounds/collide.wav");
        death_sound = try rl.loadSound("assets/sounds/die.wav");
        lose_sound = try rl.loadSound("assets/sounds/lose.wav");
        win_sound = try rl.loadSound("assets/sounds/win.wav");
    }
    defer rl.closeWindow(); // Close window and OpenGL context
    rl.setTargetFPS(config.FPS); // Set our game to run at 60 frames-per-second
    const dfont = try rl.getFontDefault();
    const pauseT = Text.init(config.PAUSE_T, 64, 0xFFFFFFFF, dfont);
    const restartT = Text.init(config.RESTART_T, 40, 0xFFFFFFFF, dfont);
    const oylT = Text.init(config.OYL_T, 64, 0xFFFFFFFF, dfont);
    const wonT = Text.init(config.WON_T, 64, 0xFFFFFFFF, dfont);

    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        const dt: f32 = rl.getFrameTime();
        Game.bar.dx = 0;
        if (rl.isKeyDown(.a) or rl.isKeyDown(.left)) {
            Game.bar.dx -= 1;
            Game.left = true;
        }
        if (rl.isKeyDown(.d) or rl.isKeyDown(.right)) {
            Game.bar.dx += 1;
            Game.right = true;
        }
        if (rl.isKeyPressed(.k)) Game.killAll();
        if (rl.isKeyPressed(.f3)) show_alive_particle = !show_alive_particle;
        if (rl.isKeyPressed(.f4)) Game.show_fps = !Game.show_fps;
        if (rl.isKeyPressed(.f5)) Game.god_mode = !Game.god_mode;
        if (rl.isKeyPressed(.space)) {
            switch (Game.state) {
                .PLAY => Game.pause = !Game.pause,
                .READY => {
                    const driction: f16 = if (Game.left) 1 else -1;
                    Game.proj.dx = driction;
                    Game.state = .PLAY;
                },
                else => {},
            }
        }
        switch (Game.state) {
            .PLAY, .READY, .START, .ATTACH => Game.update(dt),
            .GAMEOVER, .VICTORY => if (rl.isKeyPressed(.r)) {
                Game.reset();
                Game.state = .RESTART;
            },
            .RESTART => Game.state = .START,
            else => {},
        }
        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.getColor(config.BACKGROUND_COLOR));

        rl.drawText(rl.textFormat("Score: %d", .{Game.score}), 10, 10, 20, .white);
        if (Game.god_mode) rl.drawText("God Mode", config.WINDOW_WIDTH - 150, 40, 20, .{ .r = 255, .b = 50, .g = 50, .a = 255 });
        if (show_alive_particle) {
            rl.drawText(rl.textFormat("Alive Particles: %d", .{Game.alive_particles}), config.WINDOW_WIDTH - 200, 60, 20, .{ .r = 50, .b = 155, .g = 150, .a = 255 });
        }
        Game.render();
        if (Game.show_fps) rl.drawFPS(config.WINDOW_WIDTH - 150, 10);
        if (Game.pause) pauseT.drawAtCenter();
        switch (Game.state) {
            .GAMEOVER => {
                oylT.drawAtCenter();
                restartT.drawAtCenterWight(null, 60);
                Game.updateParticle(dt);
            },
            .VICTORY => {
                wonT.drawAtCenter();
                restartT.drawAtCenterWight(null, 60);
            },
            else => {},
        }
    }
}

pub const Text = struct {
    text: [:0]const u8,
    x: f32 = 0,
    y: f32 = 0,
    size: rl.Vector2,
    fontSize: i32 = 0,
    font: rl.Font,
    color: u32,
    const Self = @This();

    pub fn init(text: [:0]const u8, fontSize: i32, color: u32, font: rl.Font) Self {
        const size = rl.measureTextEx(font, text, @as(f32, @floatFromInt(fontSize)), 1.0);
        return .{ .text = text, .fontSize = fontSize, .color = color, .font = font, .size = size };
    }
    pub fn drawAtCenter(self: Self) void {
        rl.drawText(
            self.text,
            @as(i32, (@intFromFloat((config.WINDOW_WIDTH / 2) - (self.size.x / 2)))),
            config.WINDOW_HEIGHT / 2,
            self.fontSize,
            rl.getColor(self.color),
        );
    }

    pub fn drawAtCenterWight(self: Self, x: ?i32, y: ?i32) void {
        const nx = if (x) |v| v else 0;
        const ny = if (y) |v| v else 0;
        rl.drawText(
            self.text,
            @as(i32, (@intFromFloat((config.WINDOW_WIDTH / 2) - (self.size.x / 2)))) + nx,
            (config.WINDOW_HEIGHT / 2) + ny,
            self.fontSize,
            rl.getColor(self.color),
        );
    }
};
