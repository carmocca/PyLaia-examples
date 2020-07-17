#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
echo "Please, run this script from the experiment top directory!" >&2 && \
exit 1;

source ../utils/functions_parallel.inc.sh || exit 1;

num_parallel="$(get_num_cores)";
resize_height=128;
help_message="
Usage: ${0##*/} [options]

Options:
  --nun_parallel  : (type = integer, default = $num_parallel)
                    Number of parallel processes to process the images.
  --resize_height : (type = integer, default = $resize_height)
                    Resize the line and sentence images to this given height.
";
source ../utils/parse_options.inc.sh || exit 1;


function process_image () {
  local bn="$(basename "$1" .png)";
  # Process image
  "$HOME"/software/imgtxtenh/build/imgtxtenh -d 118.110 "$1" png:- |
  convert png:- -deskew 40% \
    -bordercolor white -border 5 -trim \
    -bordercolor white -border 20x0 +repage \
    -strip "${img_dir}/$bn.jpg" ||
  { echo "ERROR: Processing image $1" >&2 && return 1; }
  # Resize image to a fixed height, keep aspect ratio.
  convert "${img_dir}/$bn.jpg" \
    -resize "x${resize_height}" +repage \
    -strip "${img_resize_dir}/$bn.jpg" ||
  { echo "ERROR: Processing image $1" >&2 && return 1; }
  return 0;
}

# Copy original images
cp -r "data/imgs/lines" "data/imgs/lines_og";

tmpd="$(mktemp -d)";
bkg_pids=();
for s in tr va te; do
  img_resize_dir="data/imgs/lines_h${resize_height}/${s}";
  img_dir="data/imgs/lines/${s}";
  mkdir -p "${img_resize_dir}";
  # Enhance images with Mauricio's tool, deskew the
  # line, crop white borders and resize to the given height.
  for f in $(find "${img_dir}" -name "*.png"); do
    process_image "$f" &> "$tmpd/${#bkg_pids[@]}" & bkg_pids+=("$!");
    [ "${#bkg_pids[@]}" -lt "$num_parallel" ] ||
    { wait_jobs --log_dir "$tmpd" "${bkg_pids[@]}" && bkg_pids=(); } || exit 1;
  done;
done;
wait_jobs --log_dir "$tmpd"  "${bkg_pids[@]}" || exit 1;
rm -rf "$tmpd";

for s in tr va te; do
  img_dir="data/imgs/lines/${s}";
  find "$img_dir" -type f \( -iname \*.png \) -delete;
done;
