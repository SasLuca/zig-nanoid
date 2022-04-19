# Nano ID in Zig

[![License](https://img.shields.io/badge/license-MIT%20License-blue.svg)](https://github.com/SasLuca/nanoid-zig/edit/master/LICENSE)

<img src="https://ai.github.io/nanoid/logo.svg" align="right" alt="Nano ID logo by Anton Lovchikov" width="180" height="94">

A tiny, secure, URL-friendly, unique string ID generator. Now available in pure Zig.

* **Small.** Less than 100 lines of code. No dependencies (zig std used just for an optional convenience function).
* **Fast.** It is 2 times faster than UUID.
* **Safe.** It can use any random generator you want.
* **Short IDs.** It uses a larger alphabet than UUID (`A-Za-z0-9_-`). So ID size was reduced from 36 to 21 symbols and it is URL friendly.
* **Portable.** Nano ID was ported to [20+ programming languages](https://github.com/ai/nanoid#other-programming-languages).

## Example

With default prng:
```zig
pub fn main() !void
{
    // Init rng and allocator
    var rng = std.rand.DefaultPrng.init(0);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Generate nanoid
    const result = try generate(gpa.allocator(), rng.random());
    defer gpa.allocator().free(result);
    
    // Print
    std.log.info("Nanoid: {s}", .{result});
}
```

With default csprng seeded properly:
```zig
const std = @import("std");
const nanoid = @import("nanoid");

pub fn main() !void
{   
    // Generate seed
    var seed: [std.rand.DefaultCsprng.secret_seed_length]u8 = undefined;
    std.crypto.random.bytes(&seed);

    // Initialize rng and allocator
    var rng = std.rand.DefaultCsprng.init(seed); 
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    // Generate nanoid
    const result = try nanoid.generateDefault(gpa.allocator(), rng.random());
    defer gpa.allocator().free(result);

    // Print it at the end
    std.log.info("Nanoid: {s}", .{result});
}
```

## Comparison to UUID

Nano ID is quite comparable to UUID v4 (random-based).

It has a similar number of random bits in the ID (126 in Nano ID and 122 in UUID), so it has a similar collision probability.

It also uses a bigger alphabet, so a similar number of random bits are packed in just 21 symbols instead of 36.

> For there to be a one in a billion chance of duplication, 103 trillion version 4 IDs must be generated.

## How to use

### Build steps
To add the library as a package to your zig project:
1. Download the repo and put it in a folder (eg: `thirdparty`) in your project.
2. Import the library `build.zig` like so: `const nanoid = @import("thirdparty/nanoid-zig/build.zig");`
3. Add the library as a package like so: `exe.addPackage(nanoid.getPackage("nanoid"));`

Full example:
```zig
const std = @import("std");
const nanoid = @import("thirdparty/nanoid-zig/build.zig");

pub fn build(b: *std.build.Builder) void 
{
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zig-nanoid-test", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addPackage(nanoid.getPackage("nanoid"));
    exe.install();
}
```

### API usage

The API exposes low level unsafe procedures and higher level convenience wrappers.

The simplest way to generate an id with the default alphabet and size is by using the function `generateDefault` like so:

```zig
const result = try nanoid.generateDefault(allocator, random);
defer allocator.free(result);
```

If you want to avoid the allocation, since we know the size of an id generated by `generateDefault`, you can use `generateDefaultToBuffer`.

```zig
var buffer: [nanoid.default_id_len]u8 = undefined;
const result = try nanoid.generateDefaultToBuffer(random, &buffer);
```

You will need to provide an random number generator (rng) yourself. Here is a full example which uses the default secure rng from the zig standard library.

```zig
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
    
    // Generate a scoped nanoid
    const result = try nanoid.generateDefault(gpa.allocator(), rng.random());
    defer gpa.allocator().free(result);

    // Print it at the end
    std.log.info("Nanoid: {s}", .{result});
}
```

If you want a custom alphabet you can use the `generateWithAlphabet` procedure.

If you want to avoid passing an allocator for the result, you can just allocate a buffer with at least `default_id_len` bytes and pass it to `generateDefaultToBuffer` or `generateWithAlphabetToBuffer`. 

### Low level API

If you want a custom alphabet and size it is recommended that you create your own wrapper which does error checking and calls `generateUnsafe` or `generateWithIterativeRngUnsafe`.

`generateWithIterativeRngUnsafe` is the same as `generateUnsafe` except it will use `Random.int(u8)` instead of `Random.bytes()` to get a random byte at a time thus avoiding the need for a rng step buffer. Normally this will be slower but depending on your rng algorithm it might not be so the option is there in case you need but normally it is recommended you use `generateUnsafe` which requires a temporary buffer that will be filled using `Random.bytes` in order to improve performance.

In order to implement your own wrapper you can look at the implementation of `generateWithAlphabet` and `generateDefault`.

## Useful links

- Original implementation: https://github.com/ai/nanoid

- Online tool: https://gitpod.io/#https://github.com/ai/nanoid/
