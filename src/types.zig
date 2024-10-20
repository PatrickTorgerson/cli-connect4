const std = @import("std");

pub const ROWS = 6;
pub const COLS = 7;
pub const CELL_COUNT = ROWS * COLS;
pub const IN_A_ROW = 4;

pub const Affiliation = enum(u1) {
    red = 0,
    yellow,

    pub fn opponent(affiliation: Affiliation) Affiliation {
        return switch (affiliation) {
            .red => .yellow,
            .yellow => .red,
        };
    }

    pub fn asPiece(affiliation: Affiliation) Piece {
        return @enumFromInt(@intFromEnum(affiliation));
    }

    pub fn alliedBias(affiliation: Affiliation, other: Affiliation) i32 {
        return if (affiliation == other)
            1
        else
            -1;
    }
};

pub const Piece = enum(u3) {
    red = 0,
    yellow,
    offboard,
    empty,

    pub fn getAffiliation(piece: Piece) ?Affiliation {
        return switch (piece) {
            .red => Affiliation.red,
            .yellow => Affiliation.yellow,
            else => null,
        };
    }
};

pub const Direction = enum(u8) {
    north = 0,
    south,
    east,
    west,
    north_east,
    north_west,
    south_east,
    south_west,

    pub const offsets = [8]isize{
        -1,
        1,
        ROWS,
        -ROWS,
        ROWS - 1,
        -ROWS - 1,
        ROWS + 1,
        -ROWS + 1,
    };

    pub fn offset(dir: Direction) isize {
        return offsets[dir.asUsize()];
    }

    pub fn asUsize(dir: Direction) usize {
        return @intCast(@intFromEnum(dir));
    }

    pub fn reverse(dir: Direction) Direction {
        return switch (dir) {
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
            .north_east => .south_west,
            .north_west => .south_east,
            .south_east => .north_west,
            .south_west => .north_east,
        };
    }
};
