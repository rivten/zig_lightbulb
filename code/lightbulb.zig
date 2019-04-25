const std = @import("std");
const warn = std.debug.warn;

const prisonner = struct {};

const PrisonnerCount = 100;

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

pub fn main() !void {
    var stdout = try std.io.getStdOut();
    try stdout.write("Hello world!\n");

    var PrisonnerTaken = []bool{false} ** PrisonnerCount;
    var Series = RandomSeed(1234, 5678);
}
