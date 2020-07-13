#!/bin/bash
set -e;

# Directory where the run.sh script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
cd "$SDIR";

mkdir -p ./data;
ln -snf ~/data/print/original ./data/original

./src/extract_lines.sh
./src/prepare_texts.sh;
# TODO: ./src/prepare_images.sh;
./src/train.sh;
./src/decode_net.sh;
./src/compute_metrics.sh;
