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
# Test [S-E] where S > E (inverted/bad range).
# Expected behaviour: error to stderr, fall back to full file inclusion,
# soelim exits 0.

soelim="${SOELIM:-$HOME/Apps/bin/soelim}"

fail=

wail () {
  echo "...FAILED: $*" >&2
  fail=yes
}

tmpinc="soelim-inc-bad-inv-$$.txt"
tmperr="soelim-err-bad-inv-$$.txt"

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

output=$(printf '.so[3-1] %s\n' "$tmpinc" | "$soelim" -r 2>"$tmperr")
exit_code=$?

# soelim should exit 0 (it reports the error but continues processing)
test "$exit_code" -eq 0 || wail "[3-1]: expected exit 0, got $exit_code"

# stderr should contain a "Bad line range" error message
grep -Fq "bad line range" "$tmperr" \
  || wail "[3-1]: expected 'bad line range' on stderr; got: $(cat "$tmperr")"

# Output should fall back to full file inclusion
echo "$output" | grep -Fq "This is line 1." \
  || wail "[3-1]: fallback full file missing line 1"
echo "$output" | grep -Fq "This is line 2." \
  || wail "[3-1]: fallback full file missing line 2"
echo "$output" | grep -Fq "This is line 3." \
  || wail "[3-1]: fallback full file missing line 3"
echo "$output" | grep -Fq "This is line 4." \
  || wail "[3-1]: fallback full file missing line 4"
echo "$output" | grep -Fq "This is line 5." \
  || wail "[3-1]: fallback full file missing line 5"

cleanup
test -z "$fail"

# vim:set autoindent expandtab shiftwidth=2 tabstop=2 textwidth=72:
