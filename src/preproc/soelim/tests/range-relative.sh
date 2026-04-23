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
# Test relative range [S+R] syntax.
# [S+R] means start at line S, include R additional lines (total S to S+R).
# [3+]  = [3-4]  (R defaults to 1 when omitted)
# [3+2] = [3-5]
# [+2]  = [1-3]  (S defaults to 1 when omitted)
# [+]   = [1-2]  (S=1, R=1)

soelim="${SOELIM:-$HOME/Apps/bin/soelim}"

fail=

wail () {
  echo "...FAILED: $*" >&2
  fail=yes
}

tmpinc="soelim-inc-relative-$$.txt"

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

# .so[3+] = [3-4]: lines 3 and 4
out_3plus=$(printf '.so[3+] %s\n' "$tmpinc" | "$soelim" -r)
echo "$out_3plus" | grep -Fq "This is line 3." || wail "[3+]: line 3 missing"
echo "$out_3plus" | grep -Fq "This is line 4." || wail "[3+]: line 4 missing"
echo "$out_3plus" | grep -Fq "This is line 2." \
  && wail "[3+]: line 2 should not be present"
echo "$out_3plus" | grep -Fq "This is line 5." \
  && wail "[3+]: line 5 should not be present"

# .so[3+2] = [3-5]: lines 3, 4, 5
out_3p2=$(printf '.so[3+2] %s\n' "$tmpinc" | "$soelim" -r)
echo "$out_3p2" | grep -Fq "This is line 3." || wail "[3+2]: line 3 missing"
echo "$out_3p2" | grep -Fq "This is line 4." || wail "[3+2]: line 4 missing"
echo "$out_3p2" | grep -Fq "This is line 5." || wail "[3+2]: line 5 missing"
echo "$out_3p2" | grep -Fq "This is line 2." \
  && wail "[3+2]: line 2 should not be present"

# .so[+2] = [1-3]: lines 1, 2, 3
out_p2=$(printf '.so[+2] %s\n' "$tmpinc" | "$soelim" -r)
echo "$out_p2" | grep -Fq "This is line 1." || wail "[+2]: line 1 missing"
echo "$out_p2" | grep -Fq "This is line 2." || wail "[+2]: line 2 missing"
echo "$out_p2" | grep -Fq "This is line 3." || wail "[+2]: line 3 missing"
echo "$out_p2" | grep -Fq "This is line 4." \
  && wail "[+2]: line 4 should not be present"

# .so[+] = [1-2]: lines 1 and 2
out_plus=$(printf '.so[+] %s\n' "$tmpinc" | "$soelim" -r)
echo "$out_plus" | grep -Fq "This is line 1." || wail "[+]: line 1 missing"
echo "$out_plus" | grep -Fq "This is line 2." || wail "[+]: line 2 missing"
echo "$out_plus" | grep -Fq "This is line 3." \
  && wail "[+]: line 3 should not be present"

cleanup
test -z "$fail"

# vim:set autoindent expandtab shiftwidth=2 tabstop=2 textwidth=72:
