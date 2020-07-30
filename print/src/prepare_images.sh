#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
echo "Please, run this script from the experiment top directory!" >&2 && \
exit 1;

export LC_NUMERIC=C;

height=128;
help_message="
Usage: ${0##*/} [options]

Options:
  --height : (type = int, default = $height)
";
source "$PWD/../utils/parse_options.inc.sh" || exit 1;

cfg="$(mktemp)";
cat <<EOF > "$cfg"
TextFeatExtractor: {
  verbose = false;
  // Whether to do automatic desloping of the text
  deslope = false;
  // Whether to do automatic deslanting of the text
  deslant = false;
  // Type of feature to extract, either "dotm" or "raw"
  type = "raw";
  // Output features format, either "htk", "ascii" or "img"
  format = "img";
  // Whether to do contrast stretching
  stretch = false;
  // Window size in pixels for local enhancement
  enh_win = 30;
  // Sauvola enhancement parameter
  enh_prm = 0.1;
  // 3 independent enhancements, each in a color channel
  //enh_prm = [ 0.05, 0.2, 0.5 ];
  // Normalize image heights
  normheight = 0;
  normxheight = 0;
  // Global line vertical moment normalization
  momentnorm = true;
  // Whether to compute the features parallelograms
  fpgram = true;
  // Whether to compute the features surrounding polygon
  fcontour = true;
  fcontour_dilate = 0;
  // Padding in pixels to add to the left and right
  padding = 10;
}
EOF

# If image height < fix_height, pad with white.
# If image height > fix_height, scale.
function fix_image_height () {
  [ $# -ne 3 ] && \
  echo "Usage: fix_image_height <fix_height> <input_img> <output_img>" >&2 && \
  return 1;

  h=$(identify -format '%h' "$2") || return 1;
  if [ "$h" -lt "$1" ]; then
    convert -gravity center -extent "x$1" +repage -strip "$2" "$3" || return 1;
  else
    convert -resize "x$1" +repage -strip "$2" "$3" || return 1;
  fi;
  return 0;
}

# Clean training text line images with textFeats
mkdir -p data/imgs/lines/{tr,va,te};
for set in tr va te; do
  find data/imgs/lines_og/${set} -name "*.png" |
  xargs $HOME/software/textFeats/build/textFeats \
    --cfg="$cfg" \
    --outdir=data/imgs/lines/${set} \
    --overwrite=true \
    --threads=$(nproc);
done

# Resize training text line images to a fixed height
mkdir -p data/imgs/lines_h${height}/{tr,va,te};
for set in tr va te; do
  n=0;
  for f in $(find data/imgs/lines/${set} -name "*.png"); do
    ( fix_image_height "${height}" data/imgs/lines{,_h128}/${set}/$(basename ${f}) || exit 1; ) &
    ((++n));
    [ "$n" -eq "$(nproc)" ] && { wait; n=1; }
  done;
  wait;
done;
