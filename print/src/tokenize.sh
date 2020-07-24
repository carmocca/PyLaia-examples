#!/bin/bash
set -e;

f=$1;
tmpid=$(mktemp); tmpgt=$(mktemp);
# Get id
awk '{ print $1 }' "${f}" > "${tmpid}";
# Get text
cut -d" " -f2- "${f}" | sed 's/\([.,:;+-=¿?()¡!/\„“—#%¬’]\)/ \1 /g' > "${tmpgt}";
# Join together
paste -d" " "${tmpid}" "${tmpgt}" > "${f}";
rm -f "${tmpid}" "${tmpgt}";
# Strip leading, trailing, and contiguous whitespace
sed -i -r 's/^ +//g; s/ +/ /g; s/ $//g' "${f}";
