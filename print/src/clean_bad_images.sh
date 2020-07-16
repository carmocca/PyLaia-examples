#!/bin/bash
set -e;

# Lists of smallest images
for set in tr va te; do
  find data/imgs/lines/${set} | \
    xargs -I{} identify -format '%f %[fx:w*h]\n' {} | \
    gawk '$2 < 500 { print $1 ": " $2 }' | \
    sort -k2 -n > bad_${set}.txt
done

# Remove:

# 4x3px image "Seite 34. Nr. 148."
rm -f data/imgs/lines/tr/ONB_ibn_19110701_034.r_4_1.tl_3.png;
sed -i '/^ONB_ibn_19110701_034\.r_4_1\.tl_3\.png/d' data/lang/char/tr.gt;
