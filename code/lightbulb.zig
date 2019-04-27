const std = @import("std");
const Warn = std.debug.warn;
const Assert = std.debug.assert;
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

const prisonner = struct {
    TellFinishInternal: fn (*prisonner) bool,
    EndLightStateInternal: fn (*prisonner, light_state) light_state,

    fn TellFinish(P: *prisonner) bool {
        return (P.TellFinishInternal(P));
    }

    fn EndLightState(P: *prisonner, L: light_state) light_state {
        return (P.EndLightStateInternal(P, L));
    }
};

fn AllPrisonnersPassed(P: [PrisonnerCount]bool) bool {
    for (P) |HasBeenOut| {
        if (!HasBeenOut) {
            return (false);
        }
    }
    return (true);
}

const strategy = struct {
    Prisonners: [PrisonnerCount]*prisonner,
};

const first_strategy = struct {
    S: strategy,

    fn Init() first_strategy {
        return first_strategy{
            .S = strategy{
                .Prisonners = InitPrisonners(),
            },
        };
    }

    fn InitPrisonners() [PrisonnerCount]*prisonner {
        // TODO(hugo): can I use a FixedBuffer allocator since the whole size required is known at compile time ?
        // TODO(hugo): Deallocate the prisonners in order to do several sim.
        const Alloc = &std.heap.DirectAllocator.init().allocator;
        var Result: [PrisonnerCount]*prisonner = undefined;

        var Counter: *counter_prisonner = &(Alloc.alloc(counter_prisonner, 1) catch unreachable)[0];
        Counter.* = counter_prisonner.Init();
        Result[0] = &Counter.Prisonner;

        var Simple: []simple_prisonner = Alloc.alloc(simple_prisonner, PrisonnerCount - 1) catch unreachable;
        for (Result[1..]) |*P, i| {
            Simple[i] = simple_prisonner.Init();
            P.* = &Simple[i].Prisonner;
        }

        return (Result);
    }

    const counter_prisonner = struct {
        Prisonner: prisonner,
        Count: u32,

        fn Init() counter_prisonner {
            return counter_prisonner{
                .Prisonner = prisonner{
                    .TellFinishInternal = TellFinish,
                    .EndLightStateInternal = EndLightState,
                },
                .Count = 0,
            };
        }

        fn TellFinish(P: *prisonner) bool {
            const Self = @fieldParentPtr(counter_prisonner, "Prisonner", P);
            return (Self.Count == (PrisonnerCount - 1));
        }

        fn EndLightState(P: *prisonner, L: light_state) light_state {
            var Self = @fieldParentPtr(counter_prisonner, "Prisonner", P);
            if (L == light_state.On) {
                Self.Count += 1;
                //Warn("Count is {}.\n", Self.Count);
            }
            return (light_state.Off);
        }
    };

    const simple_prisonner = struct {
        Prisonner: prisonner,
        HasMarked: bool,

        fn Init() simple_prisonner {
            return simple_prisonner{
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
            var Self = @fieldParentPtr(simple_prisonner, "Prisonner", P);
            if (L == light_state.Off and !Self.HasMarked) {
                Self.HasMarked = true;
                return (light_state.On);
            }
            return (L);
        }
    };
};

fn DoSim(S: *strategy) void {
    var PrisonnerTaken = []bool{false} ** PrisonnerCount;
    var LightState = light_state.Off;
    var Series = RandomSeed(1234, 5678);
    var DayCount: u32 = 0;

    var Prisonners = S.Prisonners;
    while (true) {
        var Index = RandomChoice(&Series, PrisonnerCount);
        PrisonnerTaken[Index] = true;
        var Prisonner: *prisonner = Prisonners[Index];
        LightState = Prisonner.EndLightState(LightState);
        if (Prisonner.TellFinish()) {
            break;
        }
        DayCount += 1;
    }
    Assert(AllPrisonnersPassed(PrisonnerTaken));
    Warn("Escaped in {} days\n", DayCount);
}

pub fn main() void {
    var Strat = first_strategy.Init().S;
    DoSim(&Strat);
}
