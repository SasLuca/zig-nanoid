# Nano ID in Zig

[![License](https://img.shields.io/badge/license-MIT%20License-blue.svg)](https://github.com/SasLuca/nanoid-zig/master/LICENSE)
[![cross build tests](https://github.com/SasLuca/zig-nanoid/actions/workflows/cross-build.yml/badge.svg)](https://github.com/SasLuca/zig-nanoid/actions/workflows/cross-build.yml)
![Maintenance intention for this crate](https://img.shields.io/badge/maintenance-actively--developed-brightgreen.svg)

<img src="https://raw.githubusercontent.com/SasLuca/zig-nanoid/main/logo.svg" align="right" alt="Nano ID x Zig logo by Anton Lovchikov, adapted by Luca Sas" width="180" height="94">

A battle-tested, tiny, secure, URL-friendly, unique string ID generator. Now available in pure Zig.

* **Freestanding.** zig-nanoid is entirely freestanding.
* **Fast.** The algorithm is very fast and relies just on basic math, speed will mostly depend on your choice of RNG.
* **Safe.** It can use any random generator you want and the library has no errors to handle.
* **Short IDs.** It uses a larger alphabet than UUID (`A-Za-z0-9_-`). So ID length was reduced from 36 to 21 symbols and it is URL friendly.
* **Battle Tested.** Original implementation has over 18_264_279 million weekly downloads on [npm](https://www.npmjs.com/package/nanoid).
* **Portable.** Nano ID was ported to [20+ programming languages](https://github.com/ai/nanoid#other-programming-languages).

## Example

Basic usage with `std.crypto.random`:
```zig
const std = @import("std");
const nanoid = @import("nanoid");

pub fn main() !void
{   
    const result = nanoid.generate(std.crypto.random);

    std.log.info("Nanoid: {s}", .{result});
}
```

## Comparison to UUID

Nano ID is quite comparable to UUID v4 (random-based).

It has a similar number of random bits in the ID (126 in Nano ID and 122 in UUID), so it has a similar collision probability.

It also uses a bigger alphabet, so a similar number of random bits are packed in just 21 symbols instead of 36.

For there to be a one in a billion chance of duplication, 103 trillion version 4 IDs must be generated.

## How to use

### Generating an id with the default size

The simplest way to generate an id with the default alphabet and length is by using the function `generate` like so:

```zig
const result = nanoid.generate(std.crypto.random);
```

If you want a custom alphabet you can use `generateWithAlphabet` and pass either a custom alphabet or one from `nanoid.alphabets`:
```zig
const result = nanoid.generateWithAlphabet(std.crypto.random, nanoid.alphabets.numbers); // This id will only contain numbers
```

You can find a variety of other useful alphabets inside of `nanoid.alphabets`.

The result is an array of size `default_id_len` which happens to be 21 which is returned by value.

There are no errors to handle, assuming your rng object is valid everything will work.
The default alphabet includes the symbols "-_", numbers and English lowercase and uppercase letters.

### Generating an id with a custom size

If you want a custom alphabet and length use `generateEx` or `generateExWithIterativeRng`.

The function `generateEx` takes an rng, an `alphabet`, a `result_buffer` that it will write the id to, and a `step_buffer`.
The `step_buffer` is used by the algorithm to store a random bytes so it has to do less calls to the rng and `step_buffer.len` must be at 
least `computeRngStepBufferLength(computeMask(@truncate(u8, alphabet.len)), result_buffer.len, alphabet.len)`.

The function `generateExWithIterativeRng` is the same as `generateEx` except it doesn't need a `step_buffer`. It will use `Random.int(u8)` 
instead of `Random.bytes()` to get a random byte at a time thus avoiding the need for a rng step buffer. Normally this will be slower but 
depending on your rng algorithm or other requirements it might not be, so the option is there in case you need but normally it is 
recommended you use `generateEx` which requires a temporary buffer that will be filled using `Random.bytes()` in order to get the best
performance.

Additionally you can precompute a sufficient length for the `step_buffer` and pre-allocate it as an optimization using 
`computeSufficientRngStepBufferLengthFor` which simply asks for the largest possible id length you want to generate.

If you intend to use the `default_id_len`, you can use the constant `nanoid.rng_step_buffer_len_sufficient_for_default_length_ids`.

### Regarding RNGs

You will need to provide an random number generator (rng) yourself. You can use the zig standard library ones, either `std.rand.DefaultPrng`
or if you have stricter security requirements use `std.rand.DefaultCsprng` or `std.crypto.random`.

When you initialize them you need to provide a seed, providing the same one every time will result in the same ids being generated every 
time you run the program, except for `std.crypto.random`.

If you want a good secure seed you can generate one using `std.crypto.random.bytes`. 

Here is an example of how you would initialize and seed `std.rand.DefaultCsprng` and use it:

```zig
// Generate seed
var seed: [std.rand.DefaultCsprng.secret_seed_length]u8 = undefined;
std.crypto.random.bytes(&seed);

// Initialize the rng and allocator
var rng = std.rand.DefaultCsprng.init(seed);

// Generate id
var id = nanoid.generate(rng.random());
```

## Add zig-nanoid to your project

### Using the gyro package manager

We support the zig [gyro package manager](https://github.com/mattnite/gyro).
Here is how to use it:

1. From your terminal initialize a gyro project and add the package `SasLuca/nanoid`.
    ```
    gyro init
    gyro add SasLuca/nanoid
    ```

2. In your `build.zig` do an import like so `const pkgs = @import("deps.zig").pkgs;` and call `pkgs.addAllTo(exe);` to add all libraries to your executable (or some other target).

3. Import `const nanoid = @import("nanoid");` in your `main.zig` and use it.

4. Invoke `gyro build run` which will generate `deps.zig` and other files as well as building and running your project.

### Manually

To add the library as a package to your zig project:
1. Download the repo and put it in a folder (eg: `thirdparty`) in your project.
2. Import the library `build.zig` like so: `const nanoid = @import("thirdparty/nanoid-zig/build.zig");`
3. Add the library as a package like so: `exe.addPackage(nanoid.getPackage("nanoid"));`

Full example:
```zig
const std = @import("std");
const nanoid = @import("thirdparty/zig-nanoid/build.zig");

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

## Useful links

- Original implementation: https://github.com/ai/nanoid

- Online Tool: https://zelark.github.io/nano-id-cc/
