const std = @import("std");
const testing = std.testing;
const arodha = @import("./arodha.zig");

test "RequestStates init" {
    const states = arodha.RequestStates.init();

    try testing.expectEqual(states.requests, 0);
    try testing.expectEqual(states.total_successes, 0);
    try testing.expectEqual(states.total_failures, 0);
    try testing.expectEqual(states.consecutive_successes, 0);
    try testing.expectEqual(states.consecutive_failures, 0);
}

test "RequestStates onRequest" {
    var states = arodha.RequestStates.init();
    states.onRequest();

    try testing.expectEqual(states.requests, 1);
    try testing.expectEqual(states.total_successes, 0);
    try testing.expectEqual(states.total_failures, 0);
    try testing.expectEqual(states.consecutive_successes, 0);
    try testing.expectEqual(states.consecutive_failures, 0);
}

test "RequestStates onSuccess" {
    var states = arodha.RequestStates.init();
    states.onSuccess();

    try testing.expectEqual(states.requests, 0);
    try testing.expectEqual(states.total_successes, 1);
    try testing.expectEqual(states.total_failures, 0);
    try testing.expectEqual(states.consecutive_successes, 1);
    try testing.expectEqual(states.consecutive_failures, 0);
}

test "RequestStates onFailure" {
    var states = arodha.RequestStates.init();
    states.onFailure();

    try testing.expectEqual(states.requests, 0);
    try testing.expectEqual(states.total_successes, 0);
    try testing.expectEqual(states.total_failures, 1);
    try testing.expectEqual(states.consecutive_successes, 0);
    try testing.expectEqual(states.consecutive_failures, 1);
}

test "RequestStates reset" {
    var states = arodha.RequestStates.init();
    states.onRequest();
    states.onSuccess();
    states.onFailure();
    states.reset();

    try testing.expectEqual(states.requests, 0);
    try testing.expectEqual(states.total_successes, 0);
    try testing.expectEqual(states.total_failures, 0);
    try testing.expectEqual(states.consecutive_successes, 0);
    try testing.expectEqual(states.consecutive_failures, 0);
}
