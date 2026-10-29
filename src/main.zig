const std = @import("std");
const math = std.math;
const rl = @import("raylib");
const object = @import("object.zig");
const Particle = @import("Particle.zig");
const config = @import("config.zig");
const Game = @import("Game.zig");
const Text = object.Text;
const MyColor = object.MyColor;
const Entity = object.Entity;
const StateKind = object.StateKind;

pub fn main(init: std.process.Init) !void {
    rl.initWindow(config.WINDOW_WIDTH, config.WINDOW_HEIGHT, "[Z]brake");
    // rl.toggleBorderlessWindowed();
    rl.initAudioDevice();
    try Game.init(init.io);

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
        if (rl.isKeyPressed(.f3)) Game.show_alive_particle = !Game.show_alive_particle;
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
