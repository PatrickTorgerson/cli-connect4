const std = @import("std");

const Position = @import("Position.zig");
const SearchNode = @import("search.zig").SearchNode;

const Entry = struct {
    hash: u64 = 0,
    move: usize = 0,
    eval: i32 = 0,
    depth: i32 = 0,
    bound: enum { exact, upper, lower } = .exact,
};

const TranspositionTable = @This();
const MAX_ENTRIES = 1024;

entries: [MAX_ENTRIES]Entry = [_]Entry{.{}} ** MAX_ENTRIES,

pub fn store(this: *TranspositionTable, position: Position, node: SearchNode, move: usize, eval: i32) void {
    const entry = Entry{
        .hash = position.hash(),
        .move = move,
        .eval = eval,
        .depth = node.depth,
        .bound = if (eval <= node.alpha)
            .upper
        else if (eval >= node.beta)
            .lower
        else
            .exact,
    };
    const at = TranspositionTable.index(entry.hash);
    if (this.entries[at].hash == 0 or this.shouldReplace(at, entry))
        this.entries[at] = entry;
}

pub fn storeLowerBound(this: *TranspositionTable, position: Position, node: SearchNode, move: usize, eval: i32) void {
    const entry = Entry{
        .hash = position.hash(),
        .move = move,
        .eval = eval,
        .depth = node.depth,
        .bound = .lower,
    };
    const at = TranspositionTable.index(entry.hash);
    if (this.entries[at].hash == 0 or this.shouldReplace(at, entry))
        this.entries[at] = entry;
}

pub fn lookup(this: TranspositionTable, position: Position) ?Entry {
    const hash = position.hash();
    const at = TranspositionTable.index(hash);
    if (this.entries[at].hash == hash)
        return this.entries[at]
    else
        return null;
}

fn shouldReplace(this: TranspositionTable, at: usize, with: Entry) bool {
    _ = this;
    _ = at;
    _ = with;
    return true;
}

fn index(hash: u64) usize {
    return hash % MAX_ENTRIES;
}
