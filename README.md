# sgr

`sgr` is a small Zig command-line tool that prints text wrapped in ANSI SGR
(Select Graphic Rendition) escape sequences.

This project is a byte-compatible port of the Bash `sgr` function from
`~/.local/scripts/shared/fn.sgr`. The compatibility target is the Bash
function's observed behavior, including its quirks, rather than the behavior its
comments might imply.

## Features

- Writes styled terminal text using ANSI SGR escape codes.
- Supports foreground and background colors.
- Supports normal and bright color variants.
- Supports common text attributes such as bold, underline, dim, italics, blink,
  conceal, inverse, and strikethrough.
- Accepts modes as separate arguments or comma-separated lists.
- Supports a `noline` mode to suppress the trailing newline.
- Preserves the Bash function's reset ordering and compact-shorthand behavior.

## Requirements

- Zig 0.16.0 or newer.
- A terminal or output consumer that understands ANSI escape sequences.
- Bash and `xxd` only if you want to run the compatibility check script.

## Build

```sh
zig build
```

The executable is written to:

```sh
zig-out/bin/sgr
```

You can also run the tool through Zig:

```sh
zig build run -- "Hello" "green,bold"
```

## Usage

```sh
sgr "message" "mode1" ["mode2" ...]
```

At least one message and one mode are required. The message is emitted between
opening SGR codes and closing reset codes. Unless `noline` is present, `sgr`
prints a trailing newline.

Examples:

```sh
zig-out/bin/sgr "Hello" "red"
zig-out/bin/sgr "World" "green,bold"
zig-out/bin/sgr "Warning" "yellow" "bold"
zig-out/bin/sgr "Selected" "white" "bluebg"
zig-out/bin/sgr "Bright background" "bluebgbright"
zig-out/bin/sgr "No newline" "yellow" "noline"
```

When no terminal rendering is desired, inspect the output bytes instead:

```sh
zig-out/bin/sgr "Hello" "red" | xxd -p
```

## Modes

Modes are case-insensitive. A single command may pass modes as separate
arguments, comma-separated parts, or a mixture of both:

```sh
sgr "Text" "green,bold"
sgr "Text" "green" "bold"
sgr "Text" "green,bold" "underline" "noline"
```

Unknown modes are ignored, matching the source Bash function's permissive
behavior.

### Colors

The supported base colors are:

- `black`
- `red`
- `green`
- `yellow`
- `blue`
- `magenta`
- `cyan`
- `white`

By default, a color applies to the foreground:

```sh
sgr "Error" "red"
```

Add `bg` anywhere in the mode to make it a background color:

```sh
sgr "Badge" "bluebg"
sgr "Badge" "bgblue"
```

Add `bright` anywhere in the mode to use the bright color range:

```sh
sgr "Notice" "brightcyan"
sgr "Notice" "cyanbright"
sgr "Badge" "bluebgbright"
```

Internally, the color codes are:

| Color | Foreground | Background | Bright foreground | Bright background |
| --- | ---: | ---: | ---: | ---: |
| black | 30 | 40 | 90 | 100 |
| red | 31 | 41 | 91 | 101 |
| green | 32 | 42 | 92 | 102 |
| yellow | 33 | 43 | 93 | 103 |
| blue | 34 | 44 | 94 | 104 |
| magenta | 35 | 45 | 95 | 105 |
| cyan | 36 | 46 | 96 | 106 |
| white | 37 | 47 | 97 | 107 |

Foreground colors close with `39`; background colors close with `49`.

### Text attributes

| Mode | Shorthand | Opens | Closes |
| --- | --- | ---: | ---: |
| `blink` | `k` | 5 | 25 |
| `bold` | `b` | 1 | 22 |
| `conceal` | `c` | 8 | 28 |
| `dim` | `d` | 2 | 22 |
| `italics` | `i` | 3 | 23 |
| `negative` | `n` | 7 | 27 |
| `strike` | `s` | 9 | 29 |
| `underline` | `u` | 4 | 24 |

Examples:

```sh
sgr "Important" "bold"
sgr "Important" "b"
sgr "Link-like" "blue,underline"
sgr "Muted" "dim"
```

### `noline`

The `noline` mode suppresses the final newline:

```sh
zig-out/bin/sgr "prompt> " "green" "noline"
```

This is useful for prompts or for composing output with subsequent writes.

## Compatibility notes

This tool intentionally matches the Bash source function's observable behavior.
A few details are worth knowing:

- Opening SGR codes are emitted in the order modes are encountered.
- Closing reset codes are emitted in reverse order, so nested styles unwind in a
  stack-like way.
- Mode parsing is substring-based for colors and color specifiers. For example,
  `bluebgbright`, `brightbluebg`, and `bgbluebright` all select bright blue
  background.
- Unknown modes do not fail the command; they simply produce no style code.
- Compact shorthand strings made only of text-mode shorthand letters apply only
  the first character. For example, `bu` applies `bold` but not `underline`.
  This preserves the current Bash function's observed behavior.

## Testing

Run the Zig unit tests:

```sh
zig build test
```

Build the executable:

```sh
zig build
```

Run the Bash-vs-Zig compatibility checks:

```sh
./check-equivalence.sh
```

The equivalence script sources `/Users/brie/.local/scripts/shared/fn.sgr`, builds
against the binary at `/private/tmp/test/zig-out/bin/sgr`, and compares selected
outputs as hex. It currently covers colors, comma-separated modes, bright
backgrounds, `noline`, compact shorthand, and multi-argument modes.

Expected success output:

```text
All equivalence checks passed.
```

## Development notes

The main implementation lives in `src/main.zig` and the build definition lives
in `build.zig`.

Useful commands during development:

```sh
zig build test
zig build
./check-equivalence.sh
```

If changing parsing behavior, add or update tests in `src/main.zig` and extend
`check-equivalence.sh` with a byte-level comparison against the Bash function.
Terminal rendering can hide differences in escape-code order, reset code choice,
or trailing newline behavior, so prefer hex or file comparisons when validating
compatibility.
