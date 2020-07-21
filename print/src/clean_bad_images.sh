#!/bin/bash
set -e;

check=false;
if [ "$check" = true ]; then
  for set in tr va te; do
    find data/imgs/lines/${set} | \
      xargs -I{} identify -format '%f %h %w\n' {} | \
      gawk '$2 < 8 || $3 < 8 { print $1 ": " $2 "x" $3 }' > bad_${set}.txt;
  done
fi

# Remove problematic samples:
declare -a ids=(
  "ONB_ibn_19110701_034.r_4_1.tl_3"
  "ONB_krz_19110701_001.region_1547189437258_60.line_1547189690857_202"
  "ONB_nfp_18950706_012.r_15_1.line_1548399898797_287"
  "ONB_aze_18950706_7.region_1545271830529_69.line_1545271901520_79"
  "ONB_nfp_18950706_012.region_1548397997553_37.line_1548401107832_430"
  "ONB_nfp_19330701_014.TextRegion_1549865578548_498.line_1549865578767_522"
  "ONB_nfp_19330701_015.TextRegion_1550032000014_3177.line_1550032000264_3179"
  "ONB_nfp_19330701_015.TextRegion_1550032000014_3177.line_1550032000264_3181"
  "ONB_nfp_19330701_015.TextRegion_1550032000014_3177.line_1550032000280_3185"
  "ONB_nfp_19330701_015.TextRegion_1550032000014_3177.line_1550032000295_3187"
  "ONB_nfp_19330701_015.TextRegion_1550032000014_3177.line_1550032000327_3197"
  "ONB_aze_19330701_page10_image8.TextRegion_1548143804101_25.line_1548143804318_27"
  "ONB_aze_19330701_page10_image8.TextRegion_1548144027083_95.line_1548144027301_103"
)
for id in "${ids[@]}"; do
  rm -fv "data/imgs/lines/tr/${id}.*";
  sed -i "/^${id}/d" data/lang/word/tr.gt;
  if grep -q "${id}" data/lang/word/tr.gt; then echo "${id} was not correctly removed"; fi
done

declare -a ids=(
  "Sample_06.r_9_1.r_9_1l10"
  "Sample_10.r_21_1.r_21_1l27"
  "Sample_09.r3.r3l87"
)
for id in "${ids[@]}"; do
  rm -fv "data/imgs/lines/te/${id}.*";
  sed -i "/^${id}/d" data/lang/word/te.gt;
  if grep -q "${id}" data/lang/word/te.gt; then echo "${id} was not correctly removed"; fi
done
