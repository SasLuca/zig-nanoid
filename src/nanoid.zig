const std = @import("std");

/// URL friendly characters used by the default generate procedure.
pub const default_alphabet = "_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

/// The default size of the generated id.
pub const default_id_len = 21;

/// The computed mask for the default alphabet size.
pub const default_mask = computeMask(default_alphabet.len);

/// The computed size necessary for a buffer which can hold the random bytes in a step of the nanoid generation algorithm given the default mask, id size and alphabet.
pub const default_rng_step_buffer_len = computeRngStepSize(default_mask, default_id_len, default_alphabet.len);

/// The maximum size of the alphabet accepted by the nanoid algorithm.
pub const max_alphabet_len: u8 = 255;

/// An error union of Nanoid specific errors.
pub const NanoidError = error
{
    /// The alphabet size is not within the accepted range (0, alphabet_max_size).
    InvalidAlphabetSize,

    /// The size of the provided result buffer is not within an acceptable range.
    InvalidResultBufferSize
};

/// An error union of all possible errors that can be returned by a procedure in this library.
pub const Error = std.mem.Allocator.Error || NanoidError;

/// Computes the mask necessary for the nanoid algorithm given an alphabet size.
/// The mask is used to transform a random byte into an index into an array of size `alphabet_len`.
pub fn computeMask(alphabet_len: u8) u8
{
    if (std.debug.runtime_safety) 
    {
        std.debug.assert(alphabet_len > 0);
    }

    const clz: u5 = @clz(u31, (alphabet_len - 1) | 1);
    const mask = (@as(u32, 2) << (31 - clz)) - 1;
    const result = @truncate(u8, mask);
    return result;
}

/// Computes the size necessary for a buffer which can hold the random byte in a step of a the nanoid generation algorithm given a certain alphabet size.
pub fn computeRngStepSize(mask: u8, id_size: usize, alphabet_len: u8) usize
{
    if (std.debug.runtime_safety) 
    {
        std.debug.assert(alphabet_len > 0);
        std.debug.assert(mask == computeMask(alphabet_len));
    }

    // @Note: 
    // Original dev notes regarding this algorithm. 
    // Source: https://github.com/ai/nanoid/blob/0454333dee4612d2c2e163d271af6cc3ce1e5aa4/index.js#L45
    // 
    // "Next, a step determines how many random bytes to generate.
    // The number of random bytes gets decided upon the ID size, mask,
    // alphabet size, and magic number 1.6 (using 1.6 peaks at performance
    // according to benchmarks)."
    const mask_f = @intToFloat(f64, mask);
    const id_size_f = @intToFloat(f64, id_size);
    const alphabet_size_f = @intToFloat(f64, alphabet_len);
    const step_size = std.math.ceil(1.6 * mask_f * id_size_f / alphabet_size_f);
    const result = @floatToInt(usize, step_size);
    
    return result;
}

/// Generates a nanoid using the provided input inside `result_buffer` and returns it back to the caller.
/// Parameters:
/// - `rng` is a Random number generator. Provide a secure one such as std.rand.DefaultCsprng if you are concerned with security.
/// - `alphabet` is an array of the bytes used to generate the id, its length must be in the range (0, max_alphabet_len]
/// - `result_buffer` is a buffer that will be filled completely with random bytes thus generating the id. 
///    This buffer will be returned at the end of the function.
/// - `step_buffer` must be a buffer big enough to store at least `computeRngStepSize(computeMask(@truncate(u8, alphabet.len)), result_buffer.len, alphabet.len)` bytes.
///   The buffer will be filled with random bytes using `rng.bytes()`.
///   If the alphabet size and id size (aka `result_buffer.len`) are not dynamic inputs, you can precompute this and stack allocate a big enough step_buffer.
///   If the alphabet size is unknown but within the valid range of (0, max_alphabet_len], and the maximum acceptable id size (aka `result_buffer.len`) is known, 
///   you can precompute the size of a big enough step buffer as well.
///
/// We expect all provided input to be correct and if `std.debug.runtime_safety` is true we execute assertions to verify this.
/// This function is supposed to be wrapped and accomodate for the desired preferences of the user, for examples on how to 
/// wrap and use `generateUnsafe` check `generateWithAlphabet` and `generateDefault`.
pub fn generateUnsafe(rng: std.rand.Random, alphabet: []const u8, result_buffer: []u8, step_buffer: []u8) []u8
{
    if (std.debug.runtime_safety) 
    {
        std.debug.assert(result_buffer.len > 0);
        std.debug.assert(alphabet.len > 0 and alphabet.len <= max_alphabet_len);
    }

    const alphabet_len = @truncate(u8, alphabet.len);
    const mask = computeMask(alphabet_len);

    if (std.debug.runtime_safety)
    {
        const rng_step_size = computeRngStepSize(mask, result_buffer.len, alphabet_len);
        std.debug.assert(step_buffer.len >= rng_step_size);
    }

    var result_iter: usize = 0;
    while (true)
    {
        rng.bytes(step_buffer);

        for (step_buffer) |it|
        {
            const alphabet_index = it & mask;
            
            if (alphabet_index >= alphabet_len)
            {
                continue;
            }

            result_buffer[result_iter] = alphabet[alphabet_index];

            if (result_iter == result_buffer.len - 1)
            {
                return result_buffer;
            }
            else
            {
                result_iter += 1;
            }
        }
    }
}

/// Generates a nanoid using the provided input inside `result_buffer` and returns it back to the caller.
/// Parameters:
/// - `rng` is a Random number generator. Provide a secure one such as std.rand.DefaultCsprng if you are concerned with security.
/// - `alphabet` is an array of the bytes used to generate the id, its length must be in the range (0, max_alphabet_len]
/// - `result_buffer` is a buffer that will be filled completely with random bytes thus generating the id. 
///    If your buffer is bigger than the desired id size provide a slice of it here.
///    This buffer will be returned at the end of the function.
///
/// We expect all provided input to be correct and if `std.debug.runtime_safety` is true we execute assertions to verify this.
/// This function is supposed to be wrapped and accomodate for the desired preferences of the user, for examples on how to 
/// wrap and use `generateUnsafe` check `generateWithAlphabet` and `generateDefault`.
///
/// This function will use `rng.int` instead of `rng.bytes` thus avoiding the need for a step buffer.
/// Depending on your choice of rng this can be useful, since you avoid the need for a step buffer, 
/// but repeated calls to `rng.int` might be slower than a single call `rng.bytes`.
pub fn generateWithIterativeRngUnsafe(rng: std.rand.Random, alphabet: []const u8, result_buffer: []u8) []u8
{
    if (std.debug.runtime_safety) 
    {
        std.debug.assert(result_buffer.len > 0);
        std.debug.assert(alphabet.len > 0 and alphabet.len <= max_alphabet_len);
    }

    const alphabet_len = @truncate(u8, alphabet.len);
    const mask = computeMask(alphabet_len);

    var result_iter: usize = 0;
    while (true)
    {
        const random_byte = rng.int(u8);

        const alphabet_index = random_byte & mask;

        if (alphabet_index >= alphabet_len)
        {
            continue;
        }
        
        result_buffer[result_iter] = alphabet[alphabet_index];

        if (result_iter == result_buffer.len - 1)
        {
            return result_buffer;
        }
        else
        {
            result_iter += 1;
        }
    }

    return result_buffer;
}

/// Generates a nanoid using the provided alphabet inside `result_buffer` and returns it back to the caller.
/// Parameters:
/// - `rng` is a Random number generator. Provide a secure one such as std.rand.DefaultCsprng if you are concerned with security.
/// - `alphabet` is an array of the bytes used to generate the id, its length must be in the range (0, max_alphabet_len]
/// - `result_buffer` is a buffer that will be filled with random bytes thus generating the id.
///    The buffer size must be in the range (0, default_id_len]
pub fn generateWithAlphabetToBuffer(rng: std.rand.Random, alphabet: []const u8, result_buffer: []u8) NanoidError![]u8
{
    if (alphabet.len == 0 or alphabet.len > max_alphabet_len)
    {
        return NanoidError.InvalidAlphabetSize;
    }

    if (!(result_buffer.len > 0 and result_buffer.len <= default_id_len))
    {
        return NanoidError.InvalidResultBufferSize;
    }

    // This should be enough memory for any id of default size regardless of alphabet size
    const sufficient_rng_step_size = comptime computeRngStepSize(computeMask(max_alphabet_len), default_id_len, max_alphabet_len);
    var rng_step_buffer: [sufficient_rng_step_size]u8 = undefined;

    // Generate the id
    const result = generateUnsafe(rng, alphabet, result_buffer, &rng_step_buffer);
    return result;
}

/// Generates a nanoid using the provided alphabet in a newly allocated buffer and returns it back to the caller.
/// Parameters:
/// - `allocator` is the allocator used to allocate the resulting buffer which gets returned to the user. The user must manage the resulting allocation.
/// - `rng` is a Random number generator. Provide a secure one such as std.rand.DefaultCsprng if you are concerned with security.
/// - `alphabet` is an array of the bytes used to generate the id, its length must be in the range (0, max_alphabet_len]
pub fn generateWithAlphabet(allocator: std.mem.Allocator, rng: std.rand.Random, alphabet: []const u8) Error![]u8
{
    if (alphabet.len == 0 or alphabet.len > max_alphabet_len)
    {
        return NanoidError.InvalidAlphabetSize;
    }

    // This should be enough memory for any id of default size regardless of alphabet size
    const sufficient_rng_step_size = comptime computeRngStepSize(computeMask(1), default_id_len, 1);
    var rng_step_buffer: [sufficient_rng_step_size]u8 = undefined;


    // Allocate result buffer
    const result_buffer = try allocator.alloc(u8, default_id_len);
    errdefer allocator.free(result_buffer);

    // Generate the id
    const result = generateUnsafe(rng, alphabet, result_buffer, &rng_step_buffer);
    return result;
}

/// Generates a nanoid using the default alphabet inside `result_buffer` and returns it back to the caller.
/// Parameters:
/// - `rng` is a Random number generator. Provide a secure one such as std.rand.DefaultCsprng if you are concerned with security.
/// - `alphabet` is an array of the bytes used to generate the id, its length must be in the range (0, max_alphabet_len]
/// - `result_buffer` is a buffer that will be filled with random bytes thus generating the id.
///    The buffer size must be in the range (0, default_id_len]
pub fn generateDefaultToBuffer(rng: std.rand.Random, result_buffer: []u8) NanoidError![]u8
{
    if (result_buffer.len == 0 or result_buffer.len > default_id_len)
    {
        return NanoidError.InvalidResultBufferSize;
    }

    var rng_step_buffer: [default_rng_step_buffer_len]u8 = undefined;

    const result = generateUnsafe(rng, default_alphabet, result_buffer, &rng_step_buffer);
    return result;
}

/// Generates a nanoid using the default alphabet in a newly allocated buffer and returns it back to the caller.
/// Parameters:
/// - `allocator` is the allocator used to allocate the resulting buffer which gets returned to the user. The user must manage the resulting allocation.
/// - `rng` is a Random number generator. Provide a secure one such as std.rand.DefaultCsprng if you are concerned with security.
/// - `alphabet` is an array of the bytes used to generate the id, its length must be in the range (0, max_alphabet_len]
pub fn generateDefault(allocator: std.mem.Allocator, rng: std.rand.Random) Error![]u8
{
    var rng_step_buffer: [default_rng_step_buffer_len]u8 = undefined;

    const result_buffer = try allocator.alloc(u8, default_id_len);
    errdefer allocator.free(result_buffer);

    const result = generateUnsafe(rng, default_alphabet, result_buffer, &rng_step_buffer);
    return result;
}

const testutils = struct 
{
    fn makeDefaultCsprng() std.rand.DefaultCsprng 
    {
        // Generate seed
        var seed: [std.rand.DefaultCsprng.secret_seed_length]u8 = undefined;
        std.crypto.random.bytes(&seed);

        // Initialize the rng and allocator
        var rng = std.rand.DefaultCsprng.init(seed);
        return rng;
    }

    fn makeDefaultPrngWithConstantSeed() std.rand.DefaultPrng
    {
        var rng = std.rand.DefaultPrng.init(0);
        return rng;
    }

    fn makeDefaultCsprngWithConstantSeed() std.rand.DefaultCsprng
    {
        // Generate seed
        var seed: [std.rand.DefaultCsprng.secret_seed_length]u8 = undefined;
        for (seed) |*it| it.* = 'a';

        // Initialize the rng and allocator
        var rng = std.rand.DefaultCsprng.init(seed);
        return rng;
    }

    /// Taken from https://github.com/codeyu/nanoid-net/blob/445f4d363e0079e151ea414dab1a9f9961679e7e/test/Nanoid.Test/NanoidTest.cs#L145
    fn toBeCloseTo(actual: f64, expected: f64, precision: f64) bool
    {
        const pass = @fabs(expected - actual) < std.math.pow(f64, 10, -precision) / 2;
        return pass;
    }
};

test "computeMask all acceptable input"
{
    var i: u9 = 1;
    while (i <= max_alphabet_len) : (i += 1) 
    {
        const alphabet_len = @truncate(u8, i);
        const mask = computeMask(alphabet_len);
        try std.testing.expect(mask > 0);
    }
}

test "computeRngStepSize all acceptable alphabet sizes and default id size"
{
    var i: u9 = 1;
    while (i <= max_alphabet_len) : (i += 1)
    {
        const alphabet_len = @truncate(u8, i);
        const mask = computeMask(alphabet_len);
        const rng_step_size = computeRngStepSize(mask, default_id_len, alphabet_len);
        try std.testing.expect(rng_step_size > 0);
    }
}

test "generate default"
{
    // Init rng and allocator 
    var rng = testutils.makeDefaultCsprng();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    
    // Generate a nanoid
    const result = try generateDefault(gpa.allocator(), rng.random());
    defer gpa.allocator().free(result);

    try std.testing.expect(result.len == default_id_len);
}

test "generate with custom size"
{
    // Init rng
    var rng = testutils.makeDefaultCsprng();
    
    // Generate a nanoid
    const custom_id_size = 10;
    const rng_step_size = comptime computeRngStepSize(computeMask(default_alphabet.len), custom_id_size, default_alphabet.len);
    
    var result_buffer: [custom_id_size]u8 = undefined;
    var step_buffer: [rng_step_size]u8 = undefined;

    const result = generateUnsafe(rng.random(), default_alphabet, &result_buffer, &step_buffer);

    try std.testing.expect(result.len == custom_id_size);
}

test "generate with custom alphabet"
{
    // Initialize the rng and allocator
    var rng = testutils.makeDefaultCsprng();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    
    // Generate a nanoid
    const custom_alphabet = "1234abcd";
    const result = try generateWithAlphabet(gpa.allocator(), rng.random(), custom_alphabet);

    try std.testing.expect(result.len == default_id_len);
    
    for (result) |it|
    {
        try std.testing.expect(std.mem.indexOfScalar(u8, custom_alphabet, it) != null);
    }
}

test "generate with custom alphabet and size"
{
    // Initialize the rng and allocator
    var rng = testutils.makeDefaultCsprng();
    
    // Generate a nanoid
    const custom_alphabet = "1234abcd";
    const custom_id_size = 7;
    var result_buffer: [custom_id_size]u8 = undefined;
    const result = try generateWithAlphabetToBuffer(rng.random(), custom_alphabet, &result_buffer);

    try std.testing.expect(result.len == custom_id_size);
    
    for (result) |it|
    {
        try std.testing.expect(std.mem.indexOfScalar(u8, custom_alphabet, it) != null);
    }
}

test "generate with single letter alphabet"
{
    // Initialize the rng and allocator
    var rng = testutils.makeDefaultCsprng();
    
    // Generate a nanoid
    const custom_alphabet = "a";
    const custom_id_size = 5;
    var result_buffer: [custom_id_size]u8 = undefined;
    const result = try generateWithAlphabetToBuffer(rng.random(), custom_alphabet, &result_buffer);

    try std.testing.expect(std.mem.eql(u8, "aaaaa", result));
}

test "generate flat distribution"
{
    // Initialize the rng and allocator
    var rng = testutils.makeDefaultCsprng();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Generate a nanoid
    const number_of_ids_to_generate = 100 * 1000;

    var characters_counts = std.AutoArrayHashMap(u8, usize).init(gpa.allocator());
    defer characters_counts.deinit();
 
    // Generate ids
    var i: usize = 0;
    while (i < number_of_ids_to_generate) : (i += 1)
    {
        const id = try generateDefault(gpa.allocator(), rng.random());
        defer gpa.allocator().free(id);

        // Count the occurence of every character across all generated ids
        for (id) |char|
        {
            var char_count = characters_counts.getPtr(char);
            if (char_count) |c|
            {
                c.* += 1;
            }
            else 
            {
                try characters_counts.put(char, 0);
            }
        }
    }

    for (characters_counts.values()) |value|
    {
        const value_f = @intToFloat(f64, value);
        const alphabet_len_f = @intToFloat(f64, default_alphabet.len);
        const count_f = @intToFloat(f64, number_of_ids_to_generate);
        const id_size_f = @intToFloat(f64, default_id_len);
        const distribution = value_f * alphabet_len_f / (count_f * id_size_f);
        try std.testing.expect(testutils.toBeCloseTo(distribution, 1, 1));
    }
}

test "generate flat distribution for iterative rng"
{
    // Initialize the rng and allocator
    var rng = testutils.makeDefaultCsprng();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Generate a nanoid
    const number_of_ids_to_generate = 100 * 1000;

    var characters_counts = std.AutoArrayHashMap(u8, usize).init(gpa.allocator());
    defer characters_counts.deinit();
 
    // Generate ids
    var i: usize = 0;
    while (i < number_of_ids_to_generate) : (i += 1)
    {
        var id_buffer: [default_id_len]u8 = undefined;
        const id = generateWithIterativeRngUnsafe(rng.random(), default_alphabet, &id_buffer);

        // Count the occurence of every character across all generated ids
        for (id) |char|
        {
            var char_count = characters_counts.getPtr(char);
            if (char_count) |c|
            {
                c.* += 1;
            }
            else 
            {
                try characters_counts.put(char, 0);
            }
        }
    }

    for (characters_counts.values()) |value|
    {
        const value_f = @intToFloat(f64, value);
        const alphabet_len_f = @intToFloat(f64, default_alphabet.len);
        const count_f = @intToFloat(f64, number_of_ids_to_generate);
        const id_size_f = @intToFloat(f64, default_id_len);
        const distribution = value_f * alphabet_len_f / (count_f * id_size_f);
        try std.testing.expect(testutils.toBeCloseTo(distribution, 1, 1));
    }
}

test "with constant seed to prng"
{
    // Init rng and allocator 
    var rng = testutils.makeDefaultPrngWithConstantSeed();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Generate a nanoid
    const result = try generateDefault(gpa.allocator(), rng.random());
    defer gpa.allocator().free(result);

    try std.testing.expectEqualStrings(result, "x9l5_XofdoYVaZ0J2ob30");
}

test "with constant seed to csprng"
{
    // Init rng and allocator 
    var rng = testutils.makeDefaultCsprngWithConstantSeed();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Generate a nanoid
    const result = try generateDefault(gpa.allocator(), rng.random());
    defer gpa.allocator().free(result);

    try std.testing.expectEqualStrings(result, "WGAM32wiVYs19fgttw6lM");
}

test "with constant seed to prng iterative"
{
    // Init rng and allocator 
    var rng = testutils.makeDefaultPrngWithConstantSeed();
    
    // Generate a nanoid
    var result_buffer: [default_id_len]u8 = undefined;
    const result = generateWithIterativeRngUnsafe(rng.random(), default_alphabet, &result_buffer);

    try std.testing.expectEqualStrings(result, "5ookuCml5jZyphCDT0R4s");
}

test "with constant seed to csprng iterative"
{
    // Init rng and allocator 
    var rng = testutils.makeDefaultCsprngWithConstantSeed();
    
    // Generate a nanoid
    var result_buffer: [default_id_len]u8 = undefined;
    const result = generateWithIterativeRngUnsafe(rng.random(), default_alphabet, &result_buffer);

    try std.testing.expectEqualStrings(result, "WOo_Gi5-2dtC__isbnp67");
}