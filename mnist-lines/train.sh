#!/bin/bash
set -e;

exper_path="train";
fixed_height=28;
seed=0x12345;
extra_args=();
if [ -n "$fixed_height" ]; then
  extra_args+=(--fixed_input_height "$fixed_height");
fi;

mkdir -p "$exper_path";

pylaia-htr-create-model \
  1 "data/lang/syms.txt" \
  --adaptive_pooling "avgpool-8" \
  --cnn_num_features 12 24 48 \
  --cnn_kernel_size 3 3 3 \
  --cnn_stride 1 1 1 \
  --cnn_dilation 1 1 1 \
  --cnn_activations LeakyReLU LeakyReLU LeakyReLU \
  --cnn_poolsize 2 2 0 \
  --cnn_dropout 0 0 0 \
  --cnn_batchnorm t t t \
  --rnn_units 128 \
  --rnn_layers 1 \
  --use_masked_conv true \
  --logging_file "$exper_path/model_log" \
  --logging_also_to_stderr INFO \
  --logging_level INFO \
  --logging_overwrite false \
  --train_path "$exper_path" \
  --seed "$seed" \
  "${extra_args[@]}";

pylaia-htr-train-ctc \
  "data/lang/syms.txt" \
  data/imgs/tr data/imgs/te \
  "data/lang/tr.gt" \
  "data/lang/te.gt" \
  --delimiters "<space>" \
  --logging_also_to_stderr INFO \
  --logging_level INFO \
  --logging_file "$exper_path/train_log" \
  --logging_overwrite true \
  --train_path "$exper_path" \
  --batch_size 10 \
  --learning_rate 0.001 \
  --optimizer "Adam" \
  --use_distortions false \
  --gpus 1 \
  --seed "$seed";
