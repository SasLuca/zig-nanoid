const std = @import("std");
const nanoid = @import("nanoid");

pub fn main() !void
{   
    const result = nanoid.generateWithAlphabet(std.crypto.random, nanoid.alphabets.numbers);

    std.log.info("Nanoid: {s}", .{result});
}