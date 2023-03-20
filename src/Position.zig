const std = @import("std");

const types = @import("types.zig");
const Direction = types.Direction;
const Piece = types.Piece;
const Affiliation = types.Affiliation;

const ROWS = types.ROWS;
const COLS = types.COLS;
const CELL_COUNT = types.CELL_COUNT;
const IN_A_ROW = types.IN_A_ROW;

// start indecies for each column
pub const col_starts: [COLS]usize = blk: {
    var starts: [COLS]usize = undefined;
    var col = 0;
    var start = 0;
    while (col < COLS) : (col += 1) {
        starts[col] = start;
        start += ROWS;
    }
    break :blk starts;
};

// end indecies for each column
pub const col_ends: [COLS]usize = blk: {
    var ends: [COLS]usize = undefined;
    var col = 0;
    while (col < COLS) : (col += 1) {
        ends[col] = col_starts[col] + ROWS - 1;
    }
    break :blk ends;
};

// stores number of cells to edge of board for each index in each direction
pub const num_cells_to_edge: [CELL_COUNT][8]usize = blk: {
    var num_to_edge: [CELL_COUNT][8]usize = undefined;
    var col: usize = 0;
    var row: usize = 0;
    while (row < ROWS) : (row += 1) {
        while (col < COLS) : (col += 1) {
            var north = row;
            var south = ROWS - 1 - row;
            var east = COLS - 1 - col;
            var west = col;
            const index = col * ROWS + row;
            num_to_edge[index][Direction.north.asUsize()] = north;
            num_to_edge[index][Direction.south.asUsize()] = south;
            num_to_edge[index][Direction.east.asUsize()] = east;
            num_to_edge[index][Direction.west.asUsize()] = west;
            num_to_edge[index][Direction.north_east.asUsize()] = std.math.min(north, east);
            num_to_edge[index][Direction.north_west.asUsize()] = std.math.min(north, west);
            num_to_edge[index][Direction.south_east.asUsize()] = std.math.min(south, east);
            num_to_edge[index][Direction.south_west.asUsize()] = std.math.min(south, west);
        }
        col = 0;
    }
    break :blk num_to_edge;
};

const Position = @This();

pieces: [CELL_COUNT]Piece,
side_to_move: Affiliation,

/// expects side_to_move to be .red or .yellow
pub fn init(side_to_move: Affiliation) Position {
    return .{
        .pieces = [_]Piece{.empty} ** CELL_COUNT,
        .side_to_move = side_to_move,
    };
}

/// loads position from FEN style string
/// columns formleft to right
/// side to move specified with prefix `r:` or `y:`
/// r = red piece
/// y = yellow piece
/// / = column seperator
/// unaccounted space will result in empty cell on top
/// fen for empty bord, red to move: `r://////`
/// no spaces allowed
pub fn fromFen(fen: []const u8) !Position {
    if (fen.len < COLS - 1 + 2) return error.fen_minnimum_size;
    const side_to_move: Affiliation = switch (fen[0]) {
        'r' => .red,
        'y' => .yellow,
        else => return error.fen_invalid_side_to_move,
    };
    if (fen[1] != ':')
        return error.fen_expected_colon;

    var position = Position.init(side_to_move);
    var empty = [1]u8{'/'} ** (COLS - 1);
    if (std.mem.eql(u8, fen[2..], empty[0..])) return position;

    var at: usize = 2;
    var col: usize = 0;
    while (col < COLS) : (col += 1) {
        if (at == fen.len and col == COLS - 1) {
            // emply last column
        } else if (at >= fen.len) {
            return error.fen_missing_columns;
        } else if (at < fen.len and fen[at] == '/') {
            at += 1; // empty col
        } else {
            var end: usize = at;
            while (end < fen.len and fen[end] != '/') end += 1;
            const col_fen = fen[at..end];
            if (col_fen.len > ROWS)
                return error.fen_column_overflow;
            const empties = ROWS - col_fen.len;
            var piece: usize = 0;
            while (piece < col_fen.len) : (piece += 1) {
                position.pieces[col_starts[col] + empties + piece] = switch (col_fen[piece]) {
                    'r' => .red,
                    'y' => .yellow,
                    else => return error.fen_invalid_piece,
                };
            }
            at = end + 1;
        }
    }
    return position;
}

pub fn columnFull(position: Position, col: usize) bool {
    return position.pieces[col_starts[col]] != .empty;
}

pub fn makeMove(position: *Position, col: usize) !void {
    if (col >= COLS)
        return error.column_out_of_bounds;
    if (position.columnFull(col))
        return error.play_to_full_column;
    defer position.side_to_move = position.side_to_move.opponent();
    var at = col_ends[col];
    while (at >= col_starts[col]) : (at -= 1) {
        if (position.pieces[at] == .empty) {
            position.pieces[at] = position.side_to_move.asPiece();
            return;
        }
        if (at == 0) return error.could_not_play_move;
    }
    return error.could_not_play_move;
}

pub fn unmakeMove(position: *Position, col: usize) !void {
    if (col >= COLS)
        return error.column_out_of_bounds;
    defer position.side_to_move = position.side_to_move.opponent();
    var at = col_starts[col];
    while (at <= col_ends[col]) : (at += 1) {
        if (position.pieces[at] != .empty) {
            position.pieces[at] = .empty;
            return;
        }
    }
    return error.could_not_play_move;
}

pub fn isDraw(position: Position) bool {
    var col: usize = 0;
    while (col < COLS) : (col += 1) {
        if (position.pieces[col_starts[col]] == .empty)
            return false;
    }
    return true;
}

pub fn findWinner(position: Position) ?Affiliation {
    var index: usize = 0;
    var vertical_in_a_row: i32 = 0;
    var piece = Piece.empty;
    while (index < CELL_COUNT) : (index += 1) {
        if (position.pieces[index] == .empty) {
            piece = Piece.empty;
            vertical_in_a_row = 0;
            continue;
        }

        if (position.pieces[index] == piece)
            vertical_in_a_row += 1
        else {
            piece = position.pieces[index];
            vertical_in_a_row = 1;
        }

        if (vertical_in_a_row >= IN_A_ROW)
            return piece.getAffiliation();

        // reset vertical_in_a_row count accross col boundries
        {
            var at: usize = 0;
            while (at < COLS) : (at += 1) {
                if (index == col_ends[at]) {
                    piece = Piece.empty;
                    vertical_in_a_row = 0;
                }
            }
        }

        if (position.pieceInDirection(index, Direction.west) != position.pieces[index] and position.countPieces(index, Direction.east) >= IN_A_ROW)
            return position.pieces[index].getAffiliation();
        if (position.pieceInDirection(index, Direction.south_west) != position.pieces[index] and position.countPieces(index, Direction.north_east) >= IN_A_ROW)
            return position.pieces[index].getAffiliation();
        if (position.pieceInDirection(index, Direction.north_west) != position.pieces[index] and position.countPieces(index, Direction.south_east) >= IN_A_ROW)
            return position.pieces[index].getAffiliation();
    }
    return null;
}

pub fn countPieces(position: Position, index: usize, dir: Direction) i32 {
    var at = index;
    const piece = position.pieces[at];
    if (piece == .empty) return 0;
    var count: i32 = 1; // include piece at index
    while (position.pieceInDirection(at, dir) == piece) {
        count += 1;
        at = moveIndex(at, dir);
    }
    return count;
}

pub fn pieceInDirection(position: Position, index: usize, dir: Direction) Piece {
    if (num_cells_to_edge[index][dir.asUsize()] == 0)
        return .offboard;
    return position.pieces[moveIndex(index, dir)];
}

fn moveIndex(index: usize, dir: Direction) usize {
    return @intCast(usize, @intCast(isize, index) + dir.offset());
}

pub fn hash(position: Position) u64 {
    var hasher = std.hash.Wyhash.init(0);
    std.hash.autoHash(&hasher, position);
    return hasher.final();
}
