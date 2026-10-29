const std = @import("std");
const math = std.math;
const rl = @import("raylib");

const object = @import("object.zig");
const Particle = @import("Particle.zig");
const config = @import("config.zig");

const Text = object.Text;
const MyColor = object.MyColor;
const Entity = object.Entity;
const StateKind = object.StateKind;

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
pub var show_alive_particle = false;
pub var show_fps = false;
pub var god_mode = false;
pub var kill_all = false;

pub var left = false;
pub var right = false;
pub var state: StateKind = .START;
pub var bar: Entity = undefined;

pub var collid_sound: rl.Sound = undefined;
pub var death_sound: rl.Sound = undefined;
pub var lose_sound: rl.Sound = undefined;
pub var win_sound: rl.Sound = undefined;
// @section:State::end

pub fn init(io: std.Io) !void {
    {
        collid_sound = try rl.loadSound("assets/sounds/collide.wav");
        death_sound = try rl.loadSound("assets/sounds/die.wav");
        lose_sound = try rl.loadSound("assets/sounds/lose.wav");
        win_sound = try rl.loadSound("assets/sounds/win.wav");
    }
    {
        var seed: u64 = undefined;
        io.random(std.mem.asBytes(&seed));
        var prng = std.Random.DefaultPrng.init(seed);
        rand = prng.random();
    }

    init_targets();
    init_bar();
    init_projectile();
}

pub fn init_targets() void {
    const red = MyColor.srgb_to_linear(config.RED); // ~1, 0.18, 0.18, 1
    const green = MyColor.srgb_to_linear(config.GREEN); // ~0.18, 1, 0.18, 1
    const blue = MyColor.srgb_to_linear(config.BLUE); // ~0.18, 0.18, 1, 1
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
        .color = config.RED,
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
            rl.playSound(collid_sound);
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
        rl.playSound(death_sound);
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
            rl.playSound(collid_sound);
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
        rl.playSound(lose_sound);
        particleBurst(bar.react, bar.color, config.PARTICLE_BURST_DEATH_COUNT);
        bar.color.a = 0;
        return;
    }
    if (score >= config.TARGET_ROWS * config.TARGET_COLS) {
        state = .VICTORY;
        rl.playSound(win_sound);
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
    rl.drawText(rl.textFormat("Score: %d", .{score}), 10, 10, 20, rl.getColor(config.PROJ_COLOR));
    if (god_mode) rl.drawText("God Mode", config.WINDOW_WIDTH - 150, 40, 20, .{ .r = 255, .b = 50, .g = 50, .a = 255 });
    if (show_alive_particle) {
        rl.drawText(rl.textFormat("Alive Particles: %d", .{alive_particles}), config.WINDOW_WIDTH - 200, 60, 20, .{ .r = 50, .b = 155, .g = 150, .a = 255 });
    }
    drawEntity(&bar);
    drawEntity(&proj);
    for (life_pool) |lproj| {
        if (!lproj.dead) {
            drawEntity(&lproj);
        }
    }
    for (targets_pool) |target| {
        if (!target.dead) {
            drawEntity(&target);
        }
    }
    for (particle_pool) |particle| {
        if (particle.isAlive()) {
            const size_mul = particle.size_multiplayer * config.PARTICLE_BASE_SIZE;
            var color = particle.color;
            color.a = @intFromFloat((particle.lifetime / config.PARTICLE_LIFETIME) * 255);
            rl.drawRectangleV(particle.position, .{ .x = size_mul, .y = size_mul }, color);
        }
    }
}
pub fn killAll() void {
    for (targets_pool[0..]) |*target| {
        target.dead = true;
    }
    score = targets_pool.len;
}
fn drawEntity(en: *const Entity) void {
    rl.drawRectangleRec(en.react, en.color);
}

fn particleBurst(rect: rl.Rectangle, color: rl.Color, count: u8) void {
    for (0..count) |_| {
        var pos: rl.Vector2 = .zero();
        pos.x = rect.x + rand.float(f32) * rect.width;
        pos.y = rect.y + rand.float(f32) * rect.height;
        emitParticle(pos, color);
    }
}
fn emitParticle(pos: rl.Vector2, color: rl.Color) void {
    for (&particle_pool) |*par| {
        if (par.isAlive()) continue;
        const angle = rand.float(f32) * 2 * std.math.pi;
        const t = rand.float(f32) + 0.5;
        const angle_x = @cos(angle);
        const angle_y = @sin(angle);
        par.*.velocity = (rl.Vector2{ .x = angle_x, .y = angle_y }).scale(config.PARTICLE_BASE_VELOCITY * t);
        par.*.position = pos;
        par.*.color = color;
        par.size_multiplayer = rand.float(f32) + 0.5;
        par.lifetime = config.PARTICLE_LIFETIME;
        return;
    }
}

var rand: std.Random = undefined;
