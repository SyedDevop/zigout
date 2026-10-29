const std = @import("std");
const math = std.math;
const object = @import("object.zig");

pub const Particle = @This();
position: object.Vector2,
velocity: object.Vector2,
color: object.Color,
size_multiplayer: f32 = 1.0,
lifetime: f32,

pub const default = Particle{
    .position = .{ .x = 0, .y = 0 },
    .velocity = .{ .x = 0, .y = 0 },
    .color = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    .lifetime = 0,
};

pub fn isAlive(self: *const Particle) bool {
    return self.lifetime > 0;
}

pub fn initializeParticles(particle: []Particle) void {
    for (particle) |*v| v.* = .default;
}

pub fn init(position: object.Vector2, velocity: object.Vector2, color: object.Color, lifetime: f32) Particle {
    return .{ .position = position, .velocity = velocity, .color = color, .lifetime = lifetime };
}

pub fn format(
    self: @This(),
    writer: *std.Io.Writer,
) std.Io.Writer.Error!void {
    try writer.print("Position: {d}, {d}\n", .{ self.position.x, self.position.y });
    try writer.print("Velocity: {d}, {d}\n", .{ self.velocity.x, self.velocity.y });
    try writer.print("Color: {d}, {d}, {d}, {d}\n", .{ self.color.r, self.color.g, self.color.b, self.color.a });
    try writer.print("Lifetime: {d}\n", .{self.lifetime});
}
