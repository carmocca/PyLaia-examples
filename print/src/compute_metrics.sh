#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
    echo "Please, run this script from the experiment top directory!" >&2 && \
    exit 1;

rm -f decode/decode.out;

for i in char word; do
  for j in va te; do
    echo "# ${i}/${j}:" | tee -a decode/decode.out;

    # Compute CER/WER using Kaldi's compute-wer-bootci
    "$HOME"/software/kaldi/src/bin/compute-wer --print-args=false --mode=strict \
      "ark:data/lang/${i}/${j}.gt" \
      "ark:decode/${i}/${j}.hyp" | \
    tee -a decode/decode.out;
    echo "" | tee -a decode/decode.out;

    # Compute CER/WER using Rostock's TranskribusErrorRate.
    # The tool does not match by id. Needs same order in gt and hyp
    # Note: CER is not calculated correctly (github.com/Transkribus/TranskribusErrorRate/issues/4)
    java -cp "$HOME"/software/TranskribusErrorRate/target/TranskribusErrorRate-2.2.7-jar-with-dependencies.jar \
      eu.transkribus.errorrate.HtrErrorTxt \
      <(cut -d" " -f2- data/lang/${i}/${j}.gt) \
      <(cut -d" " -f2- decode/${i}/${j}.hyp) \
      --wer | \
    tee -a decode/decode.out;
    echo "" | tee -a decode/decode.out;
  done;
done;
