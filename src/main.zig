const std = @import("std");
const zcon = @import("zcon");
const search = @import("search.zig");
const Position = @import("Position.zig");
const Game = @import("Game.zig");
const COLS = @import("types.zig").COLS;

var position = Position.init(.red);
var search_options: search.SearchOptions = .{
    .target_depth = 8,
};
var stats: bool = false;
var per_move: bool = false;
var line: ?i32 = null;
var affiliation: @import("types.zig").Affiliation = .red;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var writer = zcon.Writer.init();
    defer writer.flush();
    defer writer.useDefaultColors();

    var cli = try zcon.Cli.init(allocator, &writer, option, input);
    defer cli.deinit();

    cli.help_callback = help;

    try cli.addOption(.{
        .alias_long = "position",
        .alias_short = "",
        .desc = "loads initial position from #dgry<FEN>#prv",
        .help = "RIP",
        .arguments = "#dgry<FEN>#prv",
    });

    try cli.addOption(.{
        .alias_long = "stats",
        .alias_short = "",
        .desc = "diplays statistics of performing a search on provided position",
        .help = "RIP",
        .arguments = "",
    });

    try cli.addOption(.{
        .alias_long = "per-move",
        .alias_short = "",
        .desc = "if `--stats` is present, display eval for every move in position",
        .help = "RIP",
        .arguments = "",
    });

    try cli.addOption(.{
        .alias_long = "line",
        .alias_short = "",
        .desc = "if `--stats` is present, display next <NUM> best moves for red and yellow",
        .help = "RIP",
        .arguments = "#dgry<NUM>#prv",
    });

    try cli.addOption(.{
        .alias_long = "depth",
        .alias_short = "d",
        .desc = "sets desired search depth",
        .help = "RIP",
        .arguments = "#dgry<D>#prv",
    });

    try cli.addOption(.{
        .alias_long = "iterative-deepening",
        .alias_short = "",
        .desc = "use iterative deepening",
        .help = "RIP",
        .arguments = "",
    });

    try cli.addOption(.{
        .alias_long = "timeout",
        .alias_short = "t",
        .desc = "max amount of time in seconds search should take\nif iterative deepening is off and timeout is reached no move will be returned",
        .help = "RIP",
        .arguments = "#dgry<SEC>#prv",
    });

    try cli.addOption(.{
        .alias_long = "window",
        .alias_short = "w",
        .desc = "sets the aspiration window for iterative deepening. #dgry<WIN>#prv should be an integer, or `off` to disable aspiration windows",
        .help = "RIP",
        .arguments = "#dgry<WIN>#prv",
    });

    try cli.addOption(.{
        .alias_long = "disable-alphabeta",
        .alias_short = "",
        .desc = "disables alpha beta pruning, not recomended, just to compare search times",
        .help = "RIP",
        .arguments = "",
    });

    try cli.addOption(.{
        .alias_long = "disable-transpositions",
        .alias_short = "",
        .desc = "disables use of transposition tables, not recomended, just to compare search times",
        .help = "RIP",
        .arguments = "",
    });

    try cli.addOption(.{
        .alias_long = "disable-victory-early-outs",
        .alias_short = "",
        .desc = "disables victory early outs, not recomended, just to compare search times\nThis is when a branch is abanded when a victory in another branch is found to be gaurenteed better than the current branch",
        .help = "RIP",
        .arguments = "",
    });

    try cli.addOption(.{
        .alias_long = "affiliation",
        .alias_short = "a",
        .desc = "sets pieces to play as, #dgry<COL>#prv; must be `red` or `yellow`. red by default",
        .help = "RIP",
        .arguments = "#dgry<COL>#prv",
    });

    if (!try cli.parse()) {
        return;
    }

    if (stats) {
        const results = search.search(&position, search_options);
        writer.fmt("\n{:.2}\n", .{results});

        if (per_move) {
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

                if (line) |count| {
                    printLine(&writer, count, col);
                } // "r:/yy/yrrr/ryry//yrr/ryy"

                else writer.put("\n");
            }
        } else if (line) |count| {
            printLine(&writer, count, results.move);
        }
    } else {
        var game = Game.init(position, search_options, affiliation);
        try game.run(&writer);
    }
}

fn printLine(writer: *zcon.Writer, count: i32, col: ?usize) void {
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

        const result = search.search(&duped_position, .{ .target_depth = search_options.target_depth - left - 1 });
        move = result.move;
    }
    writer.put("\n");
}

fn option(cli: *zcon.Cli) !bool {
    if (cli.isArg("position")) {
        const fen = try cli.readArg([]const u8) orelse return false;
        position = try Position.fromFen(fen);
    } else if (cli.isArg("stats")) {
        stats = true;
    } else if (cli.isArg("per-move")) {
        per_move = true;
    } else if (cli.isArg("line")) {
        const num = try cli.readArg(i32) orelse return false;
        line = num;
    } else if (cli.isArg("depth")) {
        search_options.target_depth = try cli.readArg(i32) orelse return false;
    } else if (cli.isArg("iterative-deepening")) {
        search_options.iterative_deepening = true;
    } else if (cli.isArg("timeout")) {
        const sec = try cli.readArg(f64) orelse return false;
        search_options.timeout = @floatToInt(u64, sec * std.time.ns_per_s);
    } else if (cli.isArg("disable-alphabeta")) {
        search_options.alphabeta_pruning = false;
    } else if (cli.isArg("disable-transpositions")) {
        search_options.transposition_table = false;
    } else if (cli.isArg("disable-victory-early-outs")) {
        search_options.victory_early_out = false;
    } else if (cli.isArg("window")) {
        const win_str = try cli.readArg([]const u8) orelse return false;
        if (std.mem.eql(u8, win_str, "off"))
            search_options.aspiration_window = null
        else {
            const win = std.fmt.parseInt(i32, win_str, 10) catch {
                cli.writer.put("expected arg to '--window' to be `off` or an integer\n");
                return false;
            };
            search_options.aspiration_window = win;
        }
    } else if (cli.isArg("affiliation")) {
        const arg = try cli.readArg([]const u8) orelse return false;
        if (std.mem.eql(u8, arg, "red"))
            affiliation = .red
        else if (std.mem.eql(u8, arg, "yellow"))
            affiliation = .yellow
        else {
            cli.writer.fmt("invalid affiliation `{s}`, expected `red` or `yellow`", .{arg});
            return false;
        }
    }

    return true;
}

fn input(cli: *zcon.Cli) !bool {
    cli.writer.fmt("\n  unexpected arg '{s}'\n", .{cli.current_arg});
    return false;
}

fn help(cli: *zcon.Cli) !bool {
    cli.writer.put("\nConnect4\n\n#yel Options#prv\n");
    cli.writer.indent(1);
    cli.printOptionHelp();
    cli.writer.unindent(1);
    cli.writer.putChar('\n');
    return false;
}
