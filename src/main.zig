const std = @import("std");
const math = std.math;
const rl = @import("raylib");
const ru = @import("raygui");

const FPS = 60;
const DELTA_TIME_SEC: f32 = 1.0 / @as(f32, @floatFromInt(FPS));
const WINDOW_WIDTH = 1600;
const WINDOW_HEIGHT = 900;
const PAUSE_TEXT_FS: u8 = 64;
const BACKGROUND_COLOR = 0x181818FF;
const PROJ_SIZE: f32 = 25 * 0.80;
const PROJ_SPEED: f32 = 350;
const PROJ_COLOR = 0xFFFFFFFF;
const BAR_LEN: f32 = 100;
const BAR_THICCNESS: f32 = PROJ_SIZE;
const BAR_Y: f32 = WINDOW_HEIGHT - PROJ_SIZE - 50;
const BAR_SPEED: f32 = PROJ_SPEED * 1.5;
const BAR_COLOR = 0x3030FFFF;
const TARGET_WIDTH = BAR_LEN;
const TARGET_HEIGHT = PROJ_SIZE;
const TARGET_PADDING_X = 20;
const TARGET_PADDING_Y = 50;
const TARGET_ROWS = 9;
const TARGET_COLS = 10;
const TARGET_GRID_WIDTH = (TARGET_COLS * TARGET_WIDTH + (TARGET_COLS - 1) * TARGET_PADDING_X);
const TARGET_GRID_X = WINDOW_WIDTH / 2 - TARGET_GRID_WIDTH / 2;
const TARGET_GRID_Y = 50;
const TARGET_COLOR = 0x30FF30FF;

// Constant text to display
const PAUSE_T = "Game Is Paused";
const RESTART_T = "Press r to restart";
const OYL_T = "Game Over You Lose";
const WON_T = "Game Won";

const Text = struct {
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
            @as(i32, (@intFromFloat((WINDOW_WIDTH / 2) - (self.size.x / 2)))),
            WINDOW_HEIGHT / 2,
            self.fontSize,
            rl.getColor(self.color),
        );
    }

    pub fn drawAtCenterWight(self: Self, x: ?i32, y: ?i32) void {
        const nx = if (x) |v| v else 0;
        const ny = if (y) |v| v else 0;
        rl.drawText(
            self.text,
            @as(i32, (@intFromFloat((WINDOW_WIDTH / 2) - (self.size.x / 2)))) + nx,
            (WINDOW_HEIGHT / 2) + ny,
            self.fontSize,
            rl.getColor(self.color),
        );
    }
};
const MyColor = struct { r: f32, g: f32, b: f32, a: f32 };
const Entity = struct {
    dx: f32 = 0,
    dy: f32 = 0,
    dead: bool = false,
    color: rl.Color,
    react: rl.Rectangle,
    const Self = @This();

    /// Checks if this entity's rectangle overlaps with another entity's rectangle.
    /// Optionally, `newX` and `newY` can be used to temporarily set the `x` and `y`
    /// positions of self entity for the collision check.
    ///
    /// - `self`: The current entity.
    /// - `otherEntity`: The entity to check against.
    /// - `newX`: (Optional) Temporary `x` position for self entity.
    /// - `newY`: (Optional) Temporary `y` position for self entity.
    /// - Returns `true` if the rectangles overlap, otherwise `false`.
    pub fn overlaps(self: Self, otherEntity: Entity, newX: ?f32, newY: ?f32) bool {
        var updatedRect = self.react;
        if (newY) |y| updatedRect.y = y;
        if (newX) |x| updatedRect.x = x;
        return rl.checkCollisionRecs(updatedRect, otherEntity.react);
    }
};
fn srgb_to_linear(color: rl.Color) MyColor {
    const gamma = 2.2;
    return .{
        .r = std.math.pow(f32, @as(f32, @floatFromInt(color.r)) / 255.0, gamma),
        .g = std.math.pow(f32, @as(f32, @floatFromInt(color.g)) / 255.0, gamma),
        .b = std.math.pow(f32, @as(f32, @floatFromInt(color.b)) / 255.0, gamma),
        .a = @as(f32, @floatFromInt(color.a)) / 255.0,
    };
}

fn linear_to_srgb(color: MyColor) rl.Color {
    const inv_gamma = 1.0 / 2.2;
    return .{
        .r = @intFromFloat(std.math.pow(f32, color.r, inv_gamma) * 255.0),
        .g = @intFromFloat(std.math.pow(f32, color.g, inv_gamma) * 255.0),
        .b = @intFromFloat(std.math.pow(f32, color.b, inv_gamma) * 255.0),
        .a = @intFromFloat(color.a * 255.0),
    };
}

fn lerp(a: MyColor, b: MyColor, t: f32) MyColor {
    return .{
        .r = a.r + (b.r - a.r) * t,
        .g = a.g + (b.g - a.g) * t,
        .b = a.b + (b.b - a.b) * t,
        .a = a.a + (b.a - a.a) * t,
    };
}
fn init_targets() [TARGET_ROWS * TARGET_COLS]Entity {
    var targets: [TARGET_ROWS * TARGET_COLS]Entity = undefined;

    const red = srgb_to_linear(.{ .r = 255, .g = 46, .b = 46, .a = 255 }); // ~1, 0.18, 0.18, 1
    const green = srgb_to_linear(.{ .r = 46, .g = 255, .b = 46, .a = 255 }); // ~0.18, 1, 0.18, 1
    const blue = srgb_to_linear(.{ .r = 46, .g = 46, .b = 255, .a = 255 }); // ~0.18, 0.18, 1, 1
    const level = 0.5;

    for (0..TARGET_ROWS) |row| {
        for (0..TARGET_COLS) |col| {
            const t = @as(f32, @floatFromInt(row)) / TARGET_ROWS;
            const c = if (t < level) 1.0 else 0.0;
            const g1 = lerp(red, green, t / level);
            const g2 = lerp(green, blue, (t - level) / (1 - level));
            const color = linear_to_srgb(.{
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
var live: u8 = 4;
var pause = false;
var started = false;
var show_fps = false;

// TODO: game won  sound and message.
// TODO: game lose sound and message.
// TODO: new color pallet for target.

fn reset() void {
    pause = false;
    started = false;
    score = 0;
    live = 4;
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
        live -|= 1;
        proj.react.y = BAR_Y - BAR_THICCNESS / 2 - PROJ_SIZE;
        proj.react.x = bar.react.x + BAR_LEN / 2 - PROJ_SIZE / 2;
        started = false;
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
    if (proj.overlaps(bar, null, null)) {
        return;
    }
    bar.react.x = bar_nx;
}

fn update(dt: f32) void {
    if (!pause and started) {
        if (proj.overlaps(bar, null, null)) {
            proj.react.y = BAR_Y - BAR_THICCNESS / 2 - PROJ_SIZE - 1.0;
            return;
        }
        bar_collision(dt);
        horz_collision(dt);
        vert_collision(dt);
    }
}

fn render() void {
    rl.drawText(rl.textFormat("Score: %d", .{score}), WINDOW_WIDTH - 150, 10, 20, rl.getColor(PROJ_COLOR));
    rl.drawText(rl.textFormat("Lives: %d", .{live}), WINDOW_WIDTH - 150, 50, 20, rl.getColor(PROJ_COLOR));
    drawEntity(&bar);
    drawEntity(&proj);
    for (targets_pool) |target| {
        if (!target.dead) {
            drawEntity(&target);
        }
    }
}

fn drawEntity(en: *const Entity) void {
    const nx = @as(i32, @intFromFloat(en.react.x));
    const ny = @as(i32, @intFromFloat(en.react.y));
    const nw = @as(i32, @intFromFloat(en.react.width));
    const nh = @as(i32, @intFromFloat(en.react.height));
    rl.drawRectangle(nx, ny, nw, nh, en.color);
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
            if (!started) {
                started = true;
                proj.dx = 1;
            }
        }
        if (rl.isKeyDown(.d) or rl.isKeyDown(.right)) {
            bar.dx += 1;
            if (!started) {
                started = true;
                proj.dx = -1;
            }
        }
        if (rl.isKeyPressed(.f4)) show_fps = !show_fps;
        if (rl.isKeyPressed(.space)) pause = !pause;
        if (((score >= TARGET_ROWS * TARGET_COLS) or live <= 0) and rl.isKeyPressed(.r)) reset();
        if (!(score >= TARGET_ROWS * TARGET_COLS)) update(dt);
        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.getColor(BACKGROUND_COLOR));
        render();
        if (show_fps) rl.drawFPS(10, 10);
        if (pause) pauseT.drawAtCenter();
        if (live <= 0) {
            started = false;
            oylT.drawAtCenter();
            restartT.drawAtCenterWight(null, 60);
        }
        if (score >= TARGET_ROWS * TARGET_COLS) {
            started = false;
            wonT.drawAtCenter();
            restartT.drawAtCenterWight(null, 60);
        }
    }
}
