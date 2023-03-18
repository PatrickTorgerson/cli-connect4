const std = @import("std");
const types = @import("types.zig");
const Position = @import("Position.zig");
const Direction = types.Direction;
const Piece = types.Piece;
const Affiliation = types.Affiliation;

test "Position.evaluate()" {
    //const position = try Position.fromFen("r:yyyrrr/rr/ryy/yry/rrry//y");
}

test "Position.findWinner() : vertical" {
    const position = try Position.fromFen("r:yyyrrr/rr/ryy/yry/rrrry//y");
    try std.testing.expectEqual(@as(?Affiliation, Affiliation.red), position.findWinner());
}

test "Position.findWinner() : horizontal" {
    const position = try Position.fromFen("r:yyyrrr/rr/ryy/yry/rrry/y/y");
    try std.testing.expectEqual(@as(?Affiliation, Affiliation.yellow), position.findWinner());
}

test "Position.findWinner() : forward diagonal" {
    const position = try Position.fromFen("r:yyyrrr/rr/ryy/ryry/rrry//y");
    try std.testing.expectEqual(@as(?Affiliation, Affiliation.red), position.findWinner());
}

test "Position.findWinner() : backward diagonal" {
    const position = try Position.fromFen("r:yyyrrr/yrr/ryy/yry/rrry//y");
    try std.testing.expectEqual(@as(?Affiliation, Affiliation.yellow), position.findWinner());
}

test "Position.findWinner() : no victor" {
    const position = try Position.fromFen("r:yyyrrr/rr/ryy/yry/rrry//y");
    try std.testing.expectEqual(@as(?Affiliation, null), position.findWinner());
}

test "Position.countPieces()" {
    const position = try Position.fromFen("r:yyyrrr/rr/ryy/yry/rrry//y");
    try std.testing.expectEqual(@as(i32, 2), position.countPieces(17, .north));
    try std.testing.expectEqual(@as(i32, 3), position.countPieces(3, .south));
    try std.testing.expectEqual(@as(i32, 3), position.countPieces(17, .east));
    try std.testing.expectEqual(@as(i32, 2), position.countPieces(28, .west));

    try std.testing.expectEqual(@as(i32, 3), position.countPieces(5, .north_east));
    try std.testing.expectEqual(@as(i32, 2), position.countPieces(23, .north_west));
    try std.testing.expectEqual(@as(i32, 2), position.countPieces(15, .south_east));
    try std.testing.expectEqual(@as(i32, 1), position.countPieces(41, .south_west));
}

test "fen - empty position" {
    try std.testing.expectEqual(Position.init(.red), try Position.fromFen("r://////"));
    try std.testing.expectEqual(Position.init(.yellow), try Position.fromFen("y://////"));
}

test "fen - fromFen()" {
    const actual_position = try Position.fromFen("r:yyyrrr/rr/ryy/yry/rrry//y");
    const expected_position = comptime blk: {
        var position = Position.init(.red);
        // zig fmt: off
        position.pieces = [_]Piece{
            .yellow, .yellow, .yellow, .red,    .red,    .red,
            .empty,  .empty,  .empty,  .empty,  .red,    .red,
            .empty,  .empty,  .empty,  .red,    .yellow, .yellow,
            .empty,  .empty,  .empty,  .yellow, .red,    .yellow,
            .empty,  .empty,  .red,    .red,    .red,    .yellow,
            .empty,  .empty,  .empty,  .empty,  .empty,  .empty,
            .empty,  .empty,  .empty,  .empty,  .empty,  .yellow,
        };
        // zig fmt: on
        break :blk position;
    };
    try std.testing.expectEqual(actual_position, expected_position);
}

test "fen - error.fen_invalid_side_to_move" {
    try std.testing.expectError(error.fen_invalid_side_to_move, Position.fromFen("j://////"));
    try std.testing.expectError(error.fen_invalid_side_to_move, Position.fromFen("a://yr//y//rr"));
    try std.testing.expectError(error.fen_invalid_side_to_move, Position.fromFen("n:///y//r/"));
    try std.testing.expectError(error.fen_invalid_side_to_move, Position.fromFen("#:///r//yy/"));
    try std.testing.expectError(error.fen_invalid_side_to_move, Position.fromFen("+:/ryr///r/yy/"));
}

test "fen - error.fen_expected_colon" {
    try std.testing.expectError(error.fen_expected_colon, Position.fromFen("r //////"));
    try std.testing.expectError(error.fen_expected_colon, Position.fromFen("r /y/y/y/y/y/y"));
    try std.testing.expectError(error.fen_expected_colon, Position.fromFen("r/y/y/y/y/y/y"));
    try std.testing.expectError(error.fen_expected_colon, Position.fromFen("r#/y/y/y/y/y/y"));
    try std.testing.expectError(error.fen_expected_colon, Position.fromFen("r;/y/y/y/y/y/y"));
    try std.testing.expectError(error.fen_expected_colon, Position.fromFen("r\n/y/y/y/y/y/y"));
}

test "fen - error.fen_missing_columns" {
    try std.testing.expectError(error.fen_missing_columns, Position.fromFen("y:rr/rr/rr/rr/rr/rr"));
    try std.testing.expectError(error.fen_missing_columns, Position.fromFen("r:rr/rr/rr/rr/rr"));
    try std.testing.expectError(error.fen_missing_columns, Position.fromFen("y:rr/rr/rr/rr"));
    try std.testing.expectError(error.fen_missing_columns, Position.fromFen("r:rr/rr/rr"));
    try std.testing.expectError(error.fen_missing_columns, Position.fromFen("y:rr/rrr"));
}

test "fen - error.fen_invalid_piece" {
    try std.testing.expectError(error.fen_invalid_piece, Position.fromFen("r:rr/rr/rj/rr/rr/rr/rr"));
    try std.testing.expectError(error.fen_invalid_piece, Position.fromFen("y:rr/\nr/rr/rr/rr/rr/rr"));
    try std.testing.expectError(error.fen_invalid_piece, Position.fromFen("r:wr/rr/rr/rr/rr/rr/rw"));
    try std.testing.expectError(error.fen_invalid_piece, Position.fromFen("y:rr/rr/rr/r r/rr/rr/rr"));
    try std.testing.expectError(error.fen_invalid_piece, Position.fromFen("r::rr/rr/rr/rr/rr/rr/rr"));
}

test "fen - error.fen_minnimum_size" {
    try std.testing.expectError(error.fen_minnimum_size, Position.fromFen(""));
    try std.testing.expectError(error.fen_minnimum_size, Position.fromFen("r:"));
    try std.testing.expectError(error.fen_minnimum_size, Position.fromFen("y:/"));
    try std.testing.expectError(error.fen_minnimum_size, Position.fromFen("r:r/y"));
    try std.testing.expectError(error.fen_minnimum_size, Position.fromFen("y://"));
}

test "fen - error.fen_column_overflow" {
    try std.testing.expectError(error.fen_column_overflow, Position.fromFen("r:rrrrrry//////"));
    try std.testing.expectError(error.fen_column_overflow, Position.fromFen("r:/yyyyyyr/////"));
    try std.testing.expectError(error.fen_column_overflow, Position.fromFen("r://rrrrrrrrr////"));
    try std.testing.expectError(error.fen_column_overflow, Position.fromFen("r:///yyyyyyyy///"));
    try std.testing.expectError(error.fen_column_overflow, Position.fromFen("r:////rrrrrrrr//"));
    try std.testing.expectError(error.fen_column_overflow, Position.fromFen("r://////ryryryryry"));
}
