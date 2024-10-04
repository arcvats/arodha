const std = @import("std");

pub const DEFAULT_MAX_REQUESTS = 10;
pub const DEFAULT_INTERVAL = 1000;
pub const DEFAULT_TIMEOUT = 60 * 1000;
pub const DEFAULT_CONSECUTIVE_FAILURES = 5;

fn readyToTrip(counters: Counters) bool {
    return counters.consecutive_failures >= DEFAULT_CONSECUTIVE_FAILURES;
}

fn isSuccessful(err: CircuitBreakerError) bool {
    return err == null;
}

// Possible states of the circuit breaker
// OPEN: The circuit breaker has tripped and is not allowing requests to pass through
// HALF_OPEN: The circuit breaker is allowing a limited number of requests to pass through
// CLOSED: The circuit breaker is allowing all requests to pass through
pub const State = enum { OPEN, HALF_OPEN, CLOSED };

// Possible errors that can be returned by the circuit breaker
pub const CircuitBreakerError = error{
    TooManyRequests,
    OpenCircuit,
};

// Configuration for the circuit breaker
// max_requests: The number of requests that can be made before the circuit breaker trips
// interval: The time interval after which the circuit breaker will check if it is ready to trip
// timeout: The time interval after which a request is considered failed
// metadata: Additional metadata that can be used to configure the circuit breaker
pub const Config = struct {
    max_requests: u32,
    interval: std.time.Milliseconds,
    timeout: std.time.Milliseconds,
    metadata: std.StringHashMap,
    readyToTrip: fn (Counters) bool,
    onStateChange: fn (State, State) void,
    isSuccessful: fn (CircuitBreakerError) bool,
};

// Counters to keep track of the number of requests, successes, and failures
// requests: The total number of requests made
// total_successes: The total number of successful requests made
// total_failures: The total number of failed requests made
// consecutive_successes: The number of consecutive successful requests made
// consecutive_failures: The number of consecutive failed requests made
pub const Counters = struct {
    requests: u32,
    total_successes: u32,
    total_failures: u32,
    consecutive_successes: u32,
    consecutive_failures: u32,

    pub fn init() Counters {
        return Counters{
            .requests = 0,
            .total_successes = 0,
            .total_failures = 0,
            .consecutive_successes = 0,
            .consecutive_failures = 0,
        };
    }

    pub fn onRequest(self: Counters) void {
        self.requests += 1;
    }

    pub fn onSuccess(self: Counters) void {
        self.total_successes += 1;
        self.consecutive_successes += 1;
        self.consecutive_failures = 0;
    }

    pub fn onFailure(self: Counters) void {
        self.total_failures += 1;
        self.consecutive_failures += 1;
        self.consecutive_successes = 0;
    }

    pub fn reset(self: Counters) void {
        self.requests = 0;
        self.total_successes = 0;
        self.total_failures = 0;
        self.consecutive_successes = 0;
        self.consecutive_failures = 0;
    }
};

pub const CircuitBreaker = struct {
    state: State,
    expiry: i64,
    counters: Counters,
    config: Config,
    mutex: std.Thread.Mutex,

    pub fn init(config: Config) CircuitBreaker {
        if (config == null) {
            config = Config{
                .max_requests = config.max_requests || DEFAULT_MAX_REQUESTS,
                .interval = config.interval || DEFAULT_INTERVAL,
                .timeout = config.timeout || DEFAULT_TIMEOUT,
                .metadata = std.StringHashMap.init,
                .readyToTrip = config.readyToTrip || readyToTrip,
                .onStateChange = config.onStateChange,
                .isSuccessful = config.isSuccessful || isSuccessful,
            };
        }
        return CircuitBreaker{
            .state = State.CLOSED,
            .expiry = 0, // FIXME: std.time.milliTimestamp() + config.interval,
            .counters = Counters.init(),
            .config = config,
            .mutex = std.Mutex.init,
        };
    }

    fn setState(self: CircuitBreaker, state: State, now: i64) void {
        if (self.state == state) {
            return;
        }

        const previous = self.state;
        self.state = state;

        if (self.onStateChange != null) {
            self.onStateChange(previous, state);
        }
    }

    fn currentState(self: CircuitBreaker, now: i64) State {
        // std.time.milliTimestamp()
        switch (self.state) {
            State.OPEN => {
                if (now >= self.expiry) {
                    return State.HALF_OPEN;
                }
            },
            State.HALF_OPEN => {
                if (self.config.readyToTrip(self.counters)) {
                    return State.OPEN;
                }
            },
            else => {},
        }
        return self.state;
    }

    pub fn getCurrentState(self: CircuitBreaker) State {
        return self.state;
    }
};
