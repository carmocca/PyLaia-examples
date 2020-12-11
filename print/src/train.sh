#!/bin/bash
set -e;
export LC_NUMERIC=C;

# Move to the top directory of the experiment.
cd "$(dirname "${BASH_SOURCE[0]}")/..";

# Create model
pylaia-htr-create-model --config=model_config.yaml;

# Train
pylaia-htr-train-ctc --config=train_config.yaml;

# Train with validation for 10 epochs
pylaia-htr-train-ctc --config=train_config.yaml \
  data/lang/syms.txt \
  [data/imgs/lines_h128/va] \
  data/lang/char/va.gt \
  --train.augment_training=false \
  --train.resume=10 \
  --logging.overwrite=false;
