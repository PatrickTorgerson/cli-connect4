// ********************************************************************************
//! https://github.com/PatrickTorgerson/connect4
//! Copyright (c) 2024 Patrick Torgerson
//! MIT license, see LICENSE for more information
// ********************************************************************************

const std = @import("std");
const zcon = @import("zcon");
const parsley = @import("parsley");
const search = @import("search.zig");
const Position = @import("Position.zig");
const Game = @import("Game.zig");
const Affiliation = @import("types.zig").Affiliation;

pub const command_sequence = "play";
pub const description_line = "start a game against the CPU, good luck!";
pub const description_full = description_line;
pub const positionals = &[_]parsley.Positional{};

pub fn run(
    _: *void,
    _: std.mem.Allocator,
    writer: *zcon.Writer,
    _: parsley.Positionals(@This()),
    opts: parsley.Options(@This()),
) anyerror!void {
    const position = if (opts.position) |fen|
        try Position.fromFen(fen)
    else
        Position.init(.red);
    const search_options: search.SearchOptions = .{
        .target_depth = @intCast(opts.depth orelse 8),
        .iterative_deepening = opts.@"iterative-deepening".present,
        .timeout = if (opts.timeout) |t| @intFromFloat(t * std.time.ns_per_s) else null,
        .alphabeta_pruning = !opts.@"disable-alphabeta",
        .transposition_table = !opts.@"disable-transpositions",
        .victory_early_out = !opts.@"disable-victory-early-outs",
        .aspiration_window = if (opts.@"disable-window")
            null
        else
            @intCast(opts.@"iterative-deepening".value orelse 15),
    };
    const affiliation: Affiliation = parseAffiliation(opts.affiliation) orelse .red;

    var game = Game.init(position, search_options, affiliation);
    try game.run(writer);
}

fn parseAffiliation(affiliation_str: ?[]const u8) ?Affiliation {
    if (affiliation_str) |str| {
        if (std.mem.eql(u8, str, "red")) return .red;
        if (std.mem.eql(u8, str, "yellow")) return .red;
    }
    return null;
}

pub const options = &[_]parsley.Option{
    .{
        .name = "affiliation",
        .name_short = 'a',
        .description = "specify the color to play as, #red;red#prv; or #yel;yellow#prv;",
        .arguments = &[_]parsley.Argument{.string},
    },
    .{
        .name = "position",
        .name_short = 'p',
        .description = "specify a starting position in the format '[ry]:((r|y){0,7}/){5}((r|y){0,7})'\n" ++
            " * preceeding `r:` or `y:` specifies the color to move next\n" ++
            " * pieces are specified by column, bottom to top, deliminated by a '/'" ++
            " * a column cannot have more than 6 pieces\n" ++
            " * if a column fewer empty spaces will be left at the top\n" ++
            " * all '/' must be present even with empty columns, there should be 6\n" ++
            " * example, 'r://////' is the starting position\n" ++
            " * example, 'y:/r/ry/r//yyr/', it's yellows turn but no matter their move, red will win on 0 or 4",
        .arguments = &[_]parsley.Argument{.string},
    },
} ++ @import("search_option_cli.zig").options;
