const rl = @import("raylib");

pub fn main() void {
    const screenWidth = 800;
    const screenHeight = 600;
    const projectileSize = 20;
    const barWidth = 100;
    const barHeight = 20;
    const projectileSpeed = 4.0;

    rl.initWindow(screenWidth, screenHeight, "Projectile to Bar");
    rl.setTargetFPS(60);

    // Define the projectile as a rectangle
    var projectile = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = projectileSize,
        .height = projectileSize,
    };

    // Define the bar as a rectangle at the bottom center
    var bar = rl.Rectangle{
        .x = screenWidth / 2 - barWidth / 2,
        .y = screenHeight - barHeight,
        .width = barWidth,
        .height = barHeight,
    };

    // Calculate the center of the projectile and bar

    // Calculate the direction vector

    while (!rl.windowShouldClose()) {
        const dt: f32 = rl.getFrameTime();

        const projV = rl.Vector2{ .x = projectile.x + projectile.width / 2, .y = projectile.y + projectile.height / 2 };
        const barCenter = rl.Vector2{ .x = bar.x + bar.width / 2, .y = bar.y + bar.height / 2 };
        const direction = barCenter.subtract(projV).normalize();

        // Move the bar left and right
        if (rl.isKeyDown(.a) or rl.isKeyDown(.left)) {
            bar.x -= 500 * dt;
        }
        if (rl.isKeyDown(.d) or rl.isKeyDown(.right)) {
            bar.x += 500 * dt;
        }

        // Keep the bar within the screen bounds
        if (bar.x < 0) bar.x = 0;
        if (bar.x + bar.width > screenWidth) bar.x = screenWidth - bar.width;

        // Update projectile position
        projectile.x += direction.x * projectileSpeed;
        if (projectile.y <= bar.y - barHeight) projectile.y += direction.y * projectileSpeed;

        // Draw
        rl.beginDrawing();
        rl.clearBackground(rl.Color.white);

        // Draw the projectile
        rl.drawRectangleRec(projectile, rl.Color.red);

        // Draw the bar
        rl.drawRectangleRec(bar, rl.Color.blue);

        rl.endDrawing();
    }

    rl.closeWindow();
}
