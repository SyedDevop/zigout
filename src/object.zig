const std = @import("std");
const math = std.math;
//const rl = @import("raylib");
const config = @import("config.zig");
pub const Vector2 = struct {
    x: f32,
    y: f32,

    pub fn zero() Vector2 {
        return .{ .x = 0, .y = 0 };
    }
    pub fn subtract(v1: Vector2, v2: Vector2) Vector2 {
        return .{ .x = v1.x - v2.x, .y = v1.y - v2.y };
    }

    pub fn add(v1: Vector2, v2: Vector2) Vector2 {
        return .{ .x = v1.x + v2.x, .y = v1.y + v2.y };
    }

    pub fn scale(v: Vector2, scalar: f32) Vector2 {
        return .{ .x = v.x * scalar, .y = v.y * scalar };
    }

    pub fn normalize(v: Vector2) Vector2 {
        var res: Vector2 = .{ .x = 0, .y = 0 };
        const length: f32 = @sqrt((v.x * v.x) + (v.y * v.y));
        if (length > 0) {
            const ilength: f32 = 1.0 / length;
            res.x = v.x * ilength;
            res.y = v.y * ilength;
        }
        return res;
    }
};

pub const StateKind = enum {
    // Waiting until the player proves that they can move (with A/D keys)
    START,
    // The ball from the life bar rapidly moving towards the paddle to attach to it
    ATTACH,
    // The ball is attached to the paddle and waiting until the player presses SPACE
    READY,
    // Just the usual game play until the ball hits the bottom
    PLAY,
    // Ran out of lifes before destroying all the targets
    GAMEOVER,
    // Start the whole game from scratch
    RESTART,
    // Destroyed all the targets
    VICTORY,
    RESTORE_TARGETS,
};

pub const Rectangle = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    pub fn init(x: f32, y: f32, width: f32, height: f32) Rectangle {
        return Rectangle{ .x = x, .y = y, .width = width, .height = height };
    }
};

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub const red = Color.init(255, 46, 46, 255);
    pub const green = Color.init(46, 228, 46, 255);
    pub const blue = Color.init(46, 46, 255, 255);
    pub const white = Color.init(255, 255, 255, 255);
    pub const black = Color.init(0, 0, 0, 255);
    pub const blank = Color.init(0, 0, 0, 0);
    pub fn init(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }
};

// Check collision between two rectangles
pub fn checkCollisionRecs(rec1: Rectangle, rec2: Rectangle) bool {
    var collision: bool = false;

    if ((rec1.x < (rec2.x + rec2.width) and (rec1.x + rec1.width) > rec2.x) and
        (rec1.y < (rec2.y + rec2.height) and (rec1.y + rec1.height) > rec2.y))
        collision = true;
    return collision;
}

pub const Entity = struct {
    dx: f32 = 0,
    dy: f32 = 0,
    dead: bool = false,
    color: Color,
    react: Rectangle,
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
        return checkCollisionRecs(updatedRect, otherEntity.react);
    }

    /// Returns the x-coordinate of the center of the [Entity].
    pub inline fn getCenterX(self: *const Self) f32 {
        return self.react.x + self.react.width / 2;
    }

    /// Returns the y-coordinate of the center of the [Entity].
    pub inline fn getCenterY(self: *const Self) f32 {
        return self.react.y + self.react.height / 2;
    }

    /// Returns the Coordinate of the center of the [Entity].
    pub inline fn getCenter(self: *const Self) Vector2 {
        return .{ .x = self.getCenterX(), .y = self.getCenterY() };
    }
    /// Sets the x-coordinate of the center of the rectangle.
    pub fn setCenterX(self: *Self, x: f32) void {
        self.react.x = x - self.react.width / 2;
    }
};

pub inline fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub inline fn inverceLerp(a: f32, b: f32, t: f32) f32 {
    const alpha = t * t; // Quadratic easing (slower at start, faster at end)
    return a + (b - a) * alpha;
}

pub inline fn smooth(curr: f32, target: f32, factor: f32) f32 {
    return curr + (target - curr) * (1 - @exp(-factor));
}
pub inline fn easeInQuad(t: f32) f32 {
    return t * t;
}

pub const MyColor = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn srgb_to_linear(color: Color) MyColor {
        const gamma = 2.2;
        return .{
            .r = math.pow(f32, @as(f32, @floatFromInt(color.r)) / 255.0, gamma),
            .g = math.pow(f32, @as(f32, @floatFromInt(color.g)) / 255.0, gamma),
            .b = math.pow(f32, @as(f32, @floatFromInt(color.b)) / 255.0, gamma),
            .a = @as(f32, @floatFromInt(color.a)) / 255.0,
        };
    }

    pub fn linear_to_srgb(color: MyColor) Color {
        const inv_gamma = 1.0 / 2.2;
        return .{
            .r = @intFromFloat(math.pow(f32, color.r, inv_gamma) * 255.0),
            .g = @intFromFloat(math.pow(f32, color.g, inv_gamma) * 255.0),
            .b = @intFromFloat(math.pow(f32, color.b, inv_gamma) * 255.0),
            .a = @intFromFloat(color.a * 255.0),
        };
    }

    pub fn lerp(a: MyColor, b: MyColor, t: f32) MyColor {
        return .{
            .r = a.r + (b.r - a.r) * t,
            .g = a.g + (b.g - a.g) * t,
            .b = a.b + (b.b - a.b) * t,
            .a = a.a + (b.a - a.a) * t,
        };
    }
};
