#!/bin/bash
set -e;
export LC_NUMERIC=C;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
    echo "Please, run this script from the experiment top directory!" >&2 && \
    exit 1;

batch_size=8;
gpu=0;
checkpoint="experiment.ckpt.lowest-valid-cer*";
fixed_height=false;
exper_path="train";
help_message="
Usage: ${0##*/} [options]

Options:
  --batch_size   : (type = integer, default = $batch_size)
                   Batch size for decoding.
  --gpu          : (type = integer, default = $gpu)
                   Select which GPU to use, index starts from 1.
                   Set to 0 for CPU.
  --checkpoint   : (type = str, default = $checkpoint)
                   Suffix of the checkpoint to use, can be a glob pattern.
  --fixed_height : (type = boolean, default = $fixed_height)
                   Use a fixed height model.
";
source "../utils/parse_options.inc.sh" || exit 1;
[ $# -ne 0 ] && echo "$help_message" >&2 && exit 1;

if [ $gpu -gt 0 ]; then
  export CUDA_VISIBLE_DEVICES=$((gpu-1));
  gpu=1;
fi;

for f in data/lang/{char,word}/{te,va}.txt data/lang/syms.txt "$exper_path"/model; do
  [ ! -s "$f" ] && echo "ERROR: File \"$f\" does not exist!" >&2 && exit 1;
done;

mkdir -p decode/{char,word};

for p in va te; do
  char="decode/char/${p}.txt";
  word="decode/word/${p}.txt";
  find data/imgs/lines/$p -type f \( -iname \*.png \) > decode/${p}_list.txt;

  # Decode lines
  pylaia-htr-decode-ctc \
    data/lang/syms.txt \
    decode/${p}_list.txt \
    --train_path $exper_path \
    --join_str=" " \
    --gpu $gpu \
    --batch_size $batch_size \
    --checkpoint $checkpoint \
    --use_letters | sort -V > "$char";
  # Note: The decoding step does not return the output
  # In the same order as the input unless batch size 1
  # is used. Sort must be done afterwards

  # Get word-level transcript hypotheses for lines
  gawk '{
    printf("%s ", $1);
    for (i=2;i<=NF;++i) {
      if ($i == "<space>")
        printf(" ");
      else
        printf("%s", $i);
    }
    printf("\n");
  }' "$char" > "$word";
done;
