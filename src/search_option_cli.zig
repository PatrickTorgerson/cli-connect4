// ********************************************************************************
//! https://github.com/PatrickTorgerson/connect4
//! Copyright (c) 2024 Patrick Torgerson
//! MIT license, see LICENSE for more information
// ********************************************************************************

//   --depth, -d <N>
//   --iterative-deepening
//   --timeout, -t <N>
//   --window, -w <N>
//   --disable-alphabeta
//   --disable-transpositions
//   --disable-victory-early-outs

const parsley = @import("parsley");

pub const options = &[_]parsley.Option{
    .{
        .name = "depth",
        .name_short = 'd',
        .description = "specify desired search depth",
        .arguments = &[_]parsley.Argument{.integer},
    },
    .{
        .name = "iterative-deepening",
        .name_short = null,
        .description = "use iterative deepening. optionally provide an integer to use as the aspiration window, default is 15",
        .arguments = &[_]parsley.Argument{.optional_integer},
    },
    .{
        .name = "timeout",
        .name_short = 't',
        .description = "max amount of time in seconds search should take\nif iterative deepening is off and timeout is reached no move will be returned",
        .arguments = &[_]parsley.Argument{.floating},
    },
    .{
        .name = "disable-window",
        .name_short = null,
        .description = "disable the use of aspiration windows\ndoes nothing if '--iterative-deepening' is not present",
        .arguments = &[_]parsley.Argument{},
    },
    .{
        .name = "disable-alphabeta",
        .name_short = null,
        .description = "disables alpha beta pruning, not recomended, just to compare search times",
        .arguments = &[_]parsley.Argument{},
    },
    .{
        .name = "disable-transpositions",
        .name_short = null,
        .description = "disables use of transposition tables, not recomended, just to compare search times",
        .arguments = &[_]parsley.Argument{},
    },
    .{
        .name = "disable-victory-early-outs",
        .name_short = null,
        .description = "disables victory early outs, not recomended, just to compare search times\nThis is when a branch is abanded when a victory in another branch is found to be gaurenteed better than the current branch",
        .arguments = &[_]parsley.Argument{},
    },
};
