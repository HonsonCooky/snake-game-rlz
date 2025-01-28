const std = @import("std");
const rl = @import("raylib");

const gameAlloc = std.heap.page_allocator;
const screenWidth = 960;
const screenHeight = 720;
const TileSize = 30;
const MapWidth = screenWidth / TileSize;
const MapHeight = screenHeight / TileSize;

const GameState = enum {
    menu,
    play,
    end,
    quit,
};

var gameState = GameState.menu;

const IVector2 = struct {
    x: i32,
    y: i32,
};

const Apple = struct {
    position: IVector2,

    pub fn init() Apple {
        return Apple{
            .position = IVector2{
                .x = rl.getRandomValue(0, MapWidth - 1) * TileSize,
                .y = rl.getRandomValue(0, MapHeight - 1) * TileSize,
            },
        };
    }

    pub fn eat(self: *Apple) void {
        self.position = IVector2{
            .x = rl.getRandomValue(0, MapWidth - 1) * TileSize,
            .y = rl.getRandomValue(0, MapHeight - 1) * TileSize,
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

        var player = Player{
            .head = head,
            .length = 1,
            ._direction = IVector2{ .x = 0, .y = 0 },
            ._nextDirection = IVector2{ .x = 0, .y = 0 },
            ._nodeAllocator = allocator,
        };

        for (0..3) |_| try player.addNode();

        return player;
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

        const hasMoved = self._direction.x != 0 or self._direction.y != 0;
        if (self.collisionWithSelf(newPos) and hasMoved) {
            gameState = GameState.end;
            return;
        }

        self.head.move(newPos);
    }

    pub fn draw(self: *Player) void {
        self.head.draw();
    }
};

fn menu(player: *Player, apple: *Apple) !void {
    if (player.length > 4) {
        std.debug.print("HERE", .{});
        player.free();
        player.* = try Player.init(gameAlloc);
        apple.eat();
    }

    draw: {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.fromInt(0x1e1e2eff));
        const mousePosition = rl.getMousePosition();

        // Play Button
        const pBtnRec =
            rl.Rectangle{
            .width = screenWidth / 2.0,
            .height = screenHeight / 10.0,
            .x = screenWidth / 4.0,
            .y = screenHeight / 3.0,
        };
        const hoveringPBtn = rl.checkCollisionPointRec(mousePosition, pBtnRec);
        const pBtnColor = rl.Color.fromInt(if (hoveringPBtn) 0xf9e2afff else 0xfab387ff);
        rl.drawRectangleRounded(pBtnRec, 0.5, 10, pBtnColor);
        rl.drawText(
            "Play",
            (screenWidth / 2) - rl.measureText("Pl", screenHeight / 20.0),
            (screenHeight / 3.0) + (screenHeight / 40.0),
            screenHeight / 20.0,
            rl.Color.fromInt(0x1e1e2eff),
        );

        if (rl.isMouseButtonPressed(rl.MouseButton.left) and hoveringPBtn) {
            gameState = GameState.play;
        }

        // Quit Button
        const qBtnRec =
            rl.Rectangle{
            .width = screenWidth / 2.0,
            .height = screenHeight / 10.0,
            .x = screenWidth / 4.0,
            .y = screenHeight * 2 / 3.0,
        };
        const hoveringQBtn = rl.checkCollisionPointRec(mousePosition, qBtnRec);
        const qBtnColor = rl.Color.fromInt(if (hoveringQBtn) 0xf9e2afff else 0xfab387ff);
        rl.drawRectangleRounded(qBtnRec, 0.5, 10, qBtnColor);
        rl.drawText(
            "Quit",
            (screenWidth / 2) - rl.measureText("Qu", screenHeight / 20.0),
            (screenHeight * 2 / 3.0) + (screenHeight / 40.0),
            screenHeight / 20.0,
            rl.Color.fromInt(0x1e1e2eff),
        );

        if (rl.isMouseButtonPressed(rl.MouseButton.left) and hoveringQBtn) {
            gameState = GameState.quit;
        }

        break :draw;
    }
}

fn play(player: *Player, apple: *Apple, timeSinceMove: *f32) !void {
    update: {
        if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
            gameState = GameState.end;
            return;
        }

        player.update();

        if (timeSinceMove.* < 0.1) {
            timeSinceMove.* += rl.getFrameTime();
        } else {
            timeSinceMove.* = 0;
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

fn end(player: *Player) !void {
    const mousePosition = rl.getMousePosition();

    draw: {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.fromInt(0x1e1e2eff));

        // Score Text
        const scoreStr = rl.textFormat("Score: %i", .{player.length});
        const xPos = @as(f32, screenWidth / 2.0) -
            (@as(f32, @floatFromInt(rl.measureText(scoreStr, 20))) / 2.0);

        rl.drawText(
            scoreStr,
            @intFromFloat(xPos),
            (screenHeight / 3.0) + (screenHeight / 40.0),
            screenHeight / 20.0,
            rl.Color.fromInt(0xcdd6f4ff),
        );

        // Menu Button
        const mBtnRec =
            rl.Rectangle{
            .width = screenWidth / 2.0,
            .height = screenHeight / 10.0,
            .x = screenWidth / 4.0,
            .y = screenHeight * 2 / 3.0,
        };
        const hoveringMBtn = rl.checkCollisionPointRec(mousePosition, mBtnRec);
        const mBtnColor = rl.Color.fromInt(if (hoveringMBtn) 0xf9e2afff else 0xfab387ff);
        rl.drawRectangleRounded(mBtnRec, 0.5, 10, mBtnColor);
        rl.drawText(
            "Menu",
            (screenWidth / 2) - rl.measureText("Me", screenHeight / 20.0),
            (screenHeight * 2 / 3.0) + (screenHeight / 40.0),
            screenHeight / 20.0,
            rl.Color.fromInt(0x1e1e2eff),
        );

        if (rl.isMouseButtonPressed(rl.MouseButton.left) and hoveringMBtn) {
            gameState = GameState.menu;
        }
        break :draw;
    }
}

pub fn main() !void {
    rl.setConfigFlags(.{ .vsync_hint = true });
    rl.initWindow(screenWidth, screenHeight, "Snake Game");
    defer rl.closeWindow();
    rl.setExitKey(rl.KeyboardKey.null);
    rl.setTargetFPS(60);

    // Init Player
    var player = try Player.init(gameAlloc);
    defer player.free();

    var apple = Apple.init();

    var timeSinceMove: f32 = 0;

    // Main Game Loop
    while (!rl.windowShouldClose() and gameState != GameState.quit) {
        try switch (gameState) {
            .menu => menu(&player, &apple),
            .play => play(&player, &apple, &timeSinceMove),
            .end => end(&player),
            .quit => return,
        };
    }
}
