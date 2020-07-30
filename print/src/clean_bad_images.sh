#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
echo "Please, run this script from the experiment top directory!" >&2 && \
exit 1;

# Remove images (and their variants) whose
# width or height is less than 8px
for dir in lines_og lines lines_h128; do
  for set in tr va te; do
    find data/imgs/${dir}/${set} | \
      xargs -I{} identify -format '%f %h %w\n' {} | \
      gawk '$2 < 8 || $3 < 8 { print $1 }' > bad_${set}.txt;
    cat bad_${set}.txt | while read img; do
      id="${img%.*}";
      rm -fv data/imgs/lines{_og,,_h128}/${set}/${id}\.*;
      sed -i "/^${id}/d" data/lang/word/${set}.gt;
      if grep -q "${id}" data/lang/word/${set}.gt; then echo "${id} was not correctly removed"; fi
    done
  done
done
rm -f bad_{tr,va,te}.txt;

for set in tr va te; do
  wo="data/lang/word/${set}.gt";
  # Delete empty images and their transcriptions
  gawk 'NF <= 1 { print $1 }' "${wo}" | xargs -I{} find data/imgs/lines{_og,,_h128}/${set} -name '{}.*' -delete;
  gawk -i inplace 'NF > 1' "${wo}";
done
