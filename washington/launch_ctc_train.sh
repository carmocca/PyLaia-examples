#!/bin/bash
set -e;

if [ $# -lt 2 ]; then
  cat <<EOF > /dev/stderr
Usage: ${0##*/} PARTITION_ID OUTPUT_DIR [TRAIN_OPTIONS]

Example: ${0##*/} cv1 train/dortmund/cv1 --gpu=2
EOF
  exit 1;
fi;

export PYTHONPATH=$HOME/src/PyLaia:$PYTHONPATH;

TRAIN_TXT="data/lang/dortmund/char/${1}_tr.txt";
VALID_TXT="data/lang/dortmund/char/${1}_te.txt";
OUTPUT_DIR="$2";
shift 2;


for f in "$TRAIN_TXT" "$VALID_TXT"; do
  [ -s "$f" ] || { echo "File \"$f\" wasn't found!" >&2 && exit 1; }
done;

mkdir -p "$OUTPUT_DIR";

if [ -s "$OUTPUT_DIR/model.ckpt" ]; then
    ckpt="$OUTPUT_DIR/model.ckpt";
    msg="Checkpoint \"$ckpt\" already exists. a: abort, l: load, o: overwrite";
    read -p "$msg" -n 1 -r; echo;
    if [[ $REPLY =~ ^[Oo]$ ]]; then
       load_checkpoint=;
    elif [[ $REPLY =~ ^[Ll]$ ]]; then
        load_checkpoint="$ckpt";
    else
        echo "Aborted training..." >&2;
        exit 0;
    fi;
fi;


./steps/train_ctc.py \
       --max_epochs=220 \
       --logging_also_to_stderr=INFO \
       --logging_file="$OUTPUT_DIR/train.log" \
       --load_checkpoint="$load_checkpoint" \
       --save_checkpoint="$OUTPUT_DIR/model.ckpt" \
       $@ \
       train/dortmund/syms.txt \
       data/imgs/dortmund \
       "$TRAIN_TXT" \
       "$VALID_TXT";
