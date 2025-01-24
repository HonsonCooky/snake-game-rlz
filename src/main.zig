const std = @import("std");
const rl = @import("raylib");

const screenWidth = 960;
const screenHeight = 720;
const TileSize = 30;
const MapWidth = screenWidth / TileSize;
const MapHeight = screenHeight / TileSize;

const IVector2 = struct {
    x: i32,
    y: i32,
};

const Apple = struct {
    position: IVector2,

    pub fn init() Apple {
        return Apple{
            .position = IVector2{
                .x = rl.getRandomValue(0, MapWidth) * TileSize,
                .y = rl.getRandomValue(0, MapHeight) * TileSize,
            },
        };
    }

    pub fn eat(self: *Apple) void {
        self.position = IVector2{
            .x = rl.getRandomValue(0, MapWidth) * TileSize,
            .y = rl.getRandomValue(0, MapHeight) * TileSize,
        };
    }

    pub fn draw(self: *Apple) void {
        rl.drawRectangle(
            self.position.x,
            self.position.y,
            TileSize,
            TileSize,
            rl.Color.fromInt(0xf38ba8ff),
        );
    }
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
        if (self.next) |next| next.move(self.position);
        self.position = newPos;
    }

    pub fn draw(self: *SnakeNode) void {
        if (self.next) |next| next.draw();

        rl.drawRectangle(
            self.position.x,
            self.position.y,
            TileSize,
            TileSize,
            rl.Color.fromInt(0xa6e3a1ff),
        );
    }
};

const Player = struct {
    head: *SnakeNode,
    length: i32,
    _direction: IVector2,
    _nextDirection: IVector2,
    _nodeAllocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Player {
        const head = try allocator.create(SnakeNode);
        head.* = SnakeNode{
            .position = IVector2{
                .x = (MapWidth / 2) * TileSize,
                .y = (MapHeight / 2) * TileSize,
            },
        };
        return Player{
            .head = head,
            .length = 1,
            ._direction = IVector2{ .x = 0, .y = 0 },
            ._nextDirection = IVector2{ .x = 0, .y = 0 },
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
        if (rl.isKeyDown(rl.KeyboardKey.w) and self._direction.y != 1) {
            self._nextDirection = IVector2{ .x = 0, .y = -1 };
        } else if (rl.isKeyDown(rl.KeyboardKey.s) and self._direction.y != -1) {
            self._nextDirection = IVector2{ .x = 0, .y = 1 };
        } else if (rl.isKeyDown(rl.KeyboardKey.a) and self._direction.x != 1) {
            self._nextDirection = IVector2{ .x = -1, .y = 0 };
        } else if (rl.isKeyDown(rl.KeyboardKey.d) and self._direction.x != -1) {
            self._nextDirection = IVector2{ .x = 1, .y = 0 };
        }
    }

    fn collisionWithSelf(self: *Player, newPos: IVector2) bool {
        var collided = false;
        const headRec = rl.Rectangle.init(
            @floatFromInt(newPos.x),
            @floatFromInt(newPos.y),
            TileSize,
            TileSize,
        );
        var nextNode = self.head.next;

        while (nextNode) |node| {
            const nodeRec = rl.Rectangle.init(
                @floatFromInt(node.position.x),
                @floatFromInt(node.position.y),
                TileSize,
                TileSize,
            );
            collided = rl.checkCollisionRecs(headRec, nodeRec);
            if (collided) break;
            nextNode = node.next;
        }

        return collided;
    }

    fn warpWalls(newPos: *IVector2) void {
        if (newPos.x < 0) newPos.x = (MapWidth - 1) * TileSize;
        if (newPos.x > ((MapWidth - 1) * TileSize)) newPos.x = 0;
        if (newPos.y < 0) newPos.y = (MapHeight - 1) * TileSize;
        if (newPos.y > (MapHeight - 1) * TileSize) newPos.y = 0;
    }

    pub fn move(self: *Player) void {
        self._direction = self._nextDirection;

        var newPos = IVector2{
            .x = self.head.position.x + (self._direction.x * TileSize),
            .y = self.head.position.y + (self._direction.y * TileSize),
        };

        warpWalls(&newPos);

        if (self.collisionWithSelf(newPos)) return;

        self.head.move(newPos);
    }

    pub fn draw(self: *Player) void {
        self.head.draw();
    }
};

pub fn main() !void {
    std.debug.print("{} {} {} {}", .{ MapHeight, MapWidth, screenHeight, screenWidth });
    rl.setConfigFlags(.{ .vsync_hint = true });

    rl.initWindow(screenWidth, screenHeight, "Snake Game");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    const gameAlloc = std.heap.page_allocator;
    var player = try Player.init(gameAlloc);
    defer player.free();

    var apple = Apple.init();

    for (0..3) |_| try player.addNode();

    var timeSinceMove: f32 = 0;
    const movementTime = 0.05;

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

            const playerRec = rl.Rectangle{
                .height = TileSize,
                .width = TileSize,
                .x = @floatFromInt(player.head.position.x),
                .y = @floatFromInt(player.head.position.y),
            };
            const appleRec = rl.Rectangle{
                .height = TileSize,
                .width = TileSize,
                .x = @floatFromInt(apple.position.x),
                .y = @floatFromInt(apple.position.y),
            };

            if (rl.checkCollisionRecs(playerRec, appleRec)) {
                try player.addNode();
                apple.eat();
            }

            break :update;
        }

        draw: {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(rl.Color.fromInt(0x1e1e2eff));
            rl.drawFPS(10, 10);

            player.draw();
            apple.draw();

            break :draw;
        }
    }
}
