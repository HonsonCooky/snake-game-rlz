const std = @import("std");
const rl = @import("raylib");
const rm = @import("raymath");

const Snake = struct {
    position: rl.Vector2,
    _direction: rl.Vector2 = rl.Vector2.zero(),

    pub fn update(self: *Snake) void {
        if (rl.isKeyDown(rl.KeyboardKey.w)) {
            self._direction = rl.Vector2{ .x = 0, .y = -1 };
        } else if (rl.isKeyDown(rl.KeyboardKey.s)) {
            self._direction = rl.Vector2{ .x = 0, .y = 1 };
        } else if (rl.isKeyDown(rl.KeyboardKey.a)) {
            self._direction = rl.Vector2{ .x = -1, .y = 0 };
        } else if (rl.isKeyDown(rl.KeyboardKey.d)) {
            self._direction = rl.Vector2{ .x = 1, .y = 0 };
        }
    }
};

pub fn main() void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Snake Game");
    defer rl.closeWindow();

    // Main Game Loop
    while (!rl.windowShouldClose()) {
        // Update
        {}

        // Draw
        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.white);
        }
    }
}
