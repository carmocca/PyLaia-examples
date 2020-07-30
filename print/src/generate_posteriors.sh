#!/usr/bin/env bash
set -e;

syms_ctc="data/lang/syms.txt";
gpu=1;
batch_size=8;
checkpoint="experiment.ckpt.lowest-valid-cer*";
imgs_path="$1";
exper_path="$2";
output_path="$3";

mkdir -p "${output_path}/post";

if [ $gpu -gt 0 ]; then
  export CUDA_VISIBLE_DEVICES=$((gpu-1));
  gpu=1;
fi;

# Generate frame posteriors for text lines
for set in te va; do
  pylaia-htr-netout \
    --gpu "$gpu" \
    --batch_size "$batch_size" \
    --checkpoint "$checkpoint" \
    --logging_also_to_stderr info \
    --logging_level info \
    --train_path "$exper_path" \
    --output_transform log_softmax \
    --output_matrix "${output_path}/conf_mat.ark" \
    --show_progress_bar true \
    "${imgs_path}/${set}" \
    <(cut -d" " -f1 "data/lang/char/${set}.gt");
done;

for set in te va; do
  # note: post stands for posteriors
  copy-matrix
    "ark:${output_path}/conf_mat.ark" \
    "ark,scp:${output_path}/post/${set}.ark,${output_path}/post/${set}.scp";
done
