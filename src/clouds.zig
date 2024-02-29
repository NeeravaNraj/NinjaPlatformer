const std = @import("std");
const raylib = @cImport(@cInclude("raylib.h"));
const game = @import("game.zig");
const Asset = @import("loader.zig").Asset;
const Vec2 = game.Vec2;
const Game = game.Game;
const Rect = game.Rect;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Cloud = struct {
    const Self = @This();

    pos: raylib.Vector2,
    texture: raylib.Texture2D,
    depth: f32,
    speed: f32,
    game: *Game,

    pub fn init(pos: raylib.Vector2, texture: raylib.Texture2D, depth: f32, speed: f32, game_obj: *Game) Self {
        return Self {
            .pos = pos,
            .texture = texture,
            .depth = depth,
            .speed = speed,
            .game = game_obj,
        };
    }

    pub fn update(self: *Self) void {
        self.pos.x += self.speed;
    }

    pub fn render(self: *Self) void {
        const render_pos = Vec2(
            self.pos.x - self.game.camera_offset.x * self.depth,
            self.pos.y - self.game.camera_offset.y * self.depth,
        );

        const display = self.game.display.texture;
        const ring_height: f32 = @floatFromInt(display.height + self.texture.height);
        const texture_width: f32 = @floatFromInt(self.texture.width);
        const ring_width: f32 = @floatFromInt(display.width + self.texture.width);
        const texture_height: f32 = @floatFromInt(self.texture.height);

        raylib.DrawTextureV(
            self.texture, 
            Vec2(
                @mod(render_pos.x, ring_width) - texture_width, 
                @mod(render_pos.y, ring_height) - texture_height,
            ), 
            raylib.WHITE
        );
    }
};

pub const Clouds = struct {
    const Self = @This();
    // hardcoding it dont care
    clouds: [12] Cloud,

    pub fn init(game_obj: *Game, textures: []Asset) Self {
        var self = Self { .clouds = undefined };

        var xoshiro = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        var rand = xoshiro.random();
        for (0..self.clouds.len) |i| {
            const cloud_x = rand.float(f32) * 99999.0;
            const cloud_y = rand.float(f32) * 99999.0;
            const random_cloud = textures[rand.int(usize) % textures.len];
            const speed = rand.float(f32) * 0.05 + 0.05;
            const depth = rand.float(f32) * 0.6 + 0.2;
            self.clouds[i] = Cloud.init(Vec2(cloud_x, cloud_y), random_cloud.texture, depth, speed, game_obj);
        }

        return self;
    }

    pub fn update(self: *Self) void {
        for (0..self.clouds.len) |i| {
            self.clouds[i].update();
        }
    }

    pub fn render(self: *Self) void {
        for (0..self.clouds.len) |i| {
            self.clouds[i].render();
        }
    }
};
