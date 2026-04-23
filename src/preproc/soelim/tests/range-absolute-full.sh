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
# Test forms that include the entire file: [-] and [1-].

soelim="${SOELIM:-$HOME/Apps/bin/soelim}"

fail=

wail () {
  echo "...FAILED: $*" >&2
  fail=yes
}

tmpinc="soelim-inc-abs-full-$$.txt"

cleanup () {
  rm -f "$tmpinc"
}

fatals="HUP INT QUIT TERM"
for s in $fatals
do
  trap "trap '' $fatals; cleanup; trap - $fatals; kill -$s -$$" $s
done

printf 'This is line 1.\nThis is line 2.\nThis is line 3.\nThis is line 4.\nThis is line 5.\n\n' \
  > "$tmpinc"

check_all_lines () {
  local spec="$1"
  local out="$2"
  echo "$out" | grep -Fq "This is line 1." || wail "${spec}: line 1 missing"
  echo "$out" | grep -Fq "This is line 2." || wail "${spec}: line 2 missing"
  echo "$out" | grep -Fq "This is line 3." || wail "${spec}: line 3 missing"
  echo "$out" | grep -Fq "This is line 4." || wail "${spec}: line 4 missing"
  echo "$out" | grep -Fq "This is line 5." || wail "${spec}: line 5 missing"
}

# .so[-] should include all 5 lines (open range)
out_dash=$(printf '.so[-] %s\n' "$tmpinc" | "$soelim" -r)
check_all_lines "[-]" "$out_dash"

# .so[1-] should include all 5 lines (explicit start, open end)
out_1dash=$(printf '.so[1-] %s\n' "$tmpinc" | "$soelim" -r)
check_all_lines "[1-]" "$out_1dash"

cleanup
test -z "$fail"

# vim:set autoindent expandtab shiftwidth=2 tabstop=2 textwidth=72:
