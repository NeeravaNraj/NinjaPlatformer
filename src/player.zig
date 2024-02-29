const std = @import("std");
const entities = @import("entities.zig");
const raylib = @cImport(@cInclude("raylib.h"));
const Game = @import("game.zig").Game;
const TileMap = @import("tilemap.zig").TileMap;
const PhysicsEntity = entities.PhysicsEntity;
const EntityKind = entities.EntityKind;
const Action = entities.Action;
const CollisionDirection = entities.CollisionDirection;
const Allocator = std.mem.Allocator;

pub const Player = struct {
    const Self = @This();

    entity: PhysicsEntity,
    air_time: u32,

    pub fn init(game: *Game, size: raylib.Vector2, pos: raylib.Vector2, allocator: Allocator) Self {
        return Self {
            .entity = PhysicsEntity.init(
                game, 
                EntityKind.Player, 
                size, 
                pos, 
                allocator
            ),
            .air_time = 0,
        };
    }

    pub fn update(self: *Self, tilemap: *TileMap, movement: raylib.Vector2) void {
        self.entity.update(tilemap, movement);

        self.air_time += 1;

        if (self.entity.collisions & @intFromEnum(CollisionDirection.Down) != 0) {
            self.air_time = 0;
        }

        if (self.air_time > 4) {
            self.entity.set_action(Action.Jump);
        } else if (movement.x != 0) {
            self.entity.set_action(Action.Run);
        } else {
            self.entity.set_action(Action.Idle);
        }

    }

    pub fn render(self: *Self) void {
        self.entity.render();
    }
};
