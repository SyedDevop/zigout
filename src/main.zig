const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
const rl = @import("raylib");

const overlaps = c.SDL_HasIntersection;
const FPS = 60;
const DELTA_TIME_SEC: f32 = 1.0 / @as(f32, @floatFromInt(FPS));
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const PAUSE_TEXT_FS: u8 = 64;
const PAUSE_TEXT = "Game Is Paused";
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
const TARGET_ROWS = 4;
const TARGET_COLS = 5;
const TARGET_GRID_WIDTH = (TARGET_COLS * TARGET_WIDTH + (TARGET_COLS - 1) * TARGET_PADDING_X);
const TARGET_GRID_X = WINDOW_WIDTH / 2 - TARGET_GRID_WIDTH / 2;
const TARGET_GRID_Y = 50;
const TARGET_COLOR = 0x30FF30FF;

const Target = struct {
    x: f32,
    y: f32,
    dead: bool = false,
};

const Entity = struct {
    dx: f32 = 0,
    dy: f32 = 0,
    dead: bool = false,
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

fn init_targets() [TARGET_ROWS * TARGET_COLS]Target {
    var targets: [TARGET_ROWS * TARGET_COLS]Target = undefined;
    var row: usize = 0;
    while (row < TARGET_ROWS) : (row += 1) {
        var col: usize = 0;
        while (col < TARGET_COLS) : (col += 1) {
            targets[row * TARGET_COLS + col] = Target{
                .x = TARGET_GRID_X + (TARGET_WIDTH + TARGET_PADDING_X) * @as(f32, @floatFromInt(col)),
                .y = TARGET_GRID_Y + TARGET_PADDING_Y * @as(f32, @floatFromInt(row)),
            };
        }
    }
    return targets;
}

var targets_pool = init_targets();

var tbar: Entity = .{ .react = .{ .x = WINDOW_WIDTH / 2 - BAR_LEN / 2, .y = BAR_Y - BAR_THICCNESS / 2, .width = BAR_LEN, .height = BAR_THICCNESS } };
var tproj: Entity = .{ .dx = 1, .dy = 1, .react = .{
    .x = WINDOW_WIDTH / 2 - PROJ_SIZE / 2,
    .y = BAR_Y - BAR_THICCNESS / 2 - PROJ_SIZE,
    .width = PROJ_SIZE,
    .height = PROJ_SIZE,
} };
var quit = false;
var pause = false;
var started = false;
var show_fps = false;

// TODO: death
// TODO: score
// TODO: victory
// TODO: Sound on collision's

fn make_rect(x: f32, y: f32, w: f32, h: f32) c.SDL_Rect {
    return c.SDL_Rect{
        .x = @as(i32, @intFromFloat(x)),
        .y = @as(i32, @intFromFloat(y)),
        .w = @as(i32, @intFromFloat(w)),
        .h = @as(i32, @intFromFloat(h)),
    };
}

fn set_color(renderer: *c.SDL_Renderer, color: u32) void {
    const r: u8 = @truncate((color >> (0 * 8)) & 0xFF);
    const g: u8 = @truncate((color >> (1 * 8)) & 0xFF);
    const b: u8 = @truncate((color >> (2 * 8)) & 0xFF);
    const a: u8 = @truncate((color >> (3 * 8)) & 0xFF);
    _ = c.SDL_SetRenderDrawColor(renderer, r, g, b, a);
}

fn target_rect(target: Target) c.SDL_Rect {
    return make_rect(target.x, target.y, TARGET_WIDTH, TARGET_HEIGHT);
}

fn proj_rect(x: f32, y: f32) c.SDL_Rect {
    return make_rect(x, y, PROJ_SIZE, PROJ_SIZE);
}

fn bar_rect(x: f32) c.SDL_Rect {
    return make_rect(x, BAR_Y - BAR_THICCNESS / 2, BAR_LEN, BAR_THICCNESS);
}

fn horz_collision(dt: f32) void {
    const proj_nx: f32 = tproj.react.x + tproj.dx * PROJ_SPEED * dt;

    if (proj_nx < 0 or proj_nx + PROJ_SIZE > WINDOW_WIDTH or tproj.overlaps(tbar, proj_nx, null)) {
        tproj.dx *= -1;
        return;
    }
    for (targets_pool[0..]) |*it| {
        if (!it.dead and overlaps(&proj_rect(proj_nx, tproj.react.y), &target_rect(it.*)) != 0) {
            it.dead = true;
            tproj.dx *= -1;
            return;
        }
    }
    tproj.react.x = proj_nx;
}

fn vert_collision(dt: f32) void {
    const proj_ny: f32 = tproj.react.y + tproj.dy * PROJ_SPEED * dt;
    if (proj_ny < 0 or proj_ny + PROJ_SIZE > WINDOW_HEIGHT) {
        tproj.dy *= -1;
        return;
    }
    if (tproj.overlaps(tbar, null, proj_ny)) {
        if (tbar.dx != 0) tproj.dx = tbar.dx;
        tproj.dy *= -1;
        return;
    }
    for (targets_pool[0..]) |*it| {
        if (!it.dead and overlaps(&proj_rect(tproj.react.x, proj_ny), &target_rect(it.*)) != 0) {
            it.dead = true;
            tproj.dy *= -1;
            return;
        }
    }
    tproj.react.y = proj_ny;
}

fn bar_collision(dt: f32) void {
    const bar_nx: f32 = math.clamp(
        tbar.react.x + tbar.dx * BAR_SPEED * dt,
        0,
        WINDOW_WIDTH - BAR_LEN,
    );
    if (tproj.overlaps(tbar, null, null)) {
        return;
    }
    tbar.react.x = bar_nx;
}

fn update(dt: f32) void {
    if (!pause and started) {
        if (tproj.overlaps(tbar, null, null)) {
            tproj.react.y = BAR_Y - BAR_THICCNESS / 2 - PROJ_SIZE - 1.0;
            return;
        }
        bar_collision(dt);
        horz_collision(dt);
        vert_collision(dt);
    }
}

fn render() void {
    drawBar(tbar.react.x);
    drawProj(tproj.react.x, tproj.react.y);
    for (targets_pool) |target| {
        if (!target.dead) {
            drawTarget(&target);
        }
    }
}

// fn sides(object: React) React {
//     return .{ .x = object.x, .y = object.y, .w = object.x + object.w, .h = object.y + object.h };
// }
// fn overlapsss(a: React, b: React) bool {
//     const ra = sides(a); // A Walls
//     const rb = sides(b); // B Walls
//     return !(ra.w < rb.x or rb.w < ra.x or ra.h < rb.y or rb.h < ra.y);
// }
fn drawBar(x: f32) void {
    rl.drawRectangle(@as(i32, @intFromFloat(x)), BAR_Y - BAR_THICCNESS / 2, BAR_LEN, BAR_THICCNESS, rl.getColor(BAR_COLOR));
}
fn drawProj(x: f32, y: f32) void {
    const nx = @as(i32, @intFromFloat(x));
    const ny = @as(i32, @intFromFloat(y));
    rl.drawRectangle(nx, ny, PROJ_SIZE, PROJ_SIZE, rl.getColor(PROJ_COLOR));
}
fn drawTarget(target: *const Target) void {
    const nx = @as(i32, @intFromFloat(target.x));
    const ny = @as(i32, @intFromFloat(target.y));
    rl.drawRectangle(nx, ny, TARGET_WIDTH, TARGET_HEIGHT, rl.getColor(TARGET_COLOR));
}
pub fn main() !void {
    const isSdl = false;
    if (!isSdl) {
        rl.initWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "[Z]brake");
        defer rl.closeWindow(); // Close window and OpenGL context
        rl.setTargetFPS(FPS); // Set our game to run at 60 frames-per-second
        //
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key
            const dt: f32 = rl.getFrameTime();
            tbar.dx = 0;
            if (rl.isKeyDown(.a) or rl.isKeyDown(.left)) {
                tbar.dx -= 1;
                if (!started) {
                    started = true;
                    tproj.dx = 1;
                }
            }
            if (rl.isKeyDown(.d) or rl.isKeyDown(.right)) {
                tbar.dx += 1;
                if (!started) {
                    started = true;
                    tproj.dx = -1;
                }
            }
            if (rl.isKeyPressed(.f4)) show_fps = !show_fps;
            if (rl.isKeyPressed(.space)) pause = !pause;
            update(dt);
            // Draw
            //----------------------------------------------------------------------------------
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(rl.getColor(BACKGROUND_COLOR));
            render();
            if (show_fps) rl.drawFPS(10, 10);
            if (pause) rl.drawText(
                PAUSE_TEXT,
                WINDOW_WIDTH / 2 - (@as(f32, PAUSE_TEXT.len) * PAUSE_TEXT_FS) / 4.0,
                WINDOW_HEIGHT / 2,
                PAUSE_TEXT_FS,
                rl.getColor(PROJ_COLOR),
            );
        }
    } else {

        // ------------------ SDL ---------------------------
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
            c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
            return error.SDLInitializationFailed;
        }
        defer c.SDL_Quit();

        const window = c.SDL_CreateWindow("Zigout", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, 0) orelse {
            c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
            return error.SDLInitializationFailed;
        };
        defer c.SDL_DestroyWindow(window);

        const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
            c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
            return error.SDLInitializationFailed;
        };
        defer c.SDL_DestroyRenderer(renderer);

        const keyboard = c.SDL_GetKeyboardState(null);

        while (!quit) {
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event) != 0) {
                switch (event.type) {
                    c.SDL_QUIT => {
                        quit = true;
                    },
                    c.SDL_KEYDOWN => switch (event.key.keysym.sym) {
                        ' ' => {
                            pause = !pause;
                        },
                        else => {},
                    },
                    else => {},
                }
            }

            tbar.dx = 0;
            if (keyboard[c.SDL_SCANCODE_A] != 0) {
                tbar.dx += -1;
                if (!started) {
                    started = true;
                    tproj.dx = -1;
                }
            }
            if (keyboard[c.SDL_SCANCODE_D] != 0) {
                tbar.dx += 1;
                if (!started) {
                    started = true;
                    tproj.dx = 1;
                }
            }

            update(DELTA_TIME_SEC);

            set_color(renderer, BACKGROUND_COLOR);
            _ = c.SDL_RenderClear(renderer);

            render(renderer);

            c.SDL_RenderPresent(renderer);

            c.SDL_Delay(1000 / FPS);
        }
    }
}
