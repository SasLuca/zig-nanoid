const std = @import("std");
const nanoid = @import("nanoid");

pub fn main() !void
{   
    const result = nanoid.generate(std.crypto.random);
    
    std.log.info("Nanoid: {s}", .{result});
}