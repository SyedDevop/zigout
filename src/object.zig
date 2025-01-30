const std = @import("std");
const math = std.math;
const rl = @import("raylib");

pub const WINDOW_WIDTH = 1600;
pub const WINDOW_HEIGHT = 900;

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

pub const Entity = struct {
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

    /// Returns the x-coordinate of the center of the [Entity].
    pub inline fn getCenterX(self: *const Self) f32 {
        return self.react.x + self.react.width / 2;
    }

    /// Returns the y-coordinate of the center of the [Entity].
    pub inline fn getCenterY(self: *const Self) f32 {
        return self.react.y + self.react.height / 2;
    }

    /// Returns the Coordinate of the center of the [Entity].
    pub inline fn getCenter(self: *const Self) rl.Vector2 {
        return .{ .x = self.getCenterX(), .y = self.getCenterY() };
    }
    /// Sets the x-coordinate of the center of the rectangle.
    pub fn setCenterX(self: *Self, x: f32) void {
        self.react.x = x - self.react.width / 2;
    }
};

pub const MyColor = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn srgb_to_linear(color: rl.Color) MyColor {
        const gamma = 2.2;
        return .{
            .r = math.pow(f32, @as(f32, @floatFromInt(color.r)) / 255.0, gamma),
            .g = math.pow(f32, @as(f32, @floatFromInt(color.g)) / 255.0, gamma),
            .b = math.pow(f32, @as(f32, @floatFromInt(color.b)) / 255.0, gamma),
            .a = @as(f32, @floatFromInt(color.a)) / 255.0,
        };
    }

    pub fn linear_to_srgb(color: MyColor) rl.Color {
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
