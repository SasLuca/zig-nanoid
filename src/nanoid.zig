const std = @import("std");

pub const alphabets = struct 
{    
    /// Numbers from 0 to 9.
    pub const numbers = "0123456789";

    /// English hexadecimal with lowercase characters.
    pub const hexadecimal_lowercase = numbers ++ "abcdef";

    /// English hexadecimal with uppercase characters.
    pub const hexadecimal_uppercase = numbers ++ "ABCDEF";

    /// Lowercase English letters.
    pub const lowercase = "abcdefghijklmnopqrstuvwxyz";
    
    /// Uppercase English letters.
    pub const uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    
    /// Numbers and english letters without lookalikes: 1, l, I, 0, O, o, u, v, 5, S, s, 2, Z.
    pub const no_look_alikes = "346789ABCDEFGHJKLMNPQRTUVWXYabcdefghijkmnpqrtwxyz";
    
    /// Same as nolookalikes but with removed vowels and following letters: 3, 4, x, X, V.
    /// This list should protect you from accidentally getting obscene words in generated strings.
    pub const no_look_alikes_safe = "6789BCDFGHJKLMNPQRTWbcdfghjkmnpqrtwz";

    /// Combination of all the lowercase, uppercase characters and numbers from 0 to 9. 
    /// Does not include any symbols or special characters.
    pub const alphanumeric = numbers ++ lowercase ++ uppercase;

    /// URL friendly characters used by the default generate procedure.
    pub const default = "_-" ++ alphanumeric;
};

// An array of all the alphabets.
pub const all_alphabets = InternalUtils.collectAllConstantsInStruct(alphabets, []const u8);

/// The default length of the generated id.
pub const default_id_len = 21;

/// The computed mask for the default alphabet length.
pub const default_mask = computeMask(alphabets.default.len);

/// This should be enough memory for a step buffer when generating an id of default length regardless of alphabet length.
pub const sufficient_rng_step_buffer_len = computeRngStepBufferLength(computeMask(65), default_id_len, 65);

/// The maximum length of the alphabet accepted by the nanoid algorithm.
pub const max_alphabet_len: u8 = 255;

/// An error union of Nanoid specific errors.
pub const NanoidError = error
{
    /// The alphabet length is not within the accepted range (0, alphabet_max_size).
    InvalidAlphabetSize,

    /// The length of the provided result buffer is not within an acceptable range.
    InvalidResultBufferSize
};

/// An error union of all possible errors that can be returned by a procedure in this library.
pub const Error = std.mem.Allocator.Error || NanoidError;

/// Computes the mask necessary for the nanoid algorithm given an alphabet length.
/// The mask is used to transform a random byte into an index into an array of length `alphabet_len`.
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

/// Computes the length necessary for a buffer which can hold the random byte in a step of a the nanoid generation algorithm given a certain alphabet length.
pub fn computeRngStepBufferLength(mask: u8, id_len: usize, alphabet_len: u8) usize
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
    // The number of random bytes gets decided upon the ID length, mask,
    // alphabet length, and magic number 1.6 (using 1.6 peaks at performance
    // according to benchmarks)."
    const mask_f = @intToFloat(f64, mask);
    const id_len_f = @intToFloat(f64, id_len);
    const alphabet_size_f = @intToFloat(f64, alphabet_len);
    const step_size = std.math.ceil(1.6 * mask_f * id_len_f / alphabet_size_f);
    const result = @floatToInt(usize, step_size);
    
    return result;
}

/// Generates a nanoid using the provided input inside `result_buffer` and returns it back to the caller.
/// Parameters:
/// - `rng` is a Random number generator. Provide a secure one such as std.rand.DefaultCsprng if you are concerned with security.
/// - `alphabet` is an array of the bytes used to generate the id, its length must be in the range (0, max_alphabet_len]
/// - `result_buffer` is a buffer that will be filled completely with random bytes thus generating the id. 
///    This buffer will be returned at the end of the function.
/// - `step_buffer` must be a buffer big enough to store at least `computeRngStepBufferLength(computeMask(@truncate(u8, alphabet.len)), result_buffer.len, alphabet.len)` bytes.
///   The buffer will be filled with random bytes using `rng.bytes()`.
///   If the alphabet length and id length (aka `result_buffer.len`) are not dynamic inputs, you can precompute this and stack allocate a big enough step_buffer.
///   If the alphabet length is unknown but within the valid range of (0, max_alphabet_len], and the maximum acceptable id length (aka `result_buffer.len`) is known, 
///   you can precompute the length of a big enough step buffer as well.
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
        const rng_step_size = computeRngStepBufferLength(mask, result_buffer.len, alphabet_len);
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
///    If your buffer is bigger than the desired id length provide a slice of it here.
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
///    The buffer length must be in the range (0, default_id_len]
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

    
    var rng_step_buffer: [sufficient_rng_step_buffer_len]u8 = undefined;

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

    // This should be enough memory for any id of default length regardless of alphabet length
    var rng_step_buffer: [sufficient_rng_step_buffer_len]u8 = undefined;


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
///    The buffer length must be in the range (0, default_id_len]
pub fn generateDefaultToBuffer(rng: std.rand.Random, result_buffer: []u8) NanoidError![]u8
{
    if (result_buffer.len == 0 or result_buffer.len > default_id_len)
    {
        return NanoidError.InvalidResultBufferSize;
    }

    var rng_step_buffer: [sufficient_rng_step_buffer_len]u8 = undefined;

    const result = generateUnsafe(rng, alphabets.default, result_buffer, &rng_step_buffer);
    return result;
}

/// Generates a nanoid using the default alphabet in a newly allocated buffer and returns it back to the caller.
/// Parameters:
/// - `allocator` is the allocator used to allocate the resulting buffer which gets returned to the user. The user must manage the resulting allocation.
/// - `rng` is a Random number generator. Provide a secure one such as std.rand.DefaultCsprng if you are concerned with security.
/// - `alphabet` is an array of the bytes used to generate the id, its length must be in the range (0, max_alphabet_len]
pub fn generateDefault(allocator: std.mem.Allocator, rng: std.rand.Random) Error![]u8
{
    var rng_step_buffer: [sufficient_rng_step_buffer_len]u8 = undefined;

    const result_buffer = try allocator.alloc(u8, default_id_len);
    errdefer allocator.free(result_buffer);

    const result = generateUnsafe(rng, alphabets.default, result_buffer, &rng_step_buffer);
    return result;
}

/// Non public utility functions used mostly in unit tests.
const InternalUtils = struct 
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

    /// Checks if all elements in `array` are present in `includedIn`.
    fn allIn(comptime T: type, array: []T, includedIn: []const T) bool 
    {
        for (array) |it|
        {
            if (std.mem.indexOfScalar(u8, includedIn, it) == null) 
            {
                return false;
            }
        }

        return true;
    }

    /// Returns an array with all the public constants from a struct.
    fn collectAllConstantsInStruct(comptime namespace: type, comptime T: type) []const T 
    {
        var result: []const T = &.{};
        for (@typeInfo(namespace).Struct.decls) |decl|
        {
            if (!decl.is_pub) continue;

            const value = @field(namespace, decl.name);
            
            if (@TypeOf(value) == T)
            {
                result = result ++ [_]T{ value };
            }
        }
        return result;
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

test "computeRngStepBufferLength all acceptable alphabet sizes and default id length"
{
    var i: u9 = 1;
    while (i <= max_alphabet_len) : (i += 1)
    {
        const alphabet_len = @truncate(u8, i);
        const mask = computeMask(alphabet_len);
        const rng_step_size = computeRngStepBufferLength(mask, default_id_len, alphabet_len);
        try std.testing.expect(rng_step_size > 0);
    }
}

test "generate default"
{
    // Init rng and allocator 
    var rng = InternalUtils.makeDefaultCsprng();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    
    // Generate a nanoid
    const result = try generateDefault(gpa.allocator(), rng.random());
    defer gpa.allocator().free(result);

    try std.testing.expect(result.len == default_id_len);
}

test "generate with custom length"
{
    // Init rng
    var rng = InternalUtils.makeDefaultCsprng();
    
    // Generate a nanoid
    const custom_id_len = 10;
    const rng_step_size = comptime computeRngStepBufferLength(computeMask(alphabets.default.len), custom_id_len, alphabets.default.len);
    
    var result_buffer: [custom_id_len]u8 = undefined;
    var step_buffer: [rng_step_size]u8 = undefined;

    const result = generateUnsafe(rng.random(), alphabets.default, &result_buffer, &step_buffer);

    try std.testing.expect(result.len == custom_id_len);
}

test "generate with custom alphabet"
{
    // Initialize the rng and allocator
    var rng = InternalUtils.makeDefaultCsprng();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    
    // Generate a nanoid
    const custom_alphabet = "1234abcd";
    const result = try generateWithAlphabet(gpa.allocator(), rng.random(), custom_alphabet);

    try std.testing.expect(result.len == default_id_len);
    try std.testing.expect(InternalUtils.allIn(u8, result, custom_alphabet));
}

test "generate with all alphabets"
{
    var rng = InternalUtils.makeDefaultCsprng();
    var result_buffer: [default_id_len]u8 = undefined;
    
    for (all_alphabets) |alphabet|
    {
        const result = try generateWithAlphabetToBuffer(rng.random(), alphabet, &result_buffer);

        try std.testing.expect(result.len == default_id_len);
        try std.testing.expect(InternalUtils.allIn(u8, result, alphabet));
    }
}

test "generate with custom alphabet and length"
{
    // Initialize the rng and allocator
    var rng = InternalUtils.makeDefaultCsprng();
    
    // Generate a nanoid
    const custom_alphabet = "1234abcd";
    const custom_id_len = 7;
    var result_buffer: [custom_id_len]u8 = undefined;
    const result = try generateWithAlphabetToBuffer(rng.random(), custom_alphabet, &result_buffer);

    try std.testing.expect(result.len == custom_id_len);
    
    for (result) |it|
    {
        try std.testing.expect(std.mem.indexOfScalar(u8, custom_alphabet, it) != null);
    }
}

test "generate with single letter alphabet"
{
    // Initialize the rng and allocator
    var rng = InternalUtils.makeDefaultCsprng();
    
    // Generate a nanoid
    const custom_alphabet = "a";
    const custom_id_len = 5;
    var result_buffer: [custom_id_len]u8 = undefined;
    const result = try generateWithAlphabetToBuffer(rng.random(), custom_alphabet, &result_buffer);

    try std.testing.expect(std.mem.eql(u8, "aaaaa", result));
}

test "generate flat distribution"
{
    // Initialize the rng and allocator
    var rng = InternalUtils.makeDefaultCsprng();
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
        const id = try generateDefaultToBuffer(rng.random(), &id_buffer);

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
        const alphabet_len_f = @intToFloat(f64, alphabets.default.len);
        const count_f = @intToFloat(f64, number_of_ids_to_generate);
        const id_len_f = @intToFloat(f64, default_id_len);
        const distribution = value_f * alphabet_len_f / (count_f * id_len_f);
        try std.testing.expect(InternalUtils.toBeCloseTo(distribution, 1, 1));
    }
}

test "generate flat distribution for iterative rng"
{
    // Initialize the rng and allocator
    var rng = InternalUtils.makeDefaultCsprng();
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
        const id = generateWithIterativeRngUnsafe(rng.random(), alphabets.default, &id_buffer);

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
        const alphabet_len_f = @intToFloat(f64, alphabets.default.len);
        const count_f = @intToFloat(f64, number_of_ids_to_generate);
        const id_len_f = @intToFloat(f64, default_id_len);
        const distribution = value_f * alphabet_len_f / (count_f * id_len_f);
        try std.testing.expect(InternalUtils.toBeCloseTo(distribution, 1, 1));
    }
}

test "with constant seed to prng"
{
    // Init rng and allocator 
    var rng = InternalUtils.makeDefaultPrngWithConstantSeed();
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
    var rng = InternalUtils.makeDefaultCsprngWithConstantSeed();
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
    var rng = InternalUtils.makeDefaultPrngWithConstantSeed();
    
    // Generate a nanoid
    var result_buffer: [default_id_len]u8 = undefined;
    const result = generateWithIterativeRngUnsafe(rng.random(), alphabets.default, &result_buffer);

    try std.testing.expectEqualStrings(result, "5ookuCml5jZyphCDT0R4s");
}

test "with constant seed to csprng iterative"
{
    // Init rng and allocator 
    var rng = InternalUtils.makeDefaultCsprngWithConstantSeed();
    
    // Generate a nanoid
    var result_buffer: [default_id_len]u8 = undefined;
    const result = generateWithIterativeRngUnsafe(rng.random(), alphabets.default, &result_buffer);

    try std.testing.expectEqualStrings(result, "WOo_Gi5-2dtC__isbnp67");
}