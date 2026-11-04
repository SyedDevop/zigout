const std = @import("std");
const math = std.math;

const object = @import("object.zig");
const Particle = @import("Particle.zig");
const config = @import("config.zig");

const Text = object.Text;
const MyColor = object.MyColor;
const Entity = object.Entity;
const StateKind = object.StateKind;

const Vector2 = object.Vector2;
const Rectangle = object.Rectangle;

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
pub var life: u8 = config.LIVES;

pub var proj: Entity = undefined;
pub var alive_particles: usize = undefined;
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
    std.log.debug("Got this keyCode: {d} key: `{c}`", .{ key, key });
    switch (key) {
        'A', 'a', 37 => {
            left = true;
            if (state == .START) state = .ATTACH;
        },
        'D', 'd', 38 => {
            right = true;
            if (state == .START) state = .ATTACH;
        },
        ' ' => {
            switch (state) {
                .PLAY => pause = !pause,
                .READY => {
                    // const driction: f16 = if (left) 1 else -1;
                    // proj.velocity.x = driction;
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
        37, 'A', 'a' => {
            left = false;
        },
        38, 'D', 'd' => {
            right = false;
        },
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
            targets_pool[row * config.TARGET_COLS + col] = Entity{
                .color = color,
                .position = .{
                    .x = config.TARGET_GRID_X + (config.TARGET_WIDTH + config.TARGET_PADDING_X) * @as(f32, @floatFromInt(col)),
                    .y = config.TARGET_GRID_Y + config.TARGET_PADDING_Y * @as(f32, @floatFromInt(row)),
                },
                .size = .{
                    .x = config.TARGET_WIDTH,
                    .y = config.TARGET_HEIGHT,
                },
            };
        }
    }
}

pub fn init_bar() void {
    bar = .{
        .color = .red,
        .position = .{
            .x = config.WINDOW_WIDTH / 2 - config.BAR_LEN / 2,
            .y = config.BAR_Y - config.BAR_THICKNESS / 2,
        },
        .size = .{
            .x = config.BAR_LEN,
            .y = config.BAR_THICKNESS,
        },
    };
}

//TODO: It will be cool when game is restated. Rise from the fallen position.
pub fn init_projectile() void {
    const life_size = config.BAR_THICKNESS;
    for (&life_pool, 0..) |*life_, i| {
        life_.* = .{
            .velocity = .one(),
            .color = .white,
            .position = .{
                .x = 10 + (life_size + 10) * @as(f32, @floatFromInt(i)),
                .y = 40,
            },
            .size = .{
                .x = life_size,
                .y = life_size,
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

pub const Collision = enum(u32) {
    no = 0,
    border_left,
    border_right,
    border_top,
    border_bottom,
    bar,
    target,
    _,

    pub fn add(collision: Collision, value: u32) Collision {
        const ci = @backingInt(collision);
        return @fromBackingInt(@intCast(ci + value));
    }
};
fn horz_collision2(position: *Vector2, velocity: *Vector2, size: Vector2, dt: f32) Collision {
    const nx = position.x + velocity.x * dt;
    if (nx < 0) {
        velocity.x *= -1;
        return .border_left;
    }

    if (nx + size.x > config.WINDOW_WIDTH) {
        velocity.x *= -1;
        return .border_right;
    }
    const new_r = Rectangle.makeV(.{ .x = nx, .y = position.y }, size);
    if (new_r.overlaps(bar.rect())) {
        velocity.x *= -1;
        return .bar;
    }
    for (&targets_pool, 0..) |*it, i| {
        if (!it.dead and new_r.overlaps(it.rect())) {
            velocity.x *= -1;
            return Collision.target.add(@intCast(i + 1));
        }
    }
    position.x = nx;
    return .no;
}

fn vert_collision2(position: *Vector2, velocity: *Vector2, size: Vector2, dt: f32) Collision {
    const ny = position.y + velocity.y * dt;
    if (ny < 0) {
        position.y *= -1;
        return .border_top;
    }
    if (ny + size.x > config.WINDOW_HEIGHT) {
        position.y *= -1;
        return .border_bottom;
    }
    const new_r = Rectangle.makeV(.{ .x = position.x, .y = ny }, size);
    if (new_r.overlaps(bar.rect())) {
        velocity.y *= -1;
        return .bar;
    }

    for (&targets_pool, 0..) |*it, i| {
        if (!it.dead and new_r.overlaps(it.rect())) {
            velocity.y *= -1;
            return Collision.target.add(@intCast(i + 1));
        }
    }
    position.y = ny;
    return .no;
}

fn horz_collision(dt: f32) void {
    const proj_nx: f32 = proj.position.x + proj.velocity.x * config.PROJ_SPEED * dt;
    const proj_collided_with_bar = proj.overlaps(bar, proj_nx, null);
    if (proj_nx < 0 or proj_nx + config.PROJ_SIZE > config.WINDOW_WIDTH or proj_collided_with_bar) {
        proj.velocity.x *= -1;
        return;
    }
    if (proj_collided_with_bar) particleBurst(bar.rect(), bar.color, config.PARTICLE_BURST_HIT_COUNT);
    for (targets_pool[0..]) |*it| {
        if (!it.dead and proj.overlaps(it.*, proj_nx, null)) {
            //rl.playSound(collid_sound);
            score += 1;
            it.dead = true;
            proj.velocity.x *= -1;
            particleBurst(proj.rect(), it.color, config.PARTICLE_BURST_HIT_COUNT);
            return;
        }
    }
    proj.position.x = proj_nx;
}

fn vert_collision(dt: f32) void {
    const proj_ny: f32 = proj.position.y + proj.velocity.y * config.PROJ_SPEED * dt;
    if (proj_ny < 0) {
        proj.velocity.y *= -1;
        return;
    }
    if (proj_ny + config.PROJ_SIZE > config.WINDOW_HEIGHT) {
        if (god_mode) {
            proj.velocity.y += 1.005;
            proj.velocity.y *= -1;
            return;
        }
        //rl.playSound(death_sound);
        life -= 1;
        state = .START;
        return;
    }
    if (proj.overlaps(bar, null, proj_ny)) {
        if (bar.velocity.x != 0) proj.velocity.x = bar.velocity.x;
        proj.velocity.y *= -1;
        particleBurst(bar.rect(), bar.color, config.PARTICLE_BURST_HIT_COUNT);
        return;
    }
    for (targets_pool[0..]) |*it| {
        if (!it.dead and proj.overlaps(it.*, null, proj_ny)) {
            //rl.playSound(collid_sound);
            score += 1;
            it.dead = true;
            proj.velocity.y *= -1;
            particleBurst(proj.rect(), it.color, config.PARTICLE_BURST_HIT_COUNT);
            return;
        }
    }
    proj.position.y = proj_ny;
}

fn barCollision(dt: f32) void {
    const bar_nx: f32 = math.clamp(
        bar.position.x + bar.velocity.x * config.BAR_SPEED * dt,
        0,
        config.WINDOW_WIDTH - config.BAR_LEN,
    );
    if (bar.overlaps(proj, bar_nx, null)) return;
    bar.position.x = bar_nx;
}
/// Top-left position where `src` rests centered on top of `dest`.
fn restingPos(src: *const Entity, dest: *const Entity) Vector2 {
    return .{
        .x = dest.getCenterX() - src.size.x / 2,
        .y = dest.position.y - src.size.y,
    };
}

fn attachTo(dt: f32, src: *Entity, dest: *Entity) bool {
    const target = restingPos(src, dest);
    const delta = target.subtract(src.position);
    const dist = delta.length();

    const speed = src.velocity.length() + 3500.0 * dt;
    const step = speed * dt;

    // Arrived (or would overshoot this frame): snap exactly onto the bar.
    if (dist <= step) {
        src.*.position = target;
        src.*.velocity = .zero();
        return true;
    }

    src.*.velocity = delta.divide(dist).scale(speed);
    src.*.position = src.position.add(src.velocity.scale(dt));
    return false;
}
fn lifeCollision(dt: f32) void {
    // const currProj = life_pool[life - 1];
    // if (!currProj.dead) {
    //     life_pool[life - 1].dead = true;
    //     proj = get_life();
    // }
    const barPos = bar.getCenter();
    const projPos = proj.getCenter();
    const dist = barPos.subtract(projPos).normalize();
    const proj_nx = proj.position.x + dist.x * (config.PROJ_SPEED * 4) * dt;
    const proj_ny = proj.position.y + dist.y * (config.PROJ_SPEED * 4) * dt;
    if (proj.overlaps(bar, proj_nx, proj_ny)) {
        state = .READY;
        particleBurst(bar.rect(), bar.color, config.PARTICLE_BURST_HIT_COUNT);
        return;
    }
    proj.position.x = proj_nx;
    proj.position.y = proj_ny;
    return;
}

pub fn updateBar(dt: f32) void {
    bar.velocity = .zero();
    if (left) bar.velocity.x += -1;
    if (right) bar.velocity.x += 1;
    barCollision(dt);
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

fn projCollision(c: Collision) void {
    std.log.info("collision: {t}", .{c});
    switch (c) {
        .bar => {
            if (bar.velocity.x != 0) {
                proj.velocity.x = bar.velocity.x * config.PROJ_SPEED;
            } else {
                // sign :: inline (x: float) -> float {
                //     return xx (-cast(int)(x<0) + cast(int)(x>0));
                // }
                proj.velocity.x = math.sign(proj.velocity.x) * config.PROJ_SPEED * config.ANGLE_FACTOR;
            }
        },
        .border_bottom => @panic("TODO: projCollision:bar not implemented"),
        _ => |n| {
            const ci: usize = @backingInt(Collision.target);
            const ni: usize = @backingInt(n);
            var target = &targets_pool[ni - ci];
            target.dead = !target.dead;
        },
        .target => unreachable,
        .no, .border_left, .border_top, .border_right => {},
    }
}

fn targetHit(target: *Entity) void {
    if (target.dead) return;
    particleBurst(target.react, target.color, config.PARTICLE_BURST_HIT_COUNT);
    target.*.dead = true;
    score += 1;
    if (allTargetDied()) {
        state = .VICTORY;
    }
}

pub fn update(dt: f32) void {
    if (pause) return;
    updateBar(dt);
    updateParticle(dt);
    // if (life <= 0) {
    //     state = .GAMEOVER;
    //     //rl.playSound(lose_sound);
    //     particleBurst(bar.rect(), bar.color, config.PARTICLE_BURST_DEATH_COUNT);
    //     bar.color.a = 0;
    //     return;
    // }
    // if (score >= config.TARGET_ROWS * config.TARGET_COLS) {
    //     state = .VICTORY;
    //     //rl.playSound(win_sound);
    //     return;
    // }
    // bar_collision(dt);

    switch (state) {
        .START => {
            state = .ATTACH;
        },
        // This process need to run till the proj has reached to the bar
        .ATTACH => {
            // lifeCollision(dt);
            //  Think of better way to do this
            {
                var currProj = &life_pool[life -| 1];
                if (!currProj.dead) {
                    currProj.dead = true;
                    proj = currProj.*;
                }
            }
            if (attachTo(dt, &proj, &bar)) {
                particleBurst(bar.rect(), bar.color, config.PARTICLE_BURST_HIT_COUNT);
                state = .READY;
                //rl.playSound(attach_sound);
            }
        },
        .READY => {
            // this anchor the projectile to bar till .PLAY state
            proj.position = restingPos(&proj, &bar);
        },
        .PLAY => {
            projCollision(horz_collision2(&proj.position, &proj.velocity, proj.size, dt));
            projCollision(vert_collision2(&proj.position, &proj.velocity, proj.size, dt));
        },
        .GAMEOVER => @panic("TODO: Game.update:GAMEOVER not implemented"),
        .RESTART => @panic("TODO: Game.update:RESTART not implemented"),
        .RESTORE_TARGETS => @panic("TODO: Game.update:RESTORE_TARGETS not implemented"),
        .VICTORY => @panic("TODO: Game.update:VICTORY not implemented"),
        // else => {
        // projCollision(horz_collision2(&proj.position, &proj.velocity, proj.size, dt));
        // projCollision(vert_collision2(&proj.position, &proj.velocity, proj.size, dt));
        // if (proj.overlaps(bar, null, null)) {
        //     proj.position.y = config.BAR_Y - config.BAR_THICKNESS / 2 - config.PROJ_SIZE - 1.0;
        //     return;
        // }
        // horz_collision(dt);
        // vert_collision(dt);
        // },
    }
}

pub fn render() void {
    drawReact(bar.rect(), bar.color);
    drawReact(proj.rect(), proj.color);
    for (life_pool) |lproj| {
        if (!lproj.dead) {
            drawReact(lproj.rect(), lproj.color);
        }
    }
    for (targets_pool) |target| {
        if (!target.dead) {
            drawReact(target.rect(), target.color);
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

fn toAttachState() void {
    proj.velocity = .zero();
    state = .ATTACH;
}

pub fn allTargetDied() bool {
    for (targets_pool) |target| {
        if (target.dead) return false;
    }
    return true;
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
