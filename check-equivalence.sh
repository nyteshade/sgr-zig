#!/usr/bin/env bash
set -euo pipefail

source /Users/brie/.local/scripts/shared/fn.sgr

zig_bin=/private/tmp/test/zig-out/bin/sgr
cases=(
  $'Hello\tred'
  $'World\tgreen,bold'
  $'Example\tbluebgbright'
  $'NoLine\tyellow\tnoline'
  $'Shorthand\tbu'
  $'Multi\tred\tbold\tunderline'
)

for case in "${cases[@]}"; do
  IFS=$'\t' read -r -a parts <<< "$case"
  message=${parts[0]}
  modes=("${parts[@]:1}")

  expected=$(sgr "$message" "${modes[@]}" | xxd -p)
  actual=$("$zig_bin" "$message" "${modes[@]}" | xxd -p)

  if [[ "$expected" != "$actual" ]]; then
    echo "Mismatch for: $message ${modes[*]}" >&2
    echo "expected: $expected" >&2
    echo "actual:   $actual" >&2
    exit 1
  fi

done

echo "All equivalence checks passed."
