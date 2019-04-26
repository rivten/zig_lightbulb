const std = @import("std");
const warn = std.debug.warn;
const allocator = std.mem.Allocator;

const random_series = struct {
    Alpha: u64,
    Beta: u64,
};

fn RandomSeed(Alpha: u64, Beta: u64) random_series {
    const Series = random_series{ .Alpha = Alpha, .Beta = Beta };
    return (Series);
}

fn RotateLeft(Value: u64, Rotate: u6) u64 {
    if (Rotate == 0) {
        return (Value);
    } else {
        return ((Value << Rotate) | (Value >> (0b111111 - (Rotate - 1))));
    }
}

fn RandomNextU64(Series: *random_series) u64 {
    var Alpha = Series.Alpha;
    var Beta = Series.Beta;
    var Result: u64 = 0;
    _ = @addWithOverflow(u64, Alpha, Beta, &Result);

    Beta = Beta ^ Alpha;
    Series.Alpha = RotateLeft(Alpha, 24) ^ Beta ^ (Beta << 16);
    Series.Beta = RotateLeft(Beta, 37);

    return (Result);
}

fn RandomNextU32(Series: *random_series) u32 {
    var NextU64 = RandomNextU64(Series);
    var Result = @truncate(u32, NextU64 >> 32);
    return (Result);
}

fn RandomChoice(Series: *random_series, ChoiceCount: u32) u32 {
    var Result = (RandomNextU32(Series) % ChoiceCount);
    return (Result);
}

test "xoroshiro" {
    var Series = RandomSeed(1234, 5678);
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const RandomValue = RandomChoice(&Series, 100);
        warn("{}\n", RandomValue);
    }
}

const PrisonnerCount = 100;

const light_state = enum {
    On,
    Off,
};

const prisonner_state = struct {};

const prisonner = struct {
    TellFinishInternal: fn (*prisonner) bool,
    EndLightStateInternal: fn (*prisonner, light_state) light_state,

    fn TellFinish(Self: *prisonner) bool {
        return (Self.TellFinishInternal(Self));
    }

    fn EndLightState(Self: *prisonner, L: light_state) light_state {
        return (Self.EndLightStateInternal(Self, L));
    }
};

const first_strat_counter_prisonner = struct {
    Prisonner: prisonner,
    Count: u32,

    fn Init() first_strat_counter_prisonner {
        return first_strat_counter_prisonner{
            .Prisonner = prisonner{
                .TellFinishInternal = TellFinish,
                .EndLightStateInternal = EndLightState,
            },
            .Count = 0,
        };
    }

    fn TellFinish(P: *prisonner) bool {
        const Self = @fieldParentPtr(first_strat_counter_prisonner, "Prisonner", P);
        return (Self.Count == (PrisonnerCount - 1));
    }

    fn EndLightState(P: *prisonner, L: light_state) light_state {
        var Self = @fieldParentPtr(first_strat_counter_prisonner, "Prisonner", P);
        if (L == light_state.On) {
            Self.Count += 1;
            warn("Count is {}.\n", Self.Count);
        }
        return (light_state.Off);
    }
};

const first_strat_simple_prisonner = struct {
    Prisonner: prisonner,
    HasMarked: bool,

    fn Init() first_strat_simple_prisonner {
        return first_strat_simple_prisonner{
            .Prisonner = prisonner{
                .TellFinishInternal = TellFinish,
                .EndLightStateInternal = EndLightState,
            },
            .HasMarked = false,
        };
    }

    fn TellFinish(P: *prisonner) bool {
        return (false);
    }

    fn EndLightState(P: *prisonner, L: light_state) light_state {
        var Self = @fieldParentPtr(first_strat_simple_prisonner, "Prisonner", P);
        if (L == light_state.Off and !Self.HasMarked) {
            Self.HasMarked = true;
            return (light_state.On);
        }
        return (L);
    }
};

pub fn main() void {
    var Buffer: [1024]u8 = undefined;
    const Alloc = &std.heap.FixedBufferAllocator.init(&Buffer).allocator;

    var PrisonnerTaken = []bool{false} ** PrisonnerCount;
    var LightState = light_state.Off;
    var Series = RandomSeed(1234, 5678);
    var DayCount: u32 = 0;

    var Prisonners = init: {
        var InitPris: [PrisonnerCount]prisonner = undefined;
        InitPris[0] = first_strat_counter_prisonner.Init().Prisonner;
        for (InitPris[1..]) |*p| {
            p.* = first_strat_simple_prisonner.Init().Prisonner;
        }
        break :init InitPris;
    };
    while (true) {
        var Index = RandomChoice(&Series, PrisonnerCount);
        PrisonnerTaken[Index] = true;
        var Prisonner: *prisonner = &Prisonners[Index];
        LightState = Prisonner.EndLightState(LightState);
        if (Prisonner.TellFinish()) {
            break;
        }
        DayCount += 1;
    }
    warn("Escaped in {} days\n", DayCount);
}
