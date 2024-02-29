const std = @import("std");
const raylib = @cImport(@cInclude("raylib.h"));
const TileMap = @import("tilemap.zig").TileMap;
const g = @import("game.zig");
const String = @import("string.zig").String;
const Animation = @import("animation.zig").Animation;
const Game = g.Game;
const Rect = g.Rect;
const Vec2 = g.Vec2;
const Allocator = std.mem.Allocator;

pub const EntityKind = enum {
    const Self = @This();
    Player,

    pub fn as_string(self: Self) []const u8 {
        return switch (self) {
            .Player => "player",
        };
    }
};

pub const CollisionDirection = enum(u4) {
    Up = 1,
    Down = 2,
    Left = 4,
    Right = 8,
};

pub const Action = enum {
    const Self = @This();
    Idle,
    Run,
    Jump,
    Slide,
    WallSlide,

    pub fn get_key(self: Self) []const u8 {
        return switch (self) {
            .Idle => "idle",
            .Run => "run",
            .Jump => "jump",
            .Slide => "slide",
            .WallSlide => "wall_slide",

        };
    }
};

pub const PhysicsEntity = struct {
    const Self = @This();
    game: *Game,
    kind: EntityKind,
    size: raylib.Vector2,
    pos: raylib.Vector2,
    velocity: raylib.Vector2,
    // up, down, left, right
    collisions: u4,

    action: Action,
    animation_offset: raylib.Vector2,
    animation: *Animation,
    flip: bool,
    key_buffer: String,

    pub fn init(
        game: *Game, 
        kind: EntityKind, 
        size: raylib.Vector2, 
        pos: raylib.Vector2,
        allocator: Allocator,
    ) Self {
        var self = Self {
            .game = game,
            .kind = kind,
            .size = size,
            .pos = pos,
            .collisions = 0,
            .action = Action.Slide,
            .animation_offset = Vec2(-3, -3),
            .flip = false,
            .velocity = raylib.Vector2 { .x = 0, .y = 0 },
            .key_buffer = String.init("", allocator) catch unreachable,
            .animation = undefined,
        };

        self.set_action(Action.Idle);

        return self;
    }

    pub fn set_action(self: *Self, action: Action) void {
        if (@intFromEnum(action) != @intFromEnum(self.action)) {
            self.action = action;
            const key = self.make_key(action.get_key());
            self.animation = self.game.get_animation(key).?;
        }
    }

    pub fn update(self: *Self, tilemap: *TileMap, movement: raylib.Vector2) void {
        self.collisions = 0;
        const frame_movement = raylib.Vector2 {
            .x = movement.x + self.velocity.x,
            .y = movement.y + self.velocity.y,
        };

        self.pos.x += frame_movement.x;
        var rects = tilemap.physics_rects_around(self.pos);

        var entity_rect = self.as_rect();

        for (rects) |rect| {
            if (raylib.CheckCollisionRecs(rect, entity_rect)) {
                if (frame_movement.x > 0) { // right
                    entity_rect.x = rect.x - entity_rect.width;
                    self.collisions |= @intFromEnum(CollisionDirection.Right);
                } else if (frame_movement.x < 0) { // left
                    entity_rect.x = rect.x + rect.width;
                    self.collisions |= @intFromEnum(CollisionDirection.Left);
                }

                self.pos.x = entity_rect.x;
            }
        }
        self.pos.y += frame_movement.y;

        entity_rect = self.as_rect();
        rects = tilemap.physics_rects_around(self.pos);
        for (rects) |rect| {
            if (raylib.CheckCollisionRecs(rect, entity_rect)) {
                // y < 0 is up because as y increases we 
                // go towards the bottom of the screen
                if (frame_movement.y < 0) { // up
                    entity_rect.y = rect.y + rect.height;
                    self.collisions |= @intFromEnum(CollisionDirection.Up);
                } else if (frame_movement.y > 0) { // down
                    entity_rect.y = rect.y - entity_rect.height;
                    self.collisions |= @intFromEnum(CollisionDirection.Down);
                }

                self.pos.y = entity_rect.y;
            }
        }

        if (movement.x > 0) self.flip = false;
        if (movement.x < 0) self.flip = true;

        if (self.velocity.y < 9.8) self.velocity.y += 0.2;

        if (
            self.collisions & @intFromEnum(CollisionDirection.Down) != 0 or
            self.collisions & @intFromEnum(CollisionDirection.Up) != 0
        ) self.velocity.y = 0;
        self.animation.update();
    }

    pub fn render(self: *Self) void {
        const x = self.pos.x - self.game.camera_offset.x + self.animation_offset.x;
        const y = self.pos.y - self.game.camera_offset.y + self.animation_offset.y;

        const texture = self.animation.image().texture;

        var rect = raylib.Rectangle {
            .width = @floatFromInt(texture.width),
            .height = @floatFromInt(texture.height),
            .x = 0,
            .y = 0,
        };

        if (self.flip) {
            rect.width = -rect.width;
        }

        raylib.DrawTextureRec(texture, rect, Vec2(x, y), raylib.WHITE);
    }

    pub fn as_rect(self: *Self) raylib.Rectangle {
        return Rect(self.size.x, self.size.y, self.pos.x, self.pos.y);
    }

    pub fn make_key(self: *Self, action: []const u8) []const u8 {
        self.key_buffer.clear();
        self.key_buffer.push_str(self.kind.as_string()) catch unreachable;
        self.key_buffer.push_char('.') catch unreachable;
        self.key_buffer.push_str(action) catch unreachable;
        return self.key_buffer.as_slice();
    }
};
