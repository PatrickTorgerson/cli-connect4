// ********************************************************************************
//! https://github.com/PatrickTorgerson/connect4
//! Copyright (c) 2024 Patrick Torgerson
//! MIT license, see LICENSE for more information
// ********************************************************************************

const std = @import("std");
const zcon = @import("zcon");
const parsley = @import("parsley");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var writer = zcon.Writer.init();
    defer writer.flush();
    defer writer.useDefaultColors();

    writer.putRaw("\n");
    defer writer.putRaw("\n");

    try parsley.executeCommandLine(void, undefined, allocator, &writer, &.{
        @import("Play.zig"),
        @import("Analyze.zig"),
    }, .{
        .command_descriptions = command_descriptions,
        .help_header_fmt = "#byel;:: {s} ::#prv;\n\n",
        .help_option_description_fmt = "\n    #dgry;{s}#prv;\n",
        .help_option_argument_fmt = "#i;{s}#i:off; ",
    });
}

const command_descriptions = &[_]parsley.CommandDescription{.{
    .command_sequence = "",
    .line = "not used",
    .full =
    \\ Play Connect 4 against a computer! Can you win?
    ,
}};
