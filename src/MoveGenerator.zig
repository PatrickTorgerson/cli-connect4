const std = @import("std");

const Position = @import("Position.zig");

const COLS = @import("types.zig").COLS;

const MoveGenerator = @This();

position: *Position,
at: usize = 0,
first_move: ?usize,
skip_move: ?usize = null,

pub fn init(position: *Position, first_move: ?usize) MoveGenerator {
    return .{
        .position = position,
        .first_move = first_move,
    };
}

pub fn next(this: *MoveGenerator) ?usize {
    if (this.at >= COLS)
        return null;

    if (this.first_move) |move| {
        this.first_move = null;
        this.skip_move = move;
        return move;
    }

    // skip full columns
    while (this.position.pieces[Position.col_starts[this.at]] != .empty) {
        this.at += 1;
        if (this.at >= COLS)
            return null;
    }

    if (this.skip_move != null and this.at == this.skip_move.?) {
        this.at += 1;
        this.skip_move = null;
        return this.next();
    }

    const col = this.at;
    this.at += 1;
    return col;
}

pub fn empty(this: *MoveGenerator) bool {
    if (this.at >= COLS)
        return true;
    while (this.position.pieces[Position.col_starts[this.at]] != .empty) {
        this.at += 1;
        if (this.at >= COLS)
            return true;
    }
    return false;
}
