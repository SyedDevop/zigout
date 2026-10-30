const std = @import("std");
const math = std.math;

const object = @import("object.zig");
const Particle = @import("Particle.zig");
const config = @import("config.zig");

const Text = object.Text;
const MyColor = object.MyColor;
const Entity = object.Entity;
const StateKind = object.StateKind;

//extern fn drawReact(react: object.Rectangle, color: object.Color) void;
pub const DrawReactFn = fn (react: object.Rectangle, color: object.Color) void;
pub const RandomFloatFn = fn () f32;
pub const DrawTextFn = fn (text: []const u8, posX: i32, posY: i32, fontSize: i32, color: object.Color) void;
pub const KeyEventFn = fn (key: u8) void;
pub const InitConfig = struct {
    drawReact: *const DrawReactFn,
    //drawText: *const DrawTextFn,
    randomFloat: *const RandomFloatFn,
};

// @section:State
pub var particle_pool: [255]Particle = @splat(Particle.default);
pub var targets_pool: [config.TOTAL_ENTITY]Entity = undefined;
pub var life_pool: [config.LIVES]Entity = undefined;
pub var proj: Entity = undefined;

pub var alive_particles: usize = undefined;
pub var life: u8 = config.LIVES;
pub var emitter_pried: f32 = 5;
pub var score: u32 = 0;
pub var pause = false;
pub var show_fps = false;
pub var god_mode = false;
pub var kill_all = false;

pub var left = false;
pub var right = false;
pub var state: StateKind = .START;
pub var bar: Entity = undefined;

var drawReact: *const DrawReactFn = undefined;
//var drawText: *const DrawTextFn = undefined;
var randomFloat: *const RandomFloatFn = undefined;
// @section:State::end

pub export fn keyPressed(key: u8) void {
    switch (key) {
        'A' => {
            bar.dx -= 1;
            left = true;
        },
        'D' => {
            bar.dx += 1;
            right = true;
        },
        ' ' => {
            switch (state) {
                .PLAY => pause = !pause,
                .READY => {
                    const driction: f16 = if (left) 1 else -1;
                    proj.dx = driction;
                    state = .PLAY;
                },
                else => {},
            }
        },
        else => {},
    }
}
pub export fn keyReleased(key: u8) void {
    switch (key) {
        // 'A' => {
        //     bar.dx += 1;
        //     left = false;
        // },
        // 'D' => {
        //     bar.dx -= 1;
        //     right = false;
        // },
        else => {},
    }
}
pub fn init(init_config: InitConfig) void {
    drawReact = init_config.drawReact;
    //drawText = init_config.drawText;
    randomFloat = init_config.randomFloat;

    init_targets();
    init_bar();
    init_projectile();
}

pub fn init_targets() void {
    const red = MyColor.srgb_to_linear(.red); // ~1, 0.18, 0.18, 1
    const green = MyColor.srgb_to_linear(.green); // ~0.18, 1, 0.18, 1
    const blue = MyColor.srgb_to_linear(.blue); // ~0.18, 0.18, 1, 1
    const level: f32 = 0.5;
    for (0..config.TARGET_ROWS) |row| {
        for (0..config.TARGET_COLS) |col| {
            const t = @as(f32, @floatFromInt(row)) / config.TARGET_ROWS;
            //const c: f32 = if (t < level) 1.0 else 0.0;
            const g1 = MyColor.lerp(red, green, t / level);
            const g2 = MyColor.lerp(green, blue, (t - level) / (1 - level));
            const linear_color = if (t < level) g1 else g2;
            const color = MyColor.linear_to_srgb(linear_color);
            targets_pool[row * config.TARGET_COLS + col] = Entity{ .color = color, .react = .{
                .x = config.TARGET_GRID_X + (config.TARGET_WIDTH + config.TARGET_PADDING_X) * @as(f32, @floatFromInt(col)),
                .y = config.TARGET_GRID_Y + config.TARGET_PADDING_Y * @as(f32, @floatFromInt(row)),
                .width = config.TARGET_WIDTH,
                .height = config.TARGET_HEIGHT,
            } };
        }
    }
}

pub fn init_bar() void {
    bar = .{
        .color = .red,
        .react = .{
            .x = config.WINDOW_WIDTH / 2 - config.BAR_LEN / 2,
            .y = config.BAR_Y - config.BAR_THICKNESS / 2,
            .width = config.BAR_LEN,
            .height = config.BAR_THICKNESS,
        },
    };
}

pub fn init_projectile() void {
    const life_size = config.BAR_THICKNESS;
    for (&life_pool, 0..) |*life_, i| {
        life_.* = .{
            .dx = 1,
            .dy = 1,
            .color = .white,
            .react = .{
                .x = 10 + (life_size + 10) * @as(f32, @floatFromInt(i)),
                .y = 40,
                .width = life_size,
                .height = life_size,
            },
        };
    }
}

fn get_life() Entity {
    return life_pool[life - 1];
}

fn reset_lifes() void {
    for (life_pool[0..]) |*it| {
        it.dead = false;
    }
}
fn reset_target() void {
    for (targets_pool[0..]) |*it| {
        it.dead = false;
    }
}

pub fn reset() void {
    pause = false;
    score = 0;
    state = .READY;
    life = config.LIVES;
    left = false;
    right = false;
    init_bar();
    reset_target();
    reset_lifes();
}

fn horz_collision(dt: f32) void {
    const proj_nx: f32 = proj.react.x + proj.dx * config.PROJ_SPEED * dt;
    const proj_collided_with_bar = proj.overlaps(bar, proj_nx, null);
    if (proj_nx < 0 or proj_nx + config.PROJ_SIZE > config.WINDOW_WIDTH or proj_collided_with_bar) {
        proj.dx *= -1;
        return;
    }
    if (proj_collided_with_bar) particleBurst(bar.react, bar.color, config.PARTICLE_BURST_HIT_COUNT);
    for (targets_pool[0..]) |*it| {
        if (!it.dead and proj.overlaps(it.*, proj_nx, null)) {
            //rl.playSound(collid_sound);
            score += 1;
            it.dead = true;
            proj.dx *= -1;
            particleBurst(proj.react, it.color, config.PARTICLE_BURST_HIT_COUNT);
            return;
        }
    }
    proj.react.x = proj_nx;
}

fn vert_collision(dt: f32) void {
    const proj_ny: f32 = proj.react.y + proj.dy * config.PROJ_SPEED * dt;
    if (proj_ny < 0) {
        proj.dy *= -1;
        return;
    }
    if (proj_ny + config.PROJ_SIZE > config.WINDOW_HEIGHT) {
        if (god_mode) {
            proj.dy += 1.005;
            proj.dy *= -1;
            return;
        }
        //rl.playSound(death_sound);
        life -= 1;
        state = .START;
        return;
    }
    if (proj.overlaps(bar, null, proj_ny)) {
        if (bar.dx != 0) proj.dx = bar.dx;
        proj.dy *= -1;
        particleBurst(bar.react, bar.color, config.PARTICLE_BURST_HIT_COUNT);
        return;
    }
    for (targets_pool[0..]) |*it| {
        if (!it.dead and proj.overlaps(it.*, null, proj_ny)) {
            //rl.playSound(collid_sound);
            score += 1;
            it.dead = true;
            proj.dy *= -1;
            particleBurst(proj.react, it.color, config.PARTICLE_BURST_HIT_COUNT);
            return;
        }
    }
    proj.react.y = proj_ny;
}

fn bar_collision(dt: f32) void {
    const bar_nx: f32 = math.clamp(
        bar.react.x + bar.dx * config.BAR_SPEED * dt,
        0,
        config.WINDOW_WIDTH - config.BAR_LEN,
    );
    if (bar.overlaps(proj, bar_nx, null)) return;
    bar.react.x = bar_nx;
}

fn life_collision(dt: f32) void {
    const currProj = life_pool[life - 1];
    if (!currProj.dead) {
        life_pool[life - 1].dead = true;
        proj = get_life();
    }
    const barPos = bar.getCenter();
    const projPos = proj.getCenter();
    const dist = barPos.subtract(projPos).normalize();
    const proj_nx = proj.react.x + dist.x * (config.PROJ_SPEED * 4) * dt;
    const proj_ny = proj.react.y + dist.y * (config.PROJ_SPEED * 4) * dt;
    if (proj.overlaps(bar, proj_nx, proj_ny)) {
        state = .READY;
        particleBurst(bar.react, bar.color, config.PARTICLE_BURST_HIT_COUNT);
        return;
    }
    proj.react.x = proj_nx;
    proj.react.y = proj_ny;
    return;
}

pub fn updateParticle(dt: f32) void {
    alive_particles = 0;
    for (&particle_pool) |*par| {
        if (!par.isAlive()) continue;
        alive_particles += 1;
        par.*.position = par.*.position.add(par.*.velocity.scale(dt));
        par.*.lifetime -= dt;
    }
}

pub fn update(dt: f32) void {
    updateParticle(dt);
    if (pause) return;
    if (life <= 0) {
        state = .GAMEOVER;
        //rl.playSound(lose_sound);
        particleBurst(bar.react, bar.color, config.PARTICLE_BURST_DEATH_COUNT);
        bar.color.a = 0;
        return;
    }
    if (score >= config.TARGET_ROWS * config.TARGET_COLS) {
        state = .VICTORY;
        //rl.playSound(win_sound);
        return;
    }
    bar_collision(dt);

    switch (state) {
        .START => state = .ATTACH,
        .ATTACH => life_collision(dt),
        .READY => proj.setCenterX(bar.getCenterX()), // this anchor the projectile to bar till .PLAY state

        else => {
            if (proj.overlaps(bar, null, null)) {
                proj.react.y = config.BAR_Y - config.BAR_THICKNESS / 2 - config.PROJ_SIZE - 1.0;
                return;
            }
            horz_collision(dt);
            vert_collision(dt);
        },
    }
}

pub fn render() void {
    drawReact(bar.react, bar.color);
    drawReact(proj.react, proj.color);
    for (life_pool) |lproj| {
        if (!lproj.dead) {
            drawReact(lproj.react, lproj.color);
        }
    }
    for (targets_pool) |target| {
        if (!target.dead) {
            drawReact(target.react, target.color);
        }
    }
    for (particle_pool) |particle| {
        if (particle.isAlive()) {
            const size_mul = particle.size_multiplayer * config.PARTICLE_BASE_SIZE;
            var color = particle.color;
            color.a = @intFromFloat((particle.lifetime / config.PARTICLE_LIFETIME) * 255);
            drawReact(.{
                .x = particle.position.x,
                .y = particle.position.y,
                .width = size_mul,
                .height = size_mul,
            }, color);
        }
    }
}
pub fn killAll() void {
    for (targets_pool[0..]) |*target| {
        target.dead = true;
    }
    score = targets_pool.len;
}

fn particleBurst(rect: object.Rectangle, color: object.Color, count: u8) void {
    for (0..count) |_| {
        var pos: object.Vector2 = .zero();
        pos.x = rect.x + randomFloat() * rect.width;
        pos.y = rect.y + randomFloat() * rect.height;
        emitParticle(pos, color);
    }
}
fn emitParticle(pos: object.Vector2, color: object.Color) void {
    for (&particle_pool) |*par| {
        if (par.isAlive()) continue;
        const angle = randomFloat() * 2 * std.math.pi;
        const t = randomFloat() + 0.5;
        const angle_x = @cos(angle);
        const angle_y = @sin(angle);
        par.*.velocity = (object.Vector2{ .x = angle_x, .y = angle_y }).scale(config.PARTICLE_BASE_VELOCITY * t);
        par.*.position = pos;
        par.*.color = color;
        par.size_multiplayer = randomFloat() + 0.5;
        par.lifetime = config.PARTICLE_LIFETIME;
        return;
    }
}
