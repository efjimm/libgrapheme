const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

const version = .{
    .major = 2,
    .minor = 0,
    .patch = 2,
};

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const shared = b.option(bool, "shared", "Build as a shared library") orelse false;

    const lib = Build.Step.Compile.create(b, .{
        .name = "grapheme",
        .kind = .lib,
        .version = version,
        .linkage = if (shared) .dynamic else .static,
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(.{ .path = thisDir() });
    genSources(lib, target, optimize);

    lib.addCSourceFiles(source_files, cflags);
    lib.installHeader("grapheme.h", "grapheme.h");
    b.installArtifact(lib);

    const clean_step = b.step("clean", "Remove all generated files");
    cleanStep(b, clean_step);
}

pub fn cleanStep(b: *Build, step: *Step) void {
    const rm_out = b.addRemoveDirTree("zig-out");
    const rm_cache = b.addRemoveDirTree("zig-cache");

    inline for (generators) |data| {
        const rm_gen = b.addRemoveDirTree(data[1]);
        step.dependOn(&rm_gen.step);
    }

    step.dependOn(&rm_out.step);
    step.dependOn(&rm_cache.step);
}

pub fn genSources(
    cs: *Build.Step.Compile,
    target: anytype,
    optimize: anytype,
) void {
    const b = cs.step.owner;
    const write_step = b.addWriteFiles();

    inline for (generators) |data| {
        const src = data[0];
        const dest = data[1];

        const exe = b.addExecutable(.{
            .name = std.fs.path.stem(src),
            .target = target,
            .optimize = optimize,
        });

        exe.linkLibC();
        exe.addCSourceFiles(&.{ src, "gen/util.c" }, cflags);

        const run_step = b.addRunArtifact(exe);
        const file_source = run_step.captureStdOut();
        _ = run_step.captureStdErr(); // Discard stderr

        _ = write_step.addCopyFile(file_source, dest);
    }

    cs.addIncludePath(write_step.getDirectory());
}

const cflags: []const []const u8 = &.{
    "-Wall",
    "-Wextra",
    "-Wpedantic",
    "-std=c99",
    "-D_ISOC99_SOURCE",
};

const source_files: []const []const u8 = &.{
    "src/bidirectional.c",
    "src/case.c",
    "src/character.c",
    "src/line.c",
    "src/sentence.c",
    "src/utf8.c",
    "src/util.c",
    "src/word.c",
};

/// List of .c files whose stdout when compiled and run will generate the corresponding header file.
const generators = .{
    .{ "gen/bidirectional.c", "gen/bidirectional.h" },
    .{ "gen/case.c", "gen/case.h" },
    .{ "gen/character.c", "gen/character.h" },
    .{ "gen/line.c", "gen/line.h" },
    .{ "gen/sentence.c", "gen/sentence.h" },
    .{ "gen/word.c", "gen/word.h" },
};

const man3_scripts = [_][]const u8{
    "man/grapheme_decode_utf8.sh",
    "man/grapheme_encode_utf8.sh",
    "man/grapheme_is_character_break.sh",
    "man/grapheme_is_uppercase.sh",
    "man/grapheme_is_uppercase_utf8.sh",
    "man/grapheme_is_lowercase.sh",
    "man/grapheme_is_lowercase_utf8.sh",
    "man/grapheme_is_titlecase.sh",
    "man/grapheme_is_titlecase_utf8.sh",
    "man/grapheme_next_character_break.sh",
    "man/grapheme_next_line_break.sh",
    "man/grapheme_next_sentence_break.sh",
    "man/grapheme_next_word_break.sh",
    "man/grapheme_next_character_break_utf8.sh",
    "man/grapheme_next_line_break_utf8.sh",
    "man/grapheme_next_sentence_break_utf8.sh",
    "man/grapheme_next_word_break_utf8.sh",
    "man/grapheme_to_uppercase.sh",
    "man/grapheme_to_uppercase_utf8.sh",
    "man/grapheme_to_lowercase.sh",
    "man/grapheme_to_lowercase_utf8.sh",
    "man/grapheme_to_titlecase.sh",
    "man/grapheme_to_titlecase_utf8.sh",
};

const man7_scripts = [_][]const u8{
    "man/libgrapheme.sh",
};

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
