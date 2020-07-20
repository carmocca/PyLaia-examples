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
declare -a ids=(
  "ONB_ibn_19110701_034.r_4_1.tl_3" # 4x3px
  "ONB_krz_19110701_001.region_1547189437258_60.line_1547189690857_202" # 53x2653
  "ONB_nfp_18950706_012.r_15_1.line_1548399898797_287" # 33x51
  "ONB_nfp_19330701_015.TextRegion_1550032000014_3177.line_1550032000280_3185" # 28x28
  "ONB_nfp_19330701_015.TextRegion_1550032000014_3177.line_1550032000295_3187" # 28x28
)

for id in "${ids[@]}"; do
  rm -fv "data/imgs/lines/tr/${id}.*";
  sed -i "/^${id}/d" data/lang/word/tr.gt;
  if grep -q "${id}" data/lang/word/tr.gt; then echo "${id} was not correctly removed"; fi
done
