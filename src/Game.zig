const std = @import("std");

const zcon = @import("zcon");

const types = @import("types.zig");
const search = @import("search.zig");
const Position = @import("Position.zig");
const Direction = types.Direction;
const Piece = types.Piece;
const Affiliation = types.Affiliation;

const ROWS = types.ROWS;
const COLS = types.COLS;

position: Position,
affiliation: Affiliation,
search_options: search.SearchOptions,
input_buffer: [256]u8 = undefined,

pub fn init(position: Position, search_options: search.SearchOptions, affiliation: Affiliation) @This() {
    return .{
        .position = position,
        .search_options = search_options,
        .affiliation = affiliation,
    };
}

pub fn run(this: *@This(), writer: *zcon.Writer) !void {
    writer.fmt("\nConnect4 :: q to exit", .{});
    writer.indent(1);
    writer.put("\n\n");

    primeBuffer(writer);
    writer.cursorUp(ROWS + 5);
    writer.saveCursor();

    while (true) {
        writer.restoreCursor();
        try this.drawPosition(writer);

        if (this.position.isDraw()) {
            writer.put("\n");
            writer.clearLine();
            writer.put("#byel DRAW! #prv\n");
            break;
        }

        if (this.position.findWinner()) |winner| {
            writer.put("\n");
            writer.clearLine();
            if (winner == this.affiliation)
                writer.put("\x1b[5m#grn YOU WIN! #prv\n")
            else
                writer.put("\x1b[5m#red YOU LOSE! #prv\n");
            break;
        }

        if (this.position.side_to_move == this.affiliation) {
            writer.put("\n");
            writer.clearLine();
            writer.put("#def \x1b[3m your move: #def");
            writer.flush();

            const count = try std.io.getStdIn().read(&this.input_buffer) - 2;
            if (std.mem.eql(u8, this.input_buffer[0..count], "q"))
                break;

            if (std.mem.eql(u8, this.input_buffer[0..count], "ai")) {
                const search_results = search.search(&this.position, this.search_options);
                if (search_results.move) |ai_move|
                    this.position.makeMove(ai_move) catch continue
                else {
                    writer.put("\n\n#red failed to find move #prv\n");
                    break;
                }
            } else {
                const col = std.fmt.parseInt(usize, this.input_buffer[0..count], 10) catch continue;
                this.position.makeMove(col) catch continue;
            }
        } else {
            const search_results = search.search(&this.position, this.search_options);
            if (search_results.move) |ai_move|
                this.position.makeMove(ai_move) catch continue
            else {
                writer.put("\n\n#red failed to find move #prv\n");
                break;
            }
        }
    }

    writer.putChar('\n');
}

fn drawPosition(this: *@This(), writer: *zcon.Writer) !void {
    writer.clearLine();
    const eval = search.search(&this.position, .{ .target_depth = 6 }).eval;
    if (eval >= 0)
        writer.fmt("#dgry eval: +{}\n", .{eval})
    else
        writer.fmt("#dgry eval: {}\n", .{eval});

    var draw_row: usize = 0;
    while (draw_row < ROWS) : (draw_row += 1) {
        var draw_col: usize = 0;
        while (draw_col < COLS) : (draw_col += 1) {
            const index = draw_col * ROWS + draw_row;
            switch (this.position.pieces[index]) {
                .red => writer.put("#red O"),
                .yellow => writer.put("#yel O"),
                .empty => writer.put("#dgry ."),
                .offboard => {},
            }
            writer.putChar(' ');
        }
        writer.put("\n");
    }

    writer.put("#dgry");
    writer.put("    #dgry");
    var col: usize = 0;
    while (col < COLS) : (col += 1) {
        writer.fmt("{} ", .{col});
    }
    writer.put("\n");
}

fn primeBuffer(writer: *zcon.Writer) void {
    var row: i32 = 0;
    while (row < ROWS + 5) : (row += 1) {
        writer.putRaw("                           \n");
    }
}
