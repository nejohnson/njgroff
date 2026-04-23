#!/bin/sh
#
# Copyright (C) 2025 Free Software Foundation, Inc.
#
# This file is part of groff.
#
# groff is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# groff is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Test ".so[5 filename" — missing closing ']'.
#
# Behaviour after the stream-corruption fix:
#
# get_line_range() now returns the character that terminated its loop
# (']', '\n', or EOF) rather than calling getc() itself after the range.
#
# With input "[5 filename\n":
#   - '5' is a digit -> s=5
#   - ' ' (space) is not digit/'-'/'+' -> state=SKIPPING
#   - remaining chars up to '\n' are consumed (SKIPPING)
#   - loop exits on '\n'; get_line_range returns '\n'
#   - state=SKIPPING triggers "bad line range spec, skipping..." on stderr
#
# Back in the HAD_so handler:
#   - returned c='\n' is not ']', so "missing closing ']'" is also emitted
#   - the '\n' is NOT consumed by a second getc(), so stream position is
#     intact
#   - filename-gather loop sees c='\n' immediately and does not execute
#   - do_so() receives an empty filename and passes ".so" through to stdout
#
# Summary:
#   - stderr: "bad line range spec, skipping..." AND
#             "missing closing ']' in line range spec, skipping..."
#   - stdout: ".so" (directive passed through, empty argument)
#   - exit code: 0

soelim="${SOELIM:-$HOME/Apps/bin/soelim}"

fail=

wail () {
  echo "...FAILED: $*" >&2
  fail=yes
}

tmpinc="soelim-inc-miss-brk-$$.txt"
tmperr="soelim-err-miss-brk-$$.txt"

cleanup () {
  rm -f "$tmpinc" "$tmperr"
}

fatals="HUP INT QUIT TERM"
for s in $fatals
do
  trap "trap '' $fatals; cleanup; trap - $fatals; kill -$s -$$" $s
done

printf 'This is line 1.\nThis is line 2.\nThis is line 3.\nThis is line 4.\nThis is line 5.\n\n' \
  > "$tmpinc"

# Input has no closing ']' — the space after the digit triggers SKIPPING.
# The newline terminates get_line_range, consuming the line.  The
# following getc() hits EOF (single-line pipe), leaving an empty
# filename.
output=$(printf '.so[5 %s\n' "$tmpinc" | "$soelim" -r 2>"$tmperr")
exit_code=$?

# soelim must not crash (exit 0)
test "$exit_code" -eq 0 \
  || wail "missing ']': expected exit 0, got $exit_code"

# stderr should report both a bad range error and a missing-bracket error
grep -Fq "bad line range" "$tmperr" \
  || wail "missing ']': expected 'bad line range' on stderr; got: $(cat "$tmperr")"
grep -Fq "missing closing ']'" "$tmperr" \
  || wail "missing ']': expected missing-bracket error on stderr; got: $(cat "$tmperr")"

# stdout: ".so" is passed through (empty filename, directive preserved)
echo "$output" | grep -Fq ".so" \
  || wail "missing ']': expected '.so' on stdout; got: $output"

# None of the included file's content should appear
echo "$output" | grep -Fq "This is line" \
  && wail "missing ']': file content unexpectedly appeared in output"

cleanup
test -z "$fail"

# vim:set autoindent expandtab shiftwidth=2 tabstop=2 textwidth=72:
