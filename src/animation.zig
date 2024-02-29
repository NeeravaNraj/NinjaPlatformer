const std = @import("std");
const loader = @import("loader.zig");
const Asset = loader.Asset;
const raylib = @cImport(@cInclude("raylib.h"));
const ArrayList = std.ArrayList;

pub const Animation = struct {
    const Self = @This();
    images: ArrayList(Asset),
    image_duration: usize,
    frame: usize,
    loop: bool,
    done: bool,

    pub fn init(images: ArrayList(Asset), duration: usize, loop: bool) Self {
        return Self {
            .images = images,
            .image_duration = duration,
            .frame = 0,
            .loop = loop,
            .done = false,
        };
    }

    pub fn copy(self: *Self) Self {
        return  Self.init(self.images, self.image_duration, self.loop);
    }

    pub fn update(self: *Self) void {
        if (self.loop) {
            self.frame = (self.frame + 1) % (self.image_duration * self.images.items.len);
        } else {
            if (self.frame + 1 < self.image_duration * self.images.items.len - 1) {
                self.frame += 1;
            } else {
                self.frame = self.image_duration * self.images.items.len - 1;
                self.done = true;
            }
        }
    }

    pub fn image(self: *Self) *Asset {
        const index: usize = @divTrunc(self.frame, self.image_duration);
        return &self.images.items[index];
    }

    pub fn deinit(self: *Self) void {
        for (self.images.items) |img| {
            raylib.UnloadTexture(img.texture);
        }

        self.images.deinit();
    }
};
