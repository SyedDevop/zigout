const std = @import("std");
const math = std.math;
const rl = @import("raylib");
const object = @import("object.zig");

const Text = object.Text;
const MyColor = object.MyColor;
const Entity = object.Entity;
const StateKind = object.StateKind;

const FPS = 60;
const DELTA_TIME_SEC: f32 = 1.0 / @as(f32, @floatFromInt(FPS));
const WINDOW_WIDTH = object.WINDOW_WIDTH;
const WINDOW_HEIGHT = object.WINDOW_HEIGHT;
const PAUSE_TEXT_FS: u8 = 64;
const BACKGROUND_COLOR = 0x181818FF;
const PROJ_SIZE: f32 = 25 * 0.80;
const PROJ_SPEED: f32 = 350;
const PROJ_COLOR = 0xFFFFFFFF;
const ANGLE_FACTOR: f32 = 0.45;
const BAR_LEN: f32 = 100;
const BAR_THICCNESS: f32 = PROJ_SIZE;
const BAR_Y: f32 = WINDOW_HEIGHT - PROJ_SIZE - 50;
const BAR_SPEED: f32 = PROJ_SPEED * 1.5;
const BAR_COLOR = 0x3030FFFF;
const TARGET_WIDTH = BAR_LEN;
const TARGET_HEIGHT = PROJ_SIZE;
const TARGET_PADDING_X = 20;
const TARGET_PADDING_Y = 50;
const TARGET_ROWS = 3;
const TARGET_COLS = 4;
const TARGET_GRID_WIDTH = (TARGET_COLS * TARGET_WIDTH + (TARGET_COLS - 1) * TARGET_PADDING_X);
const TARGET_GRID_X = WINDOW_WIDTH / 2 - TARGET_GRID_WIDTH / 2;
const TARGET_GRID_Y = 50;
const TARGET_COLOR = 0x30FF30FF;

// Constant text to display
const PAUSE_T = "Game Is Paused";
const RESTART_T = "Press r to restart";
const OYL_T = "Game Over You Lose";
const WON_T = "Game Won";

fn init_targets() [TARGET_ROWS * TARGET_COLS]Entity {
    var targets: [TARGET_ROWS * TARGET_COLS]Entity = undefined;

    const red = MyColor.srgb_to_linear(.{ .r = 255, .g = 46, .b = 46, .a = 255 }); // ~1, 0.18, 0.18, 1
    const green = MyColor.srgb_to_linear(.{ .r = 46, .g = 255, .b = 46, .a = 255 }); // ~0.18, 1, 0.18, 1
    const blue = MyColor.srgb_to_linear(.{ .r = 46, .g = 46, .b = 255, .a = 255 }); // ~0.18, 0.18, 1, 1
    const level = 0.5;
    for (0..TARGET_ROWS) |row| {
        for (0..TARGET_COLS) |col| {
            const t = @as(f32, @floatFromInt(row)) / TARGET_ROWS;
            const c = if (t < level) 1.0 else 0.0;
            const g1 = MyColor.lerp(red, green, t / level);
            const g2 = MyColor.lerp(green, blue, (t - level) / (1 - level));
            const color = MyColor.linear_to_srgb(.{
                .r = c * g1.r + (1 - c) * g2.r,
                .g = c * g1.g + (1 - c) * g2.g,
                .b = c * g1.b + (1 - c) * g2.b,
                .a = 1.0,
            });
            targets[row * TARGET_COLS + col] = Entity{ .color = color, .react = .{
                .x = TARGET_GRID_X + (TARGET_WIDTH + TARGET_PADDING_X) * @as(f32, @floatFromInt(col)),
                .y = TARGET_GRID_Y + TARGET_PADDING_Y * @as(f32, @floatFromInt(row)),
                .width = TARGET_WIDTH,
                .height = TARGET_HEIGHT,
            } };
        }
    }
    return targets;
}
fn init_bar() Entity {
    return .{ .color = .{ .r = 255, .g = 50, .b = 50, .a = 255 }, .react = .{
        .x = WINDOW_WIDTH / 2 - BAR_LEN / 2,
        .y = BAR_Y - BAR_THICCNESS / 2,
        .width = BAR_LEN,
        .height = BAR_THICCNESS,
    } };
}
fn init_proj() Entity {
    return .{ .dx = 1, .dy = 1, .color = .{ .r = 255, .g = 255, .b = 255, .a = 255 }, .react = .{
        .x = WINDOW_WIDTH / 2 - PROJ_SIZE / 2,
        .y = BAR_Y - BAR_THICCNESS / 2 - PROJ_SIZE,
        .width = PROJ_SIZE,
        .height = PROJ_SIZE,
    } };
}
fn reset_target() void {
    for (targets_pool[0..]) |*it| {
        it.dead = false;
    }
}
var targets_pool = init_targets();
var bar: Entity = init_bar();
var proj: Entity = init_proj();
var collid_sound: rl.Sound = undefined;
var death_sound: rl.Sound = undefined;
var score: u32 = 0;
var life: u8 = 4;
var state: StateKind = .READY;
var pause = false;
var show_fps = false;
var left = false;
var right = false;

// TODO: game won  sound and message.
// TODO: game lose sound and message.
// TODO: new color pallet for target.

fn reset() void {
    pause = false;
    score = 0;
    state = .READY;
    life = 4;
    left = false;
    right = false;
    bar = init_bar();
    proj = init_proj();
    reset_target();
}

fn horz_collision(dt: f32) void {
    const proj_nx: f32 = proj.react.x + proj.dx * PROJ_SPEED * dt;
    if (proj_nx < 0 or proj_nx + PROJ_SIZE > WINDOW_WIDTH or proj.overlaps(bar, proj_nx, null)) {
        proj.dx *= -1;
        return;
    }
    for (targets_pool[0..]) |*it| {
        if (!it.dead and proj.overlaps(it.*, proj_nx, null)) {
            rl.playSound(collid_sound);
            score += 1;
            it.dead = true;
            proj.dx *= -1;
            return;
        }
    }
    proj.react.x = proj_nx;
}

fn vert_collision(dt: f32) void {
    const proj_ny: f32 = proj.react.y + proj.dy * PROJ_SPEED * dt;
    if (proj_ny < 0) {
        proj.dy *= -1;
        return;
    }
    if (proj_ny + PROJ_SIZE > WINDOW_HEIGHT) {
        rl.playSound(death_sound);
        life -|= 1;
        proj.react.y = BAR_Y - BAR_THICCNESS / 2 - PROJ_SIZE;
        proj.react.x = bar.react.x + BAR_LEN / 2 - PROJ_SIZE / 2;
        state = .READY;
        return;
    }
    if (proj.overlaps(bar, null, proj_ny)) {
        if (bar.dx != 0) proj.dx = bar.dx;
        proj.dy *= -1;
        return;
    }
    for (targets_pool[0..]) |*it| {
        if (!it.dead and proj.overlaps(it.*, null, proj_ny)) {
            rl.playSound(collid_sound);
            score += 1;
            it.dead = true;
            proj.dy *= -1;
            return;
        }
    }
    proj.react.y = proj_ny;
}

fn bar_collision(dt: f32) void {
    const bar_nx: f32 = math.clamp(
        bar.react.x + bar.dx * BAR_SPEED * dt,
        0,
        WINDOW_WIDTH - BAR_LEN,
    );
    if (bar.overlaps(proj, bar_nx, null)) return;
    bar.react.x = bar_nx;
}

fn update(dt: f32) void {
    if (pause) return;
    if (life <= 0) {
        state = .GAMEOVER;
        return;
    }
    if (score >= TARGET_ROWS * TARGET_COLS) {
        state = .VICTORY;
        return;
    }
    if (state == .READY) {
        bar_collision(dt);
        proj.setCenterX(bar.getCenterX());
        return;
    }
    if (proj.overlaps(bar, null, null)) {
        proj.react.y = BAR_Y - BAR_THICCNESS / 2 - PROJ_SIZE - 1.0;
        return;
    }
    bar_collision(dt);
    horz_collision(dt);
    vert_collision(dt);
}

fn render() void {
    rl.drawText(rl.textFormat("Score: %d", .{score}), WINDOW_WIDTH - 150, 10, 20, rl.getColor(PROJ_COLOR));
    rl.drawText(rl.textFormat("Lives: %d", .{life}), WINDOW_WIDTH - 150, 50, 20, rl.getColor(PROJ_COLOR));
    drawEntity(&bar);
    drawEntity(&proj);
    for (targets_pool) |target| {
        if (!target.dead) {
            drawEntity(&target);
        }
    }
}

fn drawEntity(en: *const Entity) void {
    rl.drawRectangleRec(en.react, en.color);
}
pub fn main() !void {
    rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "[Z]brake");
    // rl.toggleBorderlessWindowed();
    rl.initAudioDevice();
    collid_sound = try rl.loadSound("assets/sounds/collide.wav");
    death_sound = try rl.loadSound("assets/sounds/lose.wav");
    defer rl.closeWindow(); // Close window and OpenGL context
    rl.setTargetFPS(FPS); // Set our game to run at 60 frames-per-second
    const dfont = try rl.getFontDefault();
    const pauseT = Text.init(PAUSE_T, 64, 0xFFFFFFFF, dfont);
    const restartT = Text.init(RESTART_T, 40, 0xFFFFFFFF, dfont);
    const oylT = Text.init(OYL_T, 64, 0xFFFFFFFF, dfont);
    const wonT = Text.init(WON_T, 64, 0xFFFFFFFF, dfont);

    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        const dt: f32 = rl.getFrameTime();
        bar.dx = 0;
        if (rl.isKeyDown(.a) or rl.isKeyDown(.left)) {
            bar.dx -= 1;
            left = true;
        }
        if (rl.isKeyDown(.d) or rl.isKeyDown(.right)) {
            bar.dx += 1;
            right = true;
        }
        if (rl.isKeyPressed(.f4)) show_fps = !show_fps;
        if (rl.isKeyPressed(.space)) {
            switch (state) {
                .PLAY => pause = !pause,
                .READY => {
                    const driction: f16 = if (left) 1 else -1;
                    proj.dx = driction;
                    state = .PLAY;
                },
                else => {},
            }
        }
        switch (state) {
            .PLAY, .READY => update(dt),
            .GAMEOVER, .VICTORY => if (rl.isKeyPressed(.r)) {
                reset();
                state = .RESTART;
            },
            .RESTART => state = .READY,
            else => {},
        }
        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.getColor(BACKGROUND_COLOR));
        render();
        if (show_fps) rl.drawFPS(10, 10);
        if (pause) pauseT.drawAtCenter();
        switch (state) {
            .GAMEOVER => {
                oylT.drawAtCenter();
                restartT.drawAtCenterWight(null, 60);
            },
            .VICTORY => {
                wonT.drawAtCenter();
                restartT.drawAtCenterWight(null, 60);
            },
            else => {},
        }
    }
}
