#!/bin/bash
set -e;
export LC_NUMERIC=C;

# Move to the top directory of the experiment.
cd "$(dirname "${BASH_SOURCE[0]}")/..";

source ../utils/functions_check.inc.sh || exit 1;

check_all_files \
  data/lang/puigcerver/lines/char/tr.txt \
  data/lang/puigcerver/lines/char/va.txt;

[ -s syms.txt ] ||
  cut -d\  -f2- data/lang/puigcerver/lines/char/{tr,va}.txt | \
  tr \  \\n | \
  sort -u | \
  awk 'BEGIN{ print "<ctc>", 0; }{ print $1, NR; }' > "syms.txt";

pylaia-htr-create-model --config=model_config.yaml
pylaia-htr-train-ctc --config=train_config.yaml
