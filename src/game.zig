const std = @import("std");
const entity = @import("entities.zig");
const loader = @import("loader.zig");
const raylib = @cImport(@cInclude("raylib.h"));
const Clouds = @import("clouds.zig").Clouds;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const HashMap = std.StringHashMap;
const PhysicEntity = entity.PhysicsEntity;
const EntityKind = entity.EntityKind;
const Asset = loader.Asset;
const TileMap = @import("tilemap.zig").TileMap;
const Animation = @import("animation.zig").Animation;
const Player = @import("player.zig").Player;

/// accepts u32 in format a-b-g-r
pub fn int_to_color(color: u32) raylib.Color {
    return @bitCast(color);
}

pub fn Vec2(x: f32, y: f32) raylib.Vector2 {
    return raylib.Vector2 { .x = x, .y = y};
}

pub fn Rect(w: f32, h: f32, x: f32, y: f32) raylib.Rectangle {
    return raylib.Rectangle {
        .width = w,
        .height = h,
        .x = x,
        .y = y,
    };
}

pub const Game = struct {
    const Self = @This();
    const GameError = error {
        Load
    };
    height: u16,
    width: u16,
    name: [*c]const u8,
    target_fps: u16,
    individual_assets: HashMap(raylib.Texture2D),
    assets: HashMap(ArrayList(Asset)),
    animations: HashMap(Animation),
    camera_offset: raylib.Vector2,
    display: raylib.RenderTexture2D,
    allocator: Allocator,

    pub fn init(
        name: [*c]const u8, 
        width: u16, 
        height: u16, 
        target_fps: u16, 
        allocator: Allocator
    ) Self {
        return Self{
            .name = name,
            .width = width,
            .height = height,
            .target_fps = target_fps,
            .individual_assets = HashMap(raylib.Texture2D).init(allocator),
            .assets = HashMap(ArrayList(Asset)).init(allocator),
            .animations = HashMap(Animation).init(allocator),
            .camera_offset = Vec2(0, 0),
            .display = undefined,
            .allocator = allocator,
        };
    }

    pub fn init_game(self: *Self) GameError!void {
        raylib.InitWindow(self.width, self.height, self.name);
        raylib.SetTargetFPS(@intCast(self.target_fps));
        self.display = raylib.LoadRenderTexture(@divTrunc(self.width, 2), @divTrunc(self.height, 2));
        try self.load_assets();
        try self.load_animations();
    }

    fn events(self: *Self) void {
        _ = self;
    }

    pub fn loop(self: *Self) void {
        var player = Player.init(
            self, 
            Vec2(8, 15), 
            Vec2(200, 200),
            self.allocator,
        );

        var tilemap = TileMap.init(self, self.allocator);
        var clouds = Clouds.init(self, self.assets.getPtr("cloud").?.items);
        var movement: [2]i8 = .{ 0, 0 };

        while (!raylib.WindowShouldClose()) {
            self.events();

            // const dt = raylib.GetFrameTime();
            if (raylib.IsKeyPressed(raylib.KEY_A)) movement[0] = 1;
            if (raylib.IsKeyPressed(raylib.KEY_D)) movement[1] = 1;
            if (raylib.IsKeyPressed(raylib.KEY_SPACE)) player.entity.velocity.y = -3;
            if (raylib.IsKeyUp(raylib.KEY_A)) movement[0] = 0;
            if (raylib.IsKeyUp(raylib.KEY_D)) movement[1] = 0;

            self.update_camera(&player.entity);
            clouds.update();
            player.update(&tilemap, Vec2(@floatFromInt(movement[1] - movement[0]), 0));

            // This is where we will be drawing mainly
            raylib.BeginTextureMode(self.display);
                raylib.ClearBackground(int_to_color(0xFFefab88));
                clouds.render();
                tilemap.render();
                player.render();
            raylib.EndTextureMode();

            raylib.BeginDrawing();
                // And we take that texture and upscale it here
                raylib.DrawTexturePro(
                    self.display.texture, 
                    Rect(@floatFromInt(self.display.texture.width), @floatFromInt(-self.display.texture.height), 0, 0), 
                    Rect(@floatFromInt(self.width), @floatFromInt(self.height), 0, 0), 
                    Vec2(0, 0), 
                    0,
                    raylib.WHITE
                );
                raylib.DrawFPS(10, 10);
            raylib.EndDrawing();
        }
    }

    pub fn get_asset(self: *Self, name: []const u8) ?*const raylib.Texture2D {
        return self.individual_assets.getPtr(name);
    }

    pub fn get_asset_list(self: *Self, name: []const u8, variant: usize) ?*const Asset {
        if (self.assets.get(name)) |assets| return &assets.items[variant];
        return null;
    }

    pub fn get_animation(self: *Self, name: []const u8) ?*Animation {
        if (self.animations.getPtr(name)) |animation| return animation;
        return null;
    }

    fn load_assets(self: *Self) GameError!void {
        var images = HashMap(AssetTemplate).init(self.allocator);
        defer images.deinit();

        // player
        images.put("player", AssetTemplate.init("entities/player.png", false)) 
        catch return GameError.Load;

        // tiles
        images.put("grass", AssetTemplate.init("tiles/grass/", true)) 
        catch return GameError.Load;
        images.put("decor", AssetTemplate.init("tiles/decor/", true)) 
        catch return GameError.Load;
        images.put("large_decor", AssetTemplate.init("tiles/large_decor/", true)) 
        catch return GameError.Load;
        images.put("stone", AssetTemplate.init("tiles/stone/", true)) 
        catch return GameError.Load;

        // misc
        images.put("cloud", AssetTemplate.init("clouds/", true)) 
        catch return GameError.Load;

        var image_iterator = images.iterator();
        while (image_iterator.next()) |image| {
            if (!image.value_ptr.is_many) {
                const texture = loader.load_image(image.value_ptr.path, self.allocator) 
                catch return GameError.Load;
                self.individual_assets.put(image.key_ptr.*, texture) 
                catch return GameError.Load;
            } else {
                const textures = loader.load_all_images(image.value_ptr.path, self.allocator) 
                catch return GameError.Load;
                self.assets.put(image.key_ptr.*, textures) 
                catch return GameError.Load;
            }
        }
    }

    fn load_animations(self: *Self) GameError!void {
        var animations = HashMap(AnimationTemplate).init(self.allocator);
        defer animations.deinit();

        animations.put("player.idle", AnimationTemplate.init("entities/player/idle/", 6, true)) 
        catch return GameError.Load;
        animations.put("player.run", AnimationTemplate.init("entities/player/run/", 4, true)) 
        catch return GameError.Load;
        animations.put("player.jump", AnimationTemplate.init("entities/player/jump/", 5, true)) 
        catch return GameError.Load;
        animations.put("player.slide", AnimationTemplate.init("entities/player/slide/", 5, true)) 
        catch return GameError.Load;
        animations.put("player.wall_slide", AnimationTemplate.init("entities/player/wall_slide/", 5, true)) 
        catch return GameError.Load;

        var animation_iterator = animations.iterator();
        while (animation_iterator.next()) |entry| {
            const value = entry.value_ptr;
            const textures = loader.load_all_images(value.path, self.allocator) 
            catch return GameError.Load;
            self.animations.put(entry.key_ptr.*, Animation.init(textures, value.animation_duration, value.loop))
            catch return GameError.Load;
        }
    }

    fn update_camera(self: *Self, player: *PhysicEntity) void {
        const texture = self.display.texture;
        const p_rect = player.as_rect();
        const center = Vec2(p_rect.width / 2 + p_rect.x, p_rect.height / 2 + p_rect.y);
        self.camera_offset.x += @divTrunc((center.x - @as(f32, @floatFromInt(texture.width)) / 2.0 - self.camera_offset.x), 18);
        self.camera_offset.y += @divTrunc((center.y - @as(f32, @floatFromInt(texture.height)) / 2.0 - self.camera_offset.y), 18);
    }

    fn unload_assets(self: *Self) void {
        var i_value_iter = self.individual_assets.valueIterator();
        while (i_value_iter.next()) |value| {
            raylib.UnloadTexture(value.*);
        }

        self.individual_assets.deinit();

        var value_iter = self.assets.valueIterator();
        while (value_iter.next()) |value| {
            for (value.items) |texture| {
                raylib.UnloadTexture(texture.texture);
            }
            value.deinit();
        }

        self.assets.deinit();
    }

    fn unload_animations(self: *Self) void {
        var value_iter = self.animations.valueIterator();
        while (value_iter.next()) |value| {
            value.deinit();
        }
    }

    pub fn close(self: *Self) void {
        self.unload_assets();
        self.unload_animations();
        raylib.UnloadRenderTexture(self.display);
        raylib.CloseWindow();
    }
};

const AssetTemplate = struct {
    const Self = @This();
    path: []const u8,
    is_many: bool,

    pub fn init(path: []const u8, is_many: bool) Self {
        return Self {
            .path = path,
            .is_many = is_many,
        };
    }
};

const AnimationTemplate = struct {
    const Self = @This();
    path: []const u8,
    animation_duration: usize,
    loop: bool,

    pub fn init(path: []const u8, animation: usize, loop: bool) Self {
        return Self {
            .path = path,
            .animation_duration = animation,
            .loop= loop,
        };
    }
};
