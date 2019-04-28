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

const PrisonnerCount: u32 = 100;
const strategy = first_strategy;
const SimCount: f32 = 3000.0;

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

const first_strategy = struct {
    Counter: counter_prisonner,
    Simples: [PrisonnerCount - 1]simple_prisonner,

    fn Init() first_strategy {
        var Result: first_strategy = undefined;
        Result.Counter = counter_prisonner.Init();

        for (Result.Simples) |*P| {
            P.* = simple_prisonner.Init();
        }

        return (Result);
    }

    fn GetPrisonners(S: *first_strategy) [PrisonnerCount]*prisonner {
        var Result: [PrisonnerCount]*prisonner = undefined;
        Result[0] = &S.Counter.Prisonner;
        for (Result[1..]) |*P, i| {
            P.* = &S.Simples[i].Prisonner;
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

fn DoSim(comptime strategy_type: type, Series: *random_series) u32 {
    var Prisonners = strategy_type.Init().GetPrisonners();
    var PrisonnerTaken = []bool{false} ** PrisonnerCount;
    var LightState = light_state.Off;
    var DayCount: u32 = 0;

    while (true) {
        var Index = RandomChoice(Series, PrisonnerCount);
        PrisonnerTaken[Index] = true;
        var Prisonner: *prisonner = Prisonners[Index];
        LightState = Prisonner.EndLightState(LightState);
        if (Prisonner.TellFinish()) {
            break;
        }
        DayCount += 1;
    }
    Assert(AllPrisonnersPassed(PrisonnerTaken));
    return (DayCount);
}

pub fn main() void {
    var Series = RandomSeed(1234, 5678);
    var SumDays: f32 = 0.0;
    var SimIndex: u32 = 0;
    while (SimIndex < @floatToInt(u32, SimCount)) {
        const DayCount = DoSim(strategy, &Series);
        //Warn("Escaped in {} days\n", DayCount);
        SumDays += @intToFloat(f32, DayCount);
        SimIndex += 1;
    }
    const Average = SumDays / SimCount;
    Warn("For {} prisonners, average is {} days\n", PrisonnerCount, Average);
}
