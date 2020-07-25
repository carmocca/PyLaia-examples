#!/bin/bash
set -e;

for dir in lines_og lines lines_h128; do
  for set in tr va te; do
    find data/imgs/${dir}/${set} | \
      xargs -I{} identify -format '%f %h %w\n' {} | \
      gawk '$2 < 8 || $3 < 8 { print $1 }' > bad_${set}.txt;
    cat bad_${set}.txt | while read img; do
      rm -fv data/imgs/${dir}/${set}/${img};
      id="${img%.*}";
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
