#!/bin/bash
set -e;
export LC_NUMERIC=C;

# Move to the top directory of the experiment.
cd "$(dirname "${BASH_SOURCE[0]}")/..";

# General parameters
exper_path="train";
# Model parameters
cnn_num_features="12 24 48 48";
cnn_kernel_size="3 3 3 3";
cnn_stride="1 1 1 1";
cnn_dilation="1 1 1 1";
cnn_activations="LeakyReLU LeakyReLU LeakyReLU LeakyReLU";
cnn_poolsize="2 2 0 2";
cnn_dropout="0 0 0 0";
cnn_batchnorm="t t t t";
rnn_units=256;
rnn_layers=3;
adaptive_pooling="avgpool-16";
fixed_height=128;
use_masked_conv=true;
# Trainer parameters
batch_size=4;
checkpoint="ckpt.lowest-valid-cer*";
early_stop_epochs=50;
max_epochs=250;
gpu=1;
img_directories="data/imgs/lines_h128/tr data/imgs/lines_h128/va";
learning_rate=0.0003;
num_rolling_checkpoints=5;
save_checkpoint_interval=10;
seed=0x12345;
show_progress_bar=true;
use_distortions=true;

if [ $gpu -gt 0 ]; then
  export CUDA_VISIBLE_DEVICES=$((gpu-1));
  gpu=1;
fi;

extra_args=();
if [ -n "$fixed_height" ]; then
  extra_args+=(--fixed_input_height "$fixed_height");
fi;

mkdir -p "$exper_path";

# Create model
pylaia-htr-create-model \
  1 "data/lang/syms.txt" \
  --adaptive_pooling "$adaptive_pooling" \
  --cnn_num_features $cnn_num_features \
  --cnn_kernel_size $cnn_kernel_size \
  --cnn_stride $cnn_stride \
  --cnn_dilation $cnn_dilation \
  --cnn_activations $cnn_activations \
  --cnn_poolsize $cnn_poolsize \
  --cnn_dropout $cnn_dropout \
  --cnn_batchnorm $cnn_batchnorm \
  --rnn_units "$rnn_units" \
  --rnn_layers "$rnn_layers" \
  --use_masked_conv "$use_masked_conv" \
  --logging_file "$exper_path/log" \
  --logging_also_to_stderr INFO \
  --train_path "$exper_path" \
  --seed "$seed" \
  "${extra_args[@]}";

# Train
pylaia-htr-train-ctc \
  "data/lang/syms.txt" \
  $img_directories \
  data/lang/char/tr.gt \
  data/lang/char/va.gt \
  --batch_size "$batch_size" \
  --checkpoint "$checkpoint" \
  --delimiters "<space>" \
  --gpu "$gpu" \
  --learning_rate "$learning_rate" \
  --logging_also_to_stderr INFO \
  --logging_file "$exper_path/log" \
  --max_nondecreasing_epochs "$early_stop_epochs" \
  --max_epochs "$max_epochs" \
  --num_rolling_checkpoints "$num_rolling_checkpoints" \
  --save_checkpoint_interval "$save_checkpoint_interval" \
  --show_progress_bar "$show_progress_bar" \
  --train_path "$exper_path" \
  --use_distortions "$use_distortions" \
  --seed "$seed";
