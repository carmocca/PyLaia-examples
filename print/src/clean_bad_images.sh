#!/bin/bash
set -e;

check=false;
if [ "$check" = true ]; then
  for set in tr va te; do
    find data/imgs/lines/${set} | \
      xargs -I{} identify -format '%f %[fx:w*h]\n' {} | \
      gawk '$2 < 500 { print $1 ": " $2 }' | \
      sort -k2 -n > bad_${set}.txt
  done
fi

# Remove:

# 4x3px image "Seite 34. Nr. 148."
rm -f data/imgs/lines/tr/ONB_ibn_19110701_034.r_4_1.tl_3.png;
sed -i '/^ONB_ibn_19110701_034\.r_4_1\.tl_3/d' data/lang/word/tr.gt;
