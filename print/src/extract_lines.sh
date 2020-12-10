#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
echo "Please, run this script from the experiment top directory!" >&2 && \
exit 1;

set_dir=(
  "Train_Set_'ONB_Newseye_GT_M1+'"
  "Validation_Set_'ONB_Newseye_GT_M1+'"
  "GT_NRW_Samples_final"
);
set_name=(tr va te);

mkdir -p data/imgs/lines_og;

for i in $(seq ${#set_dir[@]}); do
  data_dir=data/original/"${set_dir[i-1]}";
  img_dir=data/imgs/lines_og/"${set_name[i-1]}";
  mkdir -p "$img_dir";

  # Find all images
  set +e; # pageLineExtractor might segfault
  find "$data_dir" -type f \( -iname \*.jpg -o -iname \*.tif \) |
  while read img; do
    echo "Processing ${img}...";
    # Fix contours
    page_format_tool \
      -i "$img" \
      -l "$data_dir"/page/"$(basename "${img%.*}")".xml -m FIX;
    # Extract lines
    page_format_tool \
      -i "$img" \
      -l "$data_dir"/page/"$(basename "${img%.*}")".xml -m FILE;
      mv -f "$data_dir"/page/*.png "$img_dir";
  done
  set -e;

  # Join .txts into one file
  mkdir -p data/lang/word;
  f=data/lang/word/"${set_name[i-1]}".gt
  rm -f "$f";
  find "$data_dir"/page -type f \( -iname \*.txt \) |
  while read txt; do
    echo "$(basename "${txt%.*}") $(cat "$txt")" >> "$f";
    rm "$txt";
  done
done
