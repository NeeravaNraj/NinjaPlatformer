const std = @import("std");
const raylib = @cImport(@cInclude("raylib.h"));
const game = @import("game.zig");
const Vec2 = game.Vec2;
const Game = game.Game;
const Rect = game.Rect;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.StringHashMap;
const AutoHashMap = std.AutoHashMap;

// Neighbors = [
//      (-1, 1), (0, 1), (1, 1)
//      (-1, 0), (0, 0), (1, 0)
//      (-1, -1), (0, -1), (1, -1)
// ]
const NEIGHBORS: [9]raylib.Vector2 = blk: {
    var i = 0;
    var y = 2;
    var neighbors: [9]raylib.Vector2 = undefined;
    while (y >= 0) : (y -= 1) {
        for (0..3) |x| {
            const x_f: f32 = @floatFromInt(x);
            const y_f: f32 = @floatFromInt(y);
            neighbors[i] = Vec2(x_f - 1.0, y_f - 1.0);
            i += 1;
        }
    }
    break :blk neighbors;
};

const TileKind = enum {
    const Self = @This();
    Grass,
    Stone,

    pub fn get_key(self: Self) []const u8 {
        return switch (self) {
            .Grass => "grass",
            .Stone => "stone",
        };
    }

    pub fn is_collidable(self: Self) bool {
        return switch (self) {
            .Grass => true,
            .Stone => true,
        };
    }
};

const Tile = struct { kind: TileKind, variant: u16, pos: raylib.Vector2 };

const TileKey = struct {
    const Self = @This();
    x: i32,
    y: i32,

    pub fn from_float(x: f32, y: f32) Self {
        return Self{ .x = @bitCast(x), .y = @bitCast(y) };
    }

    pub fn as_vec(self: Self) raylib.Vector2 {
        return Vec2(@bitCast(self.x), @bitCast(self.y));
    }

    pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d};{d}", .{ self.x, self.y });
    }
};

pub const TileMap = struct {
    const Self = @This();
    game: *Game,
    tilemap: AutoHashMap(TileKey, Tile),
    offgrid_tiles: ArrayList(Tile),
    tile_size: u8,
    collision_tiles: ArrayList(Tile),
    collision_rects: ArrayList(raylib.Rectangle),
    allocator: Allocator,

    pub fn init(game_obj: *Game, allocator: Allocator) Self {
        return Self{
            .game = game_obj,
            .tilemap = Self.make_tilemap(allocator),
            .offgrid_tiles = ArrayList(Tile).init(allocator),
            .collision_tiles = ArrayList(Tile).init(allocator),
            .collision_rects = ArrayList(raylib.Rectangle).init(allocator),
            .tile_size = 16,
            .allocator = allocator,
        };
    }

    fn make_tilemap(allocator: Allocator) AutoHashMap(TileKey, Tile) {
        var map = AutoHashMap(TileKey, Tile).init(allocator);
        for (0..10) |i| {
            const a: f32 = @floatFromInt(i + 6);
            const b: f32 = @floatFromInt(i + 5);
            const c: f32 = 12.0;

            map.put(
                TileKey.from_float(a, c),
                Tile { .kind = TileKind.Grass, .variant = 1, .pos = Vec2(a, c) }
            ) catch unreachable;

            map.put(
                TileKey.from_float(c, b), 
                Tile { .kind = TileKind.Stone, .variant = 1, .pos = Vec2(c, b) }
            ) catch unreachable;
        }

        return map;
    }

    pub fn tiles_around(self: *Self, pos: raylib.Vector2) []const Tile {
        const size: f32 = @floatFromInt(self.tile_size);
        const tile_loc = Vec2(@divTrunc(pos.x, size), @divTrunc(pos.y, size));

        self.collision_tiles.clearRetainingCapacity();
        for (NEIGHBORS) |neighbor| {
            const tile_x = tile_loc.x + neighbor.x;
            const tile_y = tile_loc.y + neighbor.y;
            const vec = TileKey.from_float(tile_x, tile_y);

            if (self.tilemap.get(vec)) |value|
                self.collision_tiles.append(value) catch unreachable;
        }

        return self.collision_tiles.items;
    }

    pub fn physics_rects_around(self: *Self, pos: raylib.Vector2) []const raylib.Rectangle {
        self.collision_rects.clearRetainingCapacity();

        const tiles = self.tiles_around(pos);
        for (tiles) |tile| {
            if (tile.kind.is_collidable()) {
                self.collision_rects.append(Rect(self.get_size(), self.get_size(), tile.pos.x * self.get_size(), tile.pos.y * self.get_size())) catch unreachable;
            }
        }

        return self.collision_rects.items;
    }

    pub fn render(self: *Self) void {
        const d_width: f32 = @floatFromInt(self.game.display.texture.width);
        const d_height: f32 = @floatFromInt(self.game.display.texture.height);

        const render_start_x: isize = @intFromFloat(@divTrunc(self.game.camera_offset.x, self.get_size()));
        const render_end_x: isize = @intFromFloat(@divTrunc(self.game.camera_offset.x + d_width, self.get_size()) + 1);

        const render_start_y: isize = @intFromFloat(@divTrunc(self.game.camera_offset.y, self.get_size()));
        const render_end_y: isize = @intFromFloat(@divTrunc(self.game.camera_offset.y + d_height, self.get_size()) + 1);

        var x = render_start_x;
        var y = render_start_y;

        while (x < render_end_x) : (x += 1) {
            while (y < render_end_y) : (y += 1) {
                const key = TileKey.from_float(@floatFromInt(x), @floatFromInt(y));

                if (self.tilemap.get(key)) |tile| {
                    if (self.game.get_asset_list(tile.kind.get_key(), @intCast(tile.variant))) |asset| {
                        const t_x: f32 = tile.pos.x * self.get_size() - self.game.camera_offset.x;
                        const t_y: f32 = tile.pos.y * self.get_size() - self.game.camera_offset.y;
                        raylib.DrawTextureV(asset.texture, Vec2(t_x, t_y), raylib.WHITE);
                    }
                }
            }
            y = render_start_y;
        }
    }

    fn alloc_key(key: []const u8, allocator: Allocator) []const u8 {
        const buf = allocator.alloc(u8, key.len) catch unreachable;
        std.mem.copyForwards(u8, buf, key);
        return buf;
    }

    fn get_size(self: *Self) f32 {
        return @floatFromInt(self.tile_size);
    }
};
