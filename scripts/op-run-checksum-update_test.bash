#!/usr/bin/env bash
# Tests for scripts/op-run-checksum-update.
#
# The regenerator is a small Algorithm (Khorikov): given the manifest
# + filesystem, produce a deterministic sha256sum-format file. Tests
# assert observable properties of the committed op-run/checksums file
# (sha256sum format, manifest coverage, deterministic sort), plus an
# idempotence check via regenerate-into-tempfile-and-diff.

## format -- every line is '<64 hex>  <path>'

test_checksums_lines_sha256sum_format() {
  local line
  while IFS= read -r line; do
    [[ $line =~ ^[0-9a-f]{64}\ \ .+$ ]] \
      || { echo "malformed checksums line: $line"; return 1; }
  done < op-run/checksums
}

## manifest coverage -- every manifest path has a checksums line

test_checksums_covers_manifest() {
  local -a expected=(
    scripts/op-run
    op-run/projects.bash
  )
  # Add every present machine allowlist. Enable globbing + nullglob locally;
  # tesht inherits dotfiles' set -o noglob via the test-file source.
  set +o noglob
  shopt -s nullglob
  local f
  for f in op-run/machines/*.allow; do
    expected+=("$f")
  done

  local -a got
  mapfile -t got < <(awk '{print $2}' op-run/checksums)

  local exp
  for exp in "${expected[@]}"; do
    local found=0 g
    for g in "${got[@]}"; do
      [[ $g == "$exp" ]] && { found=1; break; }
    done
    (( found )) || { echo "expected manifest path missing from checksums: $exp"; return 1; }
  done
}

## sort order -- paths in deterministic LC_ALL=C lexicographic order

test_checksums_path_sorted() {
  local -a paths sorted
  mapfile -t paths < <(awk '{print $2}' op-run/checksums)
  mapfile -t sorted < <(printf '%s\n' "${paths[@]}" | LC_ALL=C sort)

  local got want
  got=$(printf '%s\n' "${paths[@]}")
  want=$(printf '%s\n' "${sorted[@]}")
  tesht.AssertGot "$got" "$want"
}

## sha256sum --check passes against the live tree

test_checksums_verify_against_tree() {
  local rc=0
  sha256sum --quiet --check op-run/checksums >/dev/null 2>&1 || rc=$?
  tesht.AssertRC $rc 0
}

## idempotence -- regenerate, diff against committed; restore on exit

test_regenerator_idempotent() {
  local backup
  backup=$(mktemp)
  trap "mv $backup op-run/checksums" RETURN
  cp op-run/checksums "$backup"

  bash scripts/op-run-checksum-update 2>/dev/null
  local rc=0
  diff "$backup" op-run/checksums >/dev/null || rc=$?
  tesht.AssertRC $rc 0
}
