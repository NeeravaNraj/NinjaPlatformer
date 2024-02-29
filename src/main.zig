const std = @import("std");
const raylib = @cImport(@cInclude("raylib.h"));
const Game = @import("game.zig").Game;
const loader = @import("loader.zig");


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(gpa_allocator);
    const allocator = arena.allocator();
    var game = Game.init("ninja game", 800, 640, 60, allocator);

    defer {
        game.close();
        arena.deinit();
        std.debug.assert(gpa.deinit() == .ok);
    }

    try game.init_game();
    game.loop();
}
