const std = @import("std");
const nanoid = @import("nanoid");

pub fn main() !void
{   
    // Generate seed
    var seed: [std.rand.DefaultCsprng.secret_seed_length]u8 = undefined;
    std.crypto.random.bytes(&seed);

    // Initialize the rng and allocator
    var rng = std.rand.DefaultCsprng.init(seed);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Generate a nanoid
    const result = try nanoid.generateWithAlphabet(gpa.allocator(), rng.random(), nanoid.alphabets.numbers);
    defer gpa.allocator().free(result);

    // Print it at the end
    std.log.info("Nanoid: {s}", .{result});
}