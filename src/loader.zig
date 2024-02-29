const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const raylib = @cImport(@cInclude("raylib.h"));

pub const LoaderError = error {
    Image,
    Path,
    Allocation,
    Pattern,
    Parse
};

pub const Asset = struct {
    const Self = @This();
    index: u16,
    texture: raylib.Texture2D,

    pub fn init(name: []const u8, texture: raylib.Texture2D) LoaderError!Self {
        if (Self.find(name, '.')) |index| {
            const tile_index = std.fmt.parseInt(u16, name[0..index], 10) catch return LoaderError.Parse;
            return Self {
                .index = tile_index,
                .texture = texture,
            };
        }

        return LoaderError.Pattern;
    }

    pub fn find(source: []const u8, pattern: u8) ?usize {
        for (source, 0..) |char, i| {
            if (char == pattern) return i;
        }
        return null;
    }
};

const BASE_IMG_PATH = "src/assets/images/";

fn construct_path(path: []const u8, add_null: bool, allocator: Allocator) LoaderError!String {
    var str = String.init(BASE_IMG_PATH, allocator)
    catch return LoaderError.Allocation;
    str.push_str(path)
    catch return LoaderError.Allocation;
    if (add_null) str.push_char('\x00')
    catch return LoaderError.Allocation;
    return str;
}

fn sort_assets(textures: []Asset) void {
    for (0..textures.len) |i| {
        for (0..textures.len-i-1) |j| {
            if (textures[j].index > textures[j+1].index) {
                const current = textures[j];
                textures[j] = textures[j+1];
                textures[j+1] = current;
            }
        }
    }

}

pub fn load_image(path: []const u8, allocator: Allocator) LoaderError!raylib.Texture2D {
    var loc = try construct_path(path, true, allocator);
    defer loc.deinit();
    var img = raylib.LoadImage(loc.data);
    const color_key: u32 = 0;
    raylib.ImageColorReplace(&img, raylib.BLACK, @bitCast(color_key));
    return raylib.LoadTextureFromImage(img);
}

pub fn load_all_images(path: []const u8, allocator: Allocator) LoaderError!ArrayList(Asset) {
    var full_loc = try construct_path(path, false, allocator);
    var textures = ArrayList(Asset).init(allocator);
    var loc = String.init(
        path,
        allocator
    ) catch return LoaderError.Allocation;
    defer {
        full_loc.deinit();
        loc.deinit();
    }

    const dir = std.fs.cwd().openDir(full_loc.as_slice(), .{ .iterate = true })
    catch return LoaderError.Path;
    var dir_iter = dir.iterate();
    while (dir_iter.next() catch return LoaderError.Path) |file| {
        var image_path = loc.concat(file.name)
        catch return LoaderError.Allocation;
        // This is throw away memory
        // Freeing it is extra compute
        defer image_path.deinit();
        const texture = try load_image(image_path.as_slice(), allocator);
        const asset = try Asset.init(file.name, texture);
        textures.append(asset)
        catch return LoaderError.Allocation;
    }

    sort_assets(textures.items);
    return textures;
}

