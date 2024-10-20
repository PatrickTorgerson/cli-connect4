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
const COLS = @import("types.zig").COLS;

pub const command_sequence = "analyze";
pub const description_line = "analyze a given position";
pub const description_full = description_line;
pub const positionals = &[_]parsley.Positional{.{ "position", .string }};

pub fn run(
    _: *void,
    _: std.mem.Allocator,
    writer: *zcon.Writer,
    poss: parsley.Positionals(@This()),
    opts: parsley.Options(@This()),
) anyerror!void {
    var position = try Position.fromFen(poss.position);
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

    const results = search.search(&position, search_options);
    writer.fmt("\n{}\n", .{results});

    if (opts.@"all-moves") {
        var col: usize = 0;
        while (col < COLS) : (col += 1) {
            if (position.columnFull(col))
                continue;
            if (results.move != null and col == results.move.?)
                writer.put("#grn")
            else
                writer.put("#def");
            position.makeMove(col) catch {};
            const eval = -search.search(&position, .{ .target_depth = search_options.target_depth - 1 }).eval;
            position.unmakeMove(col) catch {};
            writer.fmt("    {}: {}", .{ col, eval });

            if (opts.line) |count| {
                printLine(writer, position, count, col, search_options.target_depth);
            } else writer.put("\n");
        }
    } else if (opts.line) |count| {
        printLine(writer, position, count, results.move, search_options.target_depth);
    }
}

fn printLine(writer: *zcon.Writer, position: Position, count: i64, col: ?usize, depth: i32) void {
    var duped_position = position;
    writer.put("#def; ; ");
    var left: i32 = 0;
    var move: ?usize = col;
    while (left < count) : (left += 1) {
        if (move == null)
            break;
        if (duped_position.side_to_move == .red)
            writer.put("#red")
        else
            writer.put("#yel");
        writer.fmt("{}#prv;, ", .{move.?});
        duped_position.makeMove(move.?) catch break;

        if (duped_position.findWinner()) |winner| {
            writer.fmt(" = #grn{s}#prv", .{@tagName(winner)});
        } else if (duped_position.isDraw()) {
            writer.fmt(" = #byel;draw #prv", .{});
        }

        const result = search.search(&duped_position, .{ .target_depth = depth - left - 1 });
        move = result.move;
    }
    writer.put("\n");
}

pub const options = &[_]parsley.Option{
    .{
        .name = "all-moves",
        .name_short = null,
        .description = "display eval for every move in position",
        .arguments = &[_]parsley.Argument{},
    },
    .{
        .name = "line",
        .name_short = null,
        .description = "display nest sequence of #dgry:<NUM>; moves for red and yellow",
        .arguments = &[_]parsley.Argument{.integer},
    },
} ++ @import("search_option_cli.zig").options;
