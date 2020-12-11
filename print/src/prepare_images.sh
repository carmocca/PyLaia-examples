#!/bin/bash
set -e;
export LC_NUMERIC=C;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
echo "Please, run this script from the experiment top directory!" >&2 && \
exit 1;

# No height normalization
mkdir -p data/imgs/lines/{tr,va,te};
for set in tr va te; do
  find data/imgs/lines_og/${set} -name "*.png" -print0 |
  xargs textFeats \
    --cfg=src/textFeats.cfg \
    --outdir=data/imgs/lines/${set} \
    --overwrite=true \
    --threads="$(nproc)";
done

# 128px height
mkdir -p data/imgs/lines_h128/{tr,va,te};
for set in tr va te; do
  find data/imgs/lines_og/${set} -name "*.png" -print0 |
  xargs textFeats \
    --cfg=src/textFeats_h128.cfg \
    --outdir=data/imgs/lines_h128/${set} \
    --overwrite=true \
    --threads="$(nproc)";
done
