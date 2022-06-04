const std = @import("std");

pub fn build(b: *std.build.Builder) void 
{
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    
    const test_step = b.step("test", "Run unit tests directly.");
    const run_step = b.step("run", "Run example.");
    
    const default_example = b.option(bool, "default_example", "A simple example of using nanoid.") orelse false;
    const custom_alphabet_example = b.option(bool, "custom_alphabet_example", "A simple example of using nanoid.") orelse false;
    const tests = b.option(bool, "tests", "The unit tests of the library.") orelse false;
    
    if (default_example)
    {
        const exe = b.addExecutable("nanoid-zig-default-example", "examples/default-example.zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.addPackage(getPackage("nanoid"));
        exe.install();
        
        const exe_run = exe.run();
        exe_run.step.dependOn(b.getInstallStep());
        run_step.dependOn(&exe_run.step);
    }

    if (custom_alphabet_example)
    {
        const exe = b.addExecutable("nanoid-zig-custom-alphabet-example", "examples/custom-alphabet-example.zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.addPackage(getPackage("nanoid"));
        exe.install();
        
        const exe_run = exe.run();
        exe_run.step.dependOn(b.getInstallStep());
        run_step.dependOn(&exe_run.step);
    }

    if (tests)
    {
        const exe = b.addTestExe("nanoid-zig-test", "src/nanoid.zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();
        
        const exe_run = exe.run();
        exe_run.step.dependOn(b.getInstallStep());
        run_step.dependOn(&exe_run.step);
    }

    // Test runner
    const test_runner = b.addTest("src/nanoid.zig");
    test_runner.setBuildMode(mode);
    test_runner.setTarget(target);
    test_step.dependOn(&test_runner.step);
}

pub fn getPackage(name: []const u8) std.build.Pkg
{
    return std.build.Pkg{
        .name = name,
        .source = .{ .path = std.fs.path.dirname(@src().file).? ++ "/src/nanoid.zig" },
        .dependencies = null, // null by default, but can be set to a slice of `std.build.Pkg`s that your package depends on.
    };
}