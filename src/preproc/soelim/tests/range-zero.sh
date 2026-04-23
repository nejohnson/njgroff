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
# Test all explicit-zero cases — line numbers start at 1, so 0 is always
# invalid wherever it appears.  soelim should emit "bad line range spec,
# skipping..." and fall back to full file inclusion for every case below.
#
# Zero start:   [0], [0-5], [0+5], [0+], [0-0]
# Zero end:     [5-0], [-0]
#
# The parser uses -1 as a "not specified" sentinel for both start and
# end, so an explicitly parsed 0 is always distinguishable from an
# omitted value regardless of position.

soelim="${SOELIM:-$HOME/Apps/bin/soelim}"

fail=

wail () {
  echo "...FAILED: $*" >&2
  fail=yes
}

tmpinc="soelim-inc-zero-$$.txt"
tmperr="soelim-err-zero-$$.txt"

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

# Test [0]: explicit zero start — error + full file fallback
output=$(printf '.so[0] %s\n' "$tmpinc" | "$soelim" -r 2>"$tmperr")
exit_code=$?

test "$exit_code" -eq 0 || wail "[0]: expected exit 0, got $exit_code"
grep -Fq "bad line range" "$tmperr" \
  || wail "[0]: expected 'bad line range' on stderr; got: $(cat "$tmperr")"
echo "$output" | grep -Fq "This is line 1." \
  || wail "[0]: fallback full file missing line 1"
echo "$output" | grep -Fq "This is line 5." \
  || wail "[0]: fallback full file missing line 5"

check_bad_range () {
  spec="$1"
  output=$(printf ".so${spec} %s\n" "$tmpinc" | "$soelim" -r 2>"$tmperr")
  exit_code=$?
  test "$exit_code" -eq 0 \
    || wail "${spec}: expected exit 0, got $exit_code"
  grep -Fq "bad line range" "$tmperr" \
    || wail "${spec}: expected 'bad line range' on stderr; got: $(cat "$tmperr")"
  echo "$output" | grep -Fq "This is line 1." \
    || wail "${spec}: fallback full file missing line 1"
  echo "$output" | grep -Fq "This is line 5." \
    || wail "${spec}: fallback full file missing line 5"
}

# Zero start cases
check_bad_range "[0-5]"   # explicit zero start, explicit end
check_bad_range "[0+5]"   # explicit zero start, relative range
check_bad_range "[0+]"    # explicit zero start, empty relative
check_bad_range "[0-0]"   # both zero

# Zero end cases
check_bad_range "[5-0]"   # valid start, explicit zero end
check_bad_range "[-0]"    # unspecified start, explicit zero end

cleanup
test -z "$fail"

# vim:set autoindent expandtab shiftwidth=2 tabstop=2 textwidth=72:
