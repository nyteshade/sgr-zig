const std = @import("std");
const Io = std.Io;

const Color = struct {
  name: []const u8,
  index: u8,
};

const colors = [_]Color{
  .{ .name = "black", .index = 0 },
  .{ .name = "red", .index = 1 },
  .{ .name = "green", .index = 2 },
  .{ .name = "yellow", .index = 3 },
  .{ .name = "blue", .index = 4 },
  .{ .name = "magenta", .index = 5 },
  .{ .name = "cyan", .index = 6 },
  .{ .name = "white", .index = 7 },
};

const Styles = struct {
  owned_open_codes: []const []const u8,
  owned_close_codes: []const []const u8,
  open_codes: []const []const u8,
  close_codes: []const []const u8,
  noline: bool,

  fn deinit(self: Styles, allocator: std.mem.Allocator) void {
    allocator.free(self.owned_open_codes);
    allocator.free(self.owned_close_codes);
  }
};

const StyleBuilder = struct {
  open_codes: [][]const u8,
  close_codes: [][]const u8,
  open_count: usize = 0,
  close_count: usize = 0,
  noline: bool = false,

  fn append(self: *StyleBuilder, open: []const u8, close: []const u8) void {
    self.open_codes[self.open_count] = open;
    self.open_count += 1;

    self.close_codes[self.close_count] = close;
    self.close_count += 1;
  }

  fn finish(self: *const StyleBuilder) Styles {
    return .{
      .owned_open_codes = self.open_codes,
      .owned_close_codes = self.close_codes,
      .open_codes = self.open_codes[0..self.open_count],
      .close_codes = self.close_codes[0..self.close_count],
      .noline = self.noline,
    };
  }
};

pub fn main(init: std.process.Init) !void {
  const allocator = init.gpa;
  const args = try init.minimal.args.toSlice(init.arena.allocator());

  if (args.len < 3) {
    var stderr_buffer: [1024]u8 = undefined;
    var stderr_writer: Io.File.Writer = .init(
      .stderr(),
      init.io,
      &stderr_buffer,
    );

    try usage(&stderr_writer.interface);
    std.process.exit(1);
  }

  const styles = try parseStyles(allocator, args[2..]);
  defer styles.deinit(allocator);

  var stdout_buffer: [1024]u8 = undefined;
  var stdout_writer: Io.File.Writer = .init(
    .stdout(),
    init.io,
    &stdout_buffer,
  );
  const stdout = &stdout_writer.interface;

  for (styles.open_codes) |code| {
    try stdout.writeAll(code);
  }

  try stdout.writeAll(args[1]);

  var i = styles.close_codes.len;
  while (i > 0) {
    i -= 1;
    try stdout.writeAll(styles.close_codes[i]);
  }

  if (!styles.noline) {
    try stdout.writeByte('\n');
  }

  try stdout.flush();
}

fn usage(writer: *Io.Writer) !void {
  try writer.writeAll(
    "Usage: sgr \"message\" \"mode1\" [\"mode2\" ...]\n",
  );

  try writer.flush();
}

fn parseStyles(
  allocator: std.mem.Allocator,
  raw_modes: []const []const u8,
) !Styles {
  const max_codes = countModeBytes(raw_modes) + raw_modes.len;
  const open_codes = try allocator.alloc([]const u8, max_codes);
  errdefer allocator.free(open_codes);

  const close_codes = try allocator.alloc([]const u8, max_codes);
  errdefer allocator.free(close_codes);

  var builder = StyleBuilder{
    .open_codes = open_codes,
    .close_codes = close_codes,
  };

  for (raw_modes) |arg| {
    var parts = std.mem.splitScalar(u8, arg, ',');

    while (parts.next()) |part| {
      const mode = try lowerAlloc(allocator, part);
      defer allocator.free(mode);

      if (std.mem.eql(u8, mode, "noline")) {
        builder.noline = true;
        continue;
      }

      if (shouldExpandAsModeCharacters(mode)) {
        processModeChar(&builder, mode[0]);

        continue;
      }

      processMode(&builder, mode);
    }
  }

  return builder.finish();
}

fn countModeBytes(raw_modes: []const []const u8) usize {
  var total: usize = 0;

  for (raw_modes) |mode| {
    total += mode.len;
  }

  return total;
}

fn lowerAlloc(
  allocator: std.mem.Allocator,
  value: []const u8,
) ![]u8 {
  const lowered = try allocator.alloc(u8, value.len);

  for (value, 0..) |char, index| {
    lowered[index] = std.ascii.toLower(char);
  }

  return lowered;
}

fn shouldExpandAsModeCharacters(mode: []const u8) bool {
  return !containsColor(mode) and
    mode.len > 1 and
    containsOnlyModeCharacters(mode) and
    !containsColorSpecifier(mode);
}

fn containsColor(mode: []const u8) bool {
  for (colors) |color| {
    if (std.mem.indexOf(u8, mode, color.name) != null) {
      return true;
    }
  }

  return false;
}

fn containsOnlyModeCharacters(mode: []const u8) bool {
  for (mode) |char| {
    switch (char) {
      'b', 'i', 'u', 'k', 's', 'd', 'c', 'n' => {},
      else => return false,
    }
  }

  return true;
}

fn containsColorSpecifier(mode: []const u8) bool {
  return std.mem.indexOf(u8, mode, "fg") != null or
    std.mem.indexOf(u8, mode, "bg") != null or
    std.mem.indexOf(u8, mode, "bright") != null;
}

fn processModeChar(builder: *StyleBuilder, char: u8) void {
  switch (char) {
    'k' => builder.append("\x1b[5m", "\x1b[25m"),
    'b' => builder.append("\x1b[1m", "\x1b[22m"),
    'c' => builder.append("\x1b[8m", "\x1b[28m"),
    'd' => builder.append("\x1b[2m", "\x1b[22m"),
    'i' => builder.append("\x1b[3m", "\x1b[23m"),
    'n' => builder.append("\x1b[7m", "\x1b[27m"),
    's' => builder.append("\x1b[9m", "\x1b[29m"),
    'u' => builder.append("\x1b[4m", "\x1b[24m"),
    else => {},
  }
}

fn processMode(builder: *StyleBuilder, mode: []const u8) void {
  const is_bg = std.mem.indexOf(u8, mode, "bg") != null;
  const is_bright = std.mem.indexOf(u8, mode, "bright") != null;

  if (colorIndex(mode)) |index| {
    processColor(builder, index, is_bg, is_bright);
    return;
  }

  if (std.mem.eql(u8, mode, "blink") or std.mem.eql(u8, mode, "k")) {
    builder.append("\x1b[5m", "\x1b[25m");
  }
  else if (std.mem.eql(u8, mode, "bold") or std.mem.eql(u8, mode, "b")) {
    builder.append("\x1b[1m", "\x1b[22m");
  }
  else if (std.mem.eql(u8, mode, "conceal") or std.mem.eql(u8, mode, "c")) {
    builder.append("\x1b[8m", "\x1b[28m");
  }
  else if (std.mem.eql(u8, mode, "dim") or std.mem.eql(u8, mode, "d")) {
    builder.append("\x1b[2m", "\x1b[22m");
  }
  else if (std.mem.eql(u8, mode, "italics") or std.mem.eql(u8, mode, "i")) {
    builder.append("\x1b[3m", "\x1b[23m");
  }
  else if (std.mem.eql(u8, mode, "negative") or std.mem.eql(u8, mode, "n")) {
    builder.append("\x1b[7m", "\x1b[27m");
  }
  else if (std.mem.eql(u8, mode, "strike") or std.mem.eql(u8, mode, "s")) {
    builder.append("\x1b[9m", "\x1b[29m");
  }
  else if (std.mem.eql(u8, mode, "underline") or std.mem.eql(u8, mode, "u")) {
    builder.append("\x1b[4m", "\x1b[24m");
  }
}

fn colorIndex(mode: []const u8) ?u8 {
  for (colors) |color| {
    if (std.mem.indexOf(u8, mode, color.name) != null) {
      return color.index;
    }
  }

  return null;
}

fn processColor(
  builder: *StyleBuilder,
  index: u8,
  is_bg: bool,
  is_bright: bool,
) void {
  if (is_bg) {
    if (is_bright) {
      builder.append(brightBackgroundCode(index), "\x1b[49m");
    }
    else {
      builder.append(backgroundCode(index), "\x1b[49m");
    }
  }
  else {
    if (is_bright) {
      builder.append(brightForegroundCode(index), "\x1b[39m");
    }
    else {
      builder.append(foregroundCode(index), "\x1b[39m");
    }
  }
}

fn foregroundCode(index: u8) []const u8 {
  return switch (index) {
    0 => "\x1b[30m",
    1 => "\x1b[31m",
    2 => "\x1b[32m",
    3 => "\x1b[33m",
    4 => "\x1b[34m",
    5 => "\x1b[35m",
    6 => "\x1b[36m",
    7 => "\x1b[37m",
    else => unreachable,
  };
}

fn backgroundCode(index: u8) []const u8 {
  return switch (index) {
    0 => "\x1b[40m",
    1 => "\x1b[41m",
    2 => "\x1b[42m",
    3 => "\x1b[43m",
    4 => "\x1b[44m",
    5 => "\x1b[45m",
    6 => "\x1b[46m",
    7 => "\x1b[47m",
    else => unreachable,
  };
}

fn brightForegroundCode(index: u8) []const u8 {
  return switch (index) {
    0 => "\x1b[90m",
    1 => "\x1b[91m",
    2 => "\x1b[92m",
    3 => "\x1b[93m",
    4 => "\x1b[94m",
    5 => "\x1b[95m",
    6 => "\x1b[96m",
    7 => "\x1b[97m",
    else => unreachable,
  };
}

fn brightBackgroundCode(index: u8) []const u8 {
  return switch (index) {
    0 => "\x1b[100m",
    1 => "\x1b[101m",
    2 => "\x1b[102m",
    3 => "\x1b[103m",
    4 => "\x1b[104m",
    5 => "\x1b[105m",
    6 => "\x1b[106m",
    7 => "\x1b[107m",
    else => unreachable,
  };
}

test "parses color and text modes" {
  const styles = try parseStyles(std.testing.allocator, &.{
    "green,bold",
  });
  defer styles.deinit(std.testing.allocator);

  try std.testing.expectEqualStrings("\x1b[32m", styles.open_codes[0]);
  try std.testing.expectEqualStrings("\x1b[1m", styles.open_codes[1]);
  try std.testing.expectEqualStrings("\x1b[22m", styles.close_codes[1]);
  try std.testing.expectEqualStrings("\x1b[39m", styles.close_codes[0]);
}

test "matches Bash compact shorthand behavior" {
  const styles = try parseStyles(std.testing.allocator, &.{"bu"});
  defer styles.deinit(std.testing.allocator);

  try std.testing.expectEqualStrings("\x1b[1m", styles.open_codes[0]);
  try std.testing.expectEqual(@as(usize, 1), styles.open_codes.len);
}

test "parses bright background colors and noline" {
  const styles = try parseStyles(std.testing.allocator, &.{
    "bluebgbright",
    "noline",
  });
  defer styles.deinit(std.testing.allocator);

  try std.testing.expect(styles.noline);
  try std.testing.expectEqualStrings("\x1b[104m", styles.open_codes[0]);
  try std.testing.expectEqualStrings("\x1b[49m", styles.close_codes[0]);
}
