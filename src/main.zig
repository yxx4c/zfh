const std = @import("std");
const logo = @import("logo.zig");
const color = @import("color.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const writer = std.io.getStdOut().writer();
    var buffer = std.io.bufferedWriter(writer);
    const out = buffer.writer();

    const uname = std.posix.uname();
    const arch = uname.machine;
    const kernel = uname.release;
    const nodename: []const u8 = try getNonNullPaddedString(try std.fmt.allocPrint(allocator, "{s}", .{uname.nodename}));

    const os_logo = try logo.getLogo(nodename);
    const x_axis = os_logo.width + 4;
    const y_axis = os_logo.height + 1;

    var hbuff: [128:0]u8 = undefined;
    const hostname = try std.posix.gethostname(&hbuff);
    const user = std.c.getpwuid(std.os.linux.geteuid()).?;
    const username = std.mem.span(user.pw_name.?);
    const shell = getFinalFileNameFromPath(std.mem.span(user.pw_shell.?));

    const os = try getOs(allocator);
    const pkgs = try getPackagesCount();
    const uptime = try getUptime(allocator);
    const memory = try getMemory(allocator);
    const mem_total = try getReadableDataUnit(memory.total * 1024, allocator);
    const mem_used = try getReadableDataUnit(memory.used * 1024, allocator);

    try printArt(os_logo.art, y_axis, out);

    try printInfo(allocator, "{s}{s}@{s}{s}\n", .{ color.MAGENTA, username, hostname, color.RESET }, x_axis, out);
    try printInfo(allocator, "{s}os{s}       {s}\n", .{ color.BLUE, color.RESET, os }, x_axis, out);
    try printInfo(allocator, "{s}arch{s}     {s}\n", .{ color.BLUE, color.RESET, arch }, x_axis, out);
    try printInfo(allocator, "{s}shell{s}    {s}\n", .{ color.BLUE, color.RESET, shell }, x_axis, out);
    try printInfo(allocator, "{s}pkgs{s}     {d}\n", .{ color.BLUE, color.RESET, pkgs }, x_axis, out);
    try printInfo(allocator, "{s}uptime{s}   {s}\n", .{ color.BLUE, color.RESET, uptime }, x_axis, out);
    try printInfo(allocator, "{s}memory{s}   {s}/{s}\n", .{ color.BLUE, color.RESET, mem_used, mem_total }, x_axis, out);
    try printInfo(allocator, "{s}kernel{s}   {s}\n", .{ color.BLUE, color.RESET, kernel }, x_axis, out);

    try printColorPallete(x_axis, out);

    try buffer.flush();
}

fn getOs(allocator: std.mem.Allocator) ![]const u8 {
    const os_release = try getFileContent("/etc/os-release", allocator, true);

    var os: []const u8 = "Linux";
    var infos = std.mem.splitSequence(u8, os_release, "\n");

    while (infos.next()) |info| {
        if (std.mem.startsWith(u8, info, "NAME")) {
            os = info[6 .. info.len - 1];
            break;
        }
    }

    return os;
}

fn getPackagesCount() !usize {
    const packages = try getDirContentCount("/var/lib/pacman/local");

    return packages;
}

fn getUptime(allocator: std.mem.Allocator) ![]const u8 {
    const uptime_string = try getFileContent("/proc/uptime", allocator, true);

    var uptimes = std.mem.splitSequence(u8, uptime_string, " ");
    const uptime_ms = uptimes.next().?;
    const uptime = try getReadableTime(uptime_ms, allocator);

    return uptime;
}

const Memory = struct {
    total: u64,
    used: u64,
};

fn getMemory(allocator: std.mem.Allocator) !Memory {
    const meminfo = try getFileContent("/proc/meminfo", allocator, true);

    var memtotal: u64 = 0;
    var memused: u64 = 0;
    var memavail: ?u64 = null;

    var infos = std.mem.splitAny(u8, meminfo, ":k\n");

    while (infos.next()) |info| {
        const slice = std.mem.trim(u8, info, " ");

        if (std.mem.eql(u8, slice, "MemTotal")) {
            const val = try std.fmt.parseInt(u64, std.mem.trim(u8, infos.next().?, " "), 10);
            memtotal = val;
            memused += val;
        } else if (std.mem.eql(u8, slice, "Shmem")) {
            memused += try std.fmt.parseInt(u64, std.mem.trim(u8, infos.next().?, " "), 10);
        } else if (std.mem.eql(u8, slice, "MemFree") or std.mem.eql(u8, slice, "Buffers") or std.mem.eql(u8, slice, "Cached") or std.mem.eql(u8, slice, "SReclaimable")) {
            memused -= try std.fmt.parseInt(u64, std.mem.trim(u8, infos.next().?, " "), 10);
        } else if (std.mem.eql(u8, slice, "MemAvailable")) {
            memavail = try std.fmt.parseInt(u64, std.mem.trim(u8, infos.next().?, " "), 10);
        }
    }

    if (memavail != null) {
        memused = memtotal - memavail.?;
    }

    return Memory{ .total = memtotal, .used = memused };
}

fn printArt(art: []const u8, y_axis: usize, out: anytype) !void {
    try out.print("\n{s}\n", .{art});
    try out.print("\x1b[{d}A", .{y_axis});
}

fn printInfo(allocator: std.mem.Allocator, comptime format: []const u8, args: anytype, x_axis: usize, out: anytype) !void {
    const content = try std.fmt.allocPrint(allocator, format, args);

    try out.print("\x1b[{d}C{s}", .{ x_axis, content });
}

fn printColorPallete(x_axis: usize, out: anytype) !void {
    const glyph = "\u{2726}";

    try out.print("\x1b[{d}C", .{x_axis});

    for (0..8) |i| {
        try out.print("\x1b[3{d}m{s}\x1b[0m ", .{ 7 - i, glyph });
    }

    try out.print("\n", .{});
}

fn getDirContentCount(path: []const u8) !usize {
    var dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
    defer dir.close();

    var count: usize = 0;
    var dirIterator = dir.iterate();

    while (try dirIterator.next()) |_| {
        count += 1;
    }

    count -= 1;

    return count;
}

fn getFileContent(path: []const u8, allocator: std.mem.Allocator, trimmed: bool) ![]const u8 {
    const file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
    defer file.close();

    const max_bytes = 1 << 22;
    const content = try file.readToEndAlloc(allocator, max_bytes);
    if (trimmed) {
        return std.mem.trim(u8, content, "\n");
    }

    return content;
}

fn getFinalFileNameFromPath(path: []const u8) []const u8 {
    const lastIndex = std.mem.lastIndexOfLinear(u8, path, "/").?;
    const fileName = path[lastIndex + 1 ..];

    return fileName;
}

fn getReadableTime(time: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const ms = try std.fmt.parseFloat(f64, time);

    const days = @divFloor(ms, 86400);
    const hours = @divFloor(@rem(ms, 86400), 3600);
    const minutes = @divFloor(@rem(ms, 3600), 60);
    const seconds = @floor(@rem(ms, 60));

    var readableTime: []const u8 = "";

    if (days > 0) {
        readableTime = try std.mem.concat(allocator, u8, &[_][]const u8{
            readableTime,
            try std.fmt.allocPrint(allocator, "{d}d ", .{days}),
        });
    }

    if (hours > 0) {
        readableTime = try std.mem.concat(allocator, u8, &[_][]const u8{
            readableTime,
            try std.fmt.allocPrint(allocator, "{d}h ", .{hours}),
        });
    }

    if (minutes > 0) {
        readableTime = try std.mem.concat(allocator, u8, &[_][]const u8{
            readableTime,
            try std.fmt.allocPrint(allocator, "{d}m ", .{minutes}),
        });
    }

    if (seconds > 0) {
        readableTime = try std.mem.concat(allocator, u8, &[_][]const u8{
            readableTime,
            try std.fmt.allocPrint(allocator, "{d}s", .{seconds}),
        });
    }

    return readableTime;
}

fn getReadableDataUnit(size: u64, allocator: std.mem.Allocator) ![]const u8 {
    const suffixes = [_][]const u8{ "B", "KB", "MB", "GB", "TB", "PB", "EB" };
    const base = 1024.0;

    var index: usize = 0;
    var value: f64 = @floatFromInt(size);

    while (value >= base and index < suffixes.len - 1) {
        value /= base;
        index += 1;
    }

    const readableDataUnit = try std.fmt.allocPrint(allocator, "{d}{s}", .{ @floor(value), suffixes[index] });

    return readableDataUnit;
}

fn getNonNullPaddedString(padded_string: []const u8) ![]const u8 {
    const length = std.mem.indexOf(u8, padded_string, "\x00") orelse padded_string.len;
    const trimmed_string = padded_string[0..length];

    return trimmed_string;
}
