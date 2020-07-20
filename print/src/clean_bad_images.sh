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

# Remove problematic samples:

# 4x3px "Seite 34. Nr. 148."
rm -f data/imgs/lines/tr/ONB_ibn_19110701_034.r_4_1.tl_3.png;
sed -i '/^ONB_ibn_19110701_034\.r_4_1\.tl_3/d' data/lang/word/tr.gt;

# 54x2653px "Beraubte Opfer einer Automobil = Katastrophe ."
rm -f data/imgs/lines/tr/ONB_krz_19110701_001.region_1547189437258_60.line_1547189690857_202.png
sed -i '/^ONB_krz_19110701_001\.region_1547189437258_60\.line_1547189690857_202/d' data/lang/word/tr.gt;

# 33x51px "—"
rm -f data/imgs/lines/tr/ONB_nfp_18950706_012.r_15_1.line_1548399898797_287.png
sed -i '/^ONB_nfp_18950706_012\.r_15_1\.line_1548399898797_287/d' data/lang/word/tr.gt;

# 28x28px "-"
rm -f data/imgs/lines/tr/ONB_nfp_19330701_015.TextRegion_1550032000014_3177.line_1550032000280_3185.png;
sed -i '/^ONB_nfp_19330701_015\.TextRegion_1550032000014_3177\.line_1550032000280_3185/d' data/lang/word/tr.gt;
