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
# Test [N] single-line range specifier.

soelim="${SOELIM:-$HOME/Apps/bin/soelim}"

fail=

wail () {
  echo "...FAILED: $*" >&2
  fail=yes
}

tmpinc="soelim-inc-single-$$.txt"

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

# .so[1] should include only line 1
out1=$(printf '.so[1] %s\n' "$tmpinc" | "$soelim" -r)
echo "$out1" | grep -Fq "This is line 1." \
  || wail "[1]: line 1 not present"
echo "$out1" | grep -Fq "This is line 2." \
  && wail "[1]: line 2 should not be present"

# .so[2] should include only line 2
out2=$(printf '.so[2] %s\n' "$tmpinc" | "$soelim" -r)
echo "$out2" | grep -Fq "This is line 2." \
  || wail "[2]: line 2 not present"
echo "$out2" | grep -Fq "This is line 1." \
  && wail "[2]: line 1 should not be present"
echo "$out2" | grep -Fq "This is line 3." \
  && wail "[2]: line 3 should not be present"

# .so[4] should include only line 4
out4=$(printf '.so[4] %s\n' "$tmpinc" | "$soelim" -r)
echo "$out4" | grep -Fq "This is line 4." \
  || wail "[4]: line 4 not present"
echo "$out4" | grep -Fq "This is line 3." \
  && wail "[4]: line 3 should not be present"
echo "$out4" | grep -Fq "This is line 5." \
  && wail "[4]: line 5 should not be present"

cleanup
test -z "$fail"

# vim:set autoindent expandtab shiftwidth=2 tabstop=2 textwidth=72:
