const std = @import("std");
const rl = @import("raylib");

const MapWidth: comptime_int = 160;
const MapHeight: comptime_int = 90;
const TileSize: comptime_int = 50;

const IVector2 = struct {
    x: i32,
    y: i32,
};

const SnakeNode = struct {
    position: IVector2,
    next: ?*SnakeNode = null,

    pub fn addNode(self: *SnakeNode, otherPtr: *SnakeNode) void {
        if (self.next) |next| {
            next.addNode(otherPtr);
            return;
        }

        otherPtr.* = SnakeNode{ .position = self.position };
        self.next = otherPtr;
    }

    pub fn move(self: *SnakeNode, newPos: IVector2) void {
        if (self.next) |next| next.position = self.position;
        self.position = newPos;
    }

    pub fn draw(self: *SnakeNode) void {
        rl.drawRectangle(
            self.position.x,
            self.position.y,
            TileSize,
            TileSize,
            rl.Color.green,
        );
    }
};

const Player = struct {
    head: *SnakeNode,
    length: i32,
    _direction: IVector2,
    _nodeAllocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Player {
        const head = try allocator.create(SnakeNode);
        head.* = SnakeNode{ .position = IVector2{ .x = MapWidth / 2, .y = MapHeight / 2 } };
        return Player{
            .head = head,
            .length = 1,
            ._direction = IVector2{ .x = 0, .y = 0 },
            ._nodeAllocator = allocator,
        };
    }

    pub fn addNode(self: *Player) !void {
        const newNodePtr = try self._nodeAllocator.create(SnakeNode);
        self.head.addNode(newNodePtr);
        self.length += 1;
    }

    pub fn free(self: *Player) void {
        var currentNode: ?*SnakeNode = self.head;
        while (currentNode) |node| {
            const nextNode = node.next;
            self._nodeAllocator.destroy(node);
            currentNode = nextNode;
        }
    }

    pub fn update(self: *Player) void {
        if (rl.isKeyDown(rl.KeyboardKey.w)) {
            self._direction = IVector2{ .x = 0, .y = -1 };
        } else if (rl.isKeyDown(rl.KeyboardKey.s)) {
            self._direction = IVector2{ .x = 0, .y = 1 };
        } else if (rl.isKeyDown(rl.KeyboardKey.a)) {
            self._direction = IVector2{ .x = -1, .y = 0 };
        } else if (rl.isKeyDown(rl.KeyboardKey.d)) {
            self._direction = IVector2{ .x = 1, .y = 0 };
        }
    }

    pub fn move(self: *Player) void {
        const newPos = IVector2{
            .x = self.head.position.x + self._direction.x,
            .y = self.head.position.y + self._direction.y,
        };
        self.head.move(newPos);
    }
};

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Snake Game");
    defer rl.closeWindow();

    const gameAlloc = std.heap.page_allocator;
    var player = try Player.init(gameAlloc);
    defer player.free();

    try player.addNode();
    try player.addNode();

    var timeSinceMove: f32 = 0;
    const movementTime = 0.2;

    // Main Game Loop
    while (!rl.windowShouldClose()) {
        update: {
            player.update();

            if (timeSinceMove < movementTime) {
                timeSinceMove += rl.getFrameTime();
            } else {
                timeSinceMove = 0;
                player.move();
            }

            break :update;
        }

        draw: {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.white);
            break :draw;
        }
    }
}
