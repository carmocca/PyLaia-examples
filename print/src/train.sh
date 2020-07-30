#!/bin/bash
set -e;
export LC_NUMERIC=C;

# Move to the top directory of the experiment.
cd "$(dirname "${BASH_SOURCE[0]}")/..";

source ../utils/functions_check.inc.sh || exit 1;

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
help_message="
Usage: ${0##*/} [options]

Options:
  --adaptive_pooling         : (type = string, default = $adaptive_pooling)
                               Type of adaptive pooling to use, format:
                               {none,maxpool,avgpool}-[0-9]+
  --cnn_batchnorm            : (type = boolean list, default = \"$cnn_batchnorm\")
                               Batch normalization before the activation in each conv
                               layer.
  --cnn_dropout              : (type = double list, default = \"$cnn_dropout\")
                               Dropout probability at the input of each conv layer.
  --cnn_poolsize             : (type = integer list, default = \"$cnn_poolsize\")
                               Pooling size after each conv layer. It can be a list
                               of numbers if all the dimensions are equal or a list
                               of strings formatted as tuples, e.g. (h1, w1) (h2, w2)
  --cnn_kernel_size          : (type = integer list, default = \"$cnn_kernel_size\")
                               Kernel size of each conv layer. It can be a list
                               of numbers if all the dimensions are equal or a list
                               of strings formatted as tuples, e.g. (h1, w1) (h2, w2)
  --cnn_stride               : (type = integer list, default = \"$cnn_stride\")
                               Stride of each conv layer. It can be a list
                               of numbers if all the dimensions are equal or a list
                               of strings formatted as tuples, e.g. (h1, w1) (h2, w2)
  --cnn_dilation             : (type = integer list, default = \"$cnn_dilation\")
                               Dilation of each conv layer. It can be a list
                               of numbers if all the dimensions are equal or a list
                               of strings formatted as tuples, e.g. (h1, w1) (h2, w2)
  --cnn_num_featuress        : (type = integer list, default = \"$cnn_num_features\")
                               Number of feature maps in each conv layer.
  --cnn_activations          : (type = string list, default = \"$cnn_activations\")
                               Type of the activation function in each conv layer,
                               valid types are \"ReLU\", \"Tanh\", \"LeakyReLU\".
  --rnn_layers               : (type = integer, default = $rnn_layers)
                               Number of recurrent layers.
  --rnn_units                : (type = integer, default = $rnn_units)
                               Number of units in the recurrent layers.
  --fixed_height             : (type = integer, default = $fixed_height)
                               Use a fixed height model.
  --batch_size               : (type = integer, default = $batch_size)
                               Batch size for training.
  --learning_rate            : (type = float, default = $learning_rate)
                               Learning rate from RMSProp.
  --gpu                      : (type = integer, default = $gpu)
                               Select which GPU to use, index starts from 1.
                               Set to 0 for CPU.
  --early_stop_epochs        : (type = integer, default = $early_stop_epochs)
                               If n>0, stop training after this number of epochs
                               without a significant improvement in the validation CER.
                               If n=0, early stopping will not be used.
  --save_checkpoint_interval : (type=integer, default=$save_checkpoint_interval)
                               Make checkpoints of the training process every N epochs.
  --num_rolling_checkpoints  : (type=integer, default=$num_rolling_checkpoints)
                               Keep this number of checkpoints during training.
  --show_progress_bar        : (type=boolean, default=$show_progress_bar)
                               Whether or not to show a progress bar for each epoch.
  --use_distortions          : (type=boolean, default=$use_distortions)
                               Whether or not to use distortions to augment the training data.
  --img_directories          : (type = string list, default = \"$img_directories\")
                               Image directories to use. If more than one, separate them with
                               spaces.
  --checkpoint               : (type = str, default = $checkpoint)
                               Suffix of the checkpoint to use, can be a glob pattern.
";
source "../utils/parse_options.inc.sh" || exit 1;
[ $# -ne 0 ] && echo "$help_message" >&2 && exit 1;

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
