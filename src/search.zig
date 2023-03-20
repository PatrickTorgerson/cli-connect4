const std = @import("std");

const types = @import("types.zig");
const TranspositionTable = @import("TranspositionTable.zig");
const MoveGenerator = @import("MoveGenerator.zig");
const Position = @import("Position.zig");
const Direction = types.Direction;
const Piece = types.Piece;

const ROWS = types.ROWS;
const COLS = types.COLS;
const CELL_COUNT = types.CELL_COUNT;
const IN_A_ROW = types.IN_A_ROW;

const min_int = std.math.minInt(i32) + 1;
const max_int = std.math.maxInt(i32) - 1;
const victory_score = 5000;

pub const SearchOptions = struct {
    target_depth: i32 = 1,
    iterative_deepening: bool = false,
    timeout: ?u64 = null,
    alphabeta_pruning: bool = true,
    transposition_table: bool = true,
    victory_early_out: bool = true,
    aspiration_window: ?i32 = 15,
};

pub const SearchResults = struct {
    options: SearchOptions,
    move: ?usize = null,
    depth_reached: i32 = 0,
    eval: i32 = 0,
    prunes: i32 = 0,
    nodes: i32 = 0,
    positions: i32 = 0,
    transpositions: i32 = 0,
    victory_early_outs: i32 = 0,
    window_widens: i32 = 0,
    time_ns: u64 = 0,

    pub fn format(value: SearchResults, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("Configuration #dgry;{s}#prv\n", .{fmt});

        try writer.print("    target depth: {}\n", .{value.options.target_depth});
        try writer.print("    iterative deepening: {}\n", .{value.options.iterative_deepening});
        try writer.print("    alphabeta pruning: {}\n", .{value.options.alphabeta_pruning});
        try writer.print("    use transposition table: {}\n", .{value.options.transposition_table});
        try writer.print("    use victory early outs: {}\n", .{value.options.victory_early_out});
        try writer.print("    aspiration window: {?}\n", .{value.options.aspiration_window});

        try writer.print("    timeout: ", .{});
        if (value.options.timeout) |timeout| {
            try std.fmt.formatFloatDecimal(
                @intToFloat(f64, timeout) / std.time.ns_per_s,
                options,
                writer,
            );
            try writer.writeAll("s\n");
        } else try writer.writeAll("null\n");

        try writer.print("\nResults\n", .{});

        try writer.print("    depth reached: {}\n", .{value.depth_reached});
        try writer.print("    best move: {?}\n", .{value.move});
        try writer.print("    eval: {}\n", .{value.eval});
        try writer.print("    prunes: {}\n", .{value.prunes});
        try writer.print("    nodes: {}\n", .{value.nodes});
        try writer.print("    positions: {} / {}\n", .{ value.positions, std.math.powi(u64, 7, @intCast(u64, value.options.target_depth)) catch 0 });
        try writer.print("    transpositions: {}\n", .{value.transpositions});
        try writer.print("    victory early outs: {}\n", .{value.victory_early_outs});
        try writer.print("    window widens: {}\n", .{value.window_widens});

        try writer.writeAll("\ntime: ");
        try std.fmt.formatFloatDecimal(
            @intToFloat(f64, value.time_ns) / std.time.ns_per_s,
            options,
            writer,
        );
        try writer.writeAll("s\n");
    }
};

pub const SearchNode = struct {
    alpha: i32 = min_int,
    beta: i32 = max_int,
    ply_from_root: i32 = 0,
    depth: i32,

    pub fn next(node: SearchNode, alpha: i32, beta: i32) SearchNode {
        return .{
            .alpha = -beta,
            .beta = -alpha,
            .ply_from_root = node.ply_from_root + 1,
            .depth = node.depth - 1,
        };
    }
};

const SearchState = struct {
    abort: bool = false,
    best_move_yet: ?usize = null,
    best_eval_yet: i32 = min_int,
    options: SearchOptions,
    results: SearchResults,
    timer: std.time.Timer,
    transpositions: TranspositionTable = .{},

    fn alphabeta_negamax(this: *SearchState, position: *Position, node: SearchNode) i32 {
        if (this.options.timeout != null and this.timer.read() >= this.options.timeout.?)
            this.abort = true;
        if (this.abort)
            return 0;

        var alpha = node.alpha;
        var beta = node.beta;

        // Skip this position if a win sequence has already been found earlier in
        // the search, which would be shorter than any win we could find from here.
        // This is done by observing that alpha can't possibly be worse (and likewise
        // beta can't possibly be better) than winning in the current position.
        if (this.options.victory_early_out and node.ply_from_root > 0) {
            alpha = std.math.max(alpha, -victory_score + node.ply_from_root);
            beta = std.math.min(beta, victory_score - node.ply_from_root);
            if (alpha >= beta) {
                this.results.victory_early_outs += 1;
                return alpha;
            }
        }

        // try to load position from transposition table
        if (this.transpositions.lookup(position.*)) |entry| {
            if (this.options.transposition_table and entry.depth >= node.depth) {
                switch (entry.bound) {
                    .exact => {},
                    .lower => alpha = std.math.max(alpha, entry.eval),
                    .upper => beta = std.math.min(beta, entry.eval),
                }
                if (entry.bound == .exact or alpha >= beta) {
                    this.results.transpositions += 1;
                    if (node.ply_from_root == 0) {
                        this.best_eval_yet = entry.eval;
                        this.best_move_yet = entry.move;
                    }
                    return entry.eval;
                }
            }
        }

        if (node.depth <= 0) {
            this.results.positions += 1;
            const value = evaluate(position);
            return value;
        }

        const winner = position.findWinner();
        if (winner == position.side_to_move) {
            this.results.positions += 1;
            const value = victory_score - node.ply_from_root;
            return value;
        }
        if (winner == position.side_to_move.opponent()) {
            this.results.positions += 1;
            const value = -victory_score + node.ply_from_root;
            return value;
        }

        var eval: i32 = min_int;
        var move: usize = 0;
        var move_gen = MoveGenerator.init(
            position,
            if (node.ply_from_root == 0) this.best_move_yet else null,
        );

        if (move_gen.empty()) return 0; // draw

        while (move_gen.next()) |col| {
            position.makeMove(col) catch {};
            eval = std.math.max(eval, -this.alphabeta_negamax(position, node.next(alpha, beta)));
            position.unmakeMove(col) catch {};
            this.results.nodes += 1;

            if (this.options.alphabeta_pruning and std.math.max(alpha, eval) >= beta) {
                this.results.prunes += 1;
                this.transpositions.storeLowerBound(position.*, node, col, beta);
                return beta; // prune
            }

            if (eval > alpha) {
                alpha = eval;
                move = col;
                if (node.ply_from_root == 0) {
                    this.best_eval_yet = eval;
                    this.best_move_yet = col;
                }
            }
        }

        this.transpositions.store(position.*, node, move, eval);

        return alpha;
    }
};

/// search position for side_to_move's best move
pub fn search(position: *Position, options: SearchOptions) SearchResults {
    var state = SearchState{
        .options = options,
        .results = .{ .options = options },
        // This should only fail in hostile environments such as linux seccomp misuse.
        .timer = std.time.Timer.start() catch unreachable,
    };

    if (options.target_depth <= 0) {
        state.results.eval = evaluate(position);
        return state.results;
    }

    if (options.iterative_deepening) {
        const aspiration = options.aspiration_window orelse 0;
        var alpha: i32 = min_int;
        var beta: i32 = max_int;
        var current_search_depth: i32 = 1;
        state.timer.reset();

        while (current_search_depth <= options.target_depth) {
            const eval = state.alphabeta_negamax(position, .{
                .depth = current_search_depth,
                .alpha = alpha,
                .beta = beta,
            });

            if (state.abort)
                break;

            if (options.aspiration_window) |_|
                if (eval <= alpha or eval >= beta) {
                    alpha = min_int;
                    beta = max_int;
                    state.results.window_widens += 1;
                    continue;
                } else {
                    alpha = eval - aspiration;
                    beta = eval + aspiration;
                };

            state.results.depth_reached = current_search_depth;
            state.results.move = state.best_move_yet;
            state.results.eval = std.math.max(eval, state.best_eval_yet);
            current_search_depth += 1;

            // exit search if victory encountered
            if ((std.math.absInt(state.best_eval_yet) catch max_int) > victory_score - options.target_depth)
                break;
        }
        state.results.time_ns = state.timer.read();
    } else {
        state.timer.reset();
        const eval = state.alphabeta_negamax(position, .{ .depth = options.target_depth });
        state.results.time_ns = state.timer.read();
        if (state.abort)
            return state.results;
        state.results.depth_reached = options.target_depth;
        state.results.eval = std.math.max(eval, state.best_eval_yet);
        state.results.move = state.best_move_yet;
    }

    return state.results;
}

fn evaluate(position: *Position) i32 {
    var eval: i32 = 0;
    var index: usize = 0;
    while (index < CELL_COUNT) : (index += 1) {
        if (position.pieces[index] == .empty) {
            continue;
        }

        if (position.pieceInDirection(index, .north) != position.pieces[index] and position.pieceInDirection(index, .south) == position.pieces[index])
            eval += evaluateDirection(position, index, .south);
        if (position.pieceInDirection(index, .west) != position.pieces[index] and position.pieceInDirection(index, .east) == position.pieces[index])
            eval += evaluateDirection(position, index, .east);
        if (position.pieceInDirection(index, .south_west) != position.pieces[index] and position.pieceInDirection(index, .north_east) == position.pieces[index])
            eval += evaluateDirection(position, index, .north_east);
        if (position.pieceInDirection(index, .north_west) != position.pieces[index] and position.pieceInDirection(index, .south_east) == position.pieces[index])
            eval += evaluateDirection(position, index, .south_east);
    }

    return eval;
}

fn evaluateDirection(position: *Position, index: usize, dir: Direction) i32 {
    if (position.pieces[index] == .empty) return 0;
    const piece = position.pieces[index];
    const affiliation = piece.getAffiliation().?;
    const count = position.countPieces(index, dir);

    const near_cap = position.pieceInDirection(index, dir.reverse());
    const end = @intCast(usize, @intCast(isize, index) + dir.offset() * (count - 1));
    const far_cap = position.pieceInDirection(end, dir);

    if ((near_cap == affiliation.opponent().asPiece() or near_cap == .offboard) and (far_cap == affiliation.opponent().asPiece() or far_cap == .offboard))
        return 0;

    var eval = count;
    if (near_cap == .empty)
        eval *= 2;
    if (far_cap == .empty)
        eval *= 2;
    return position.side_to_move.alliedBias(affiliation) * eval;
}
