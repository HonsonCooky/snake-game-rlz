const std = @import("std");
const rl = @import("raylib");
const rm = @import("raymath");

const SnakeNode = struct {
    x: i32,
    y: i32,
    next: ?*SnakeNode,
};

const Player = struct {
    head: *SnakeNode,

    pub fn init() Player {}
};

pub fn main() void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Snake Game");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var timeSinceMove: f32 = 0;
    const movementTime = 0.2;

    // Main Game Loop
    while (!rl.windowShouldClose()) {
        // Update
        {
            if (timeSinceMove < movementTime) {
                timeSinceMove += rl.getFrameTime();
            } else {
                timeSinceMove = 0;
            }
        }

        // Draw
        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.white);
        }
    }
}
