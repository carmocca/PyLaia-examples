#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
    echo "Please, run this script from the experiment top directory!" >&2 && \
    exit 1;

# Compute CER/WER using Kaldi's compute-wer-bootci
echo "# char/va_og:";
"$HOME"/software/kaldi/src/bin/compute-wer --print-args=false --mode=strict \
  "ark:data/lang/char/va_og.gt" "ark:decode/char/va.hyp";
echo -e "\n# char/te_og:";
"$HOME"/software/kaldi/src/bin/compute-wer --print-args=false --mode=strict \
  "ark:data/lang/char/te_og.gt" "ark:decode/char/te.hyp";
# Rostock's tool is not used to calculate CER due to a problem
# with its tokenizer (github.com/Transkribus/TranskribusErrorRate/issues/4)

for x in va_og va te_og te; do
  echo -e "\n# word/${x}:";
  "$HOME"/software/kaldi/src/bin/compute-wer --print-args=false --mode=strict \
    "ark:data/lang/word/${x}.gt" "ark:decode/word/${x}.hyp";

  # Compute CER/WER using Rostock's TranskribusErrorRate.
  # The tool does not match by id. Needs same order in gt and hyp
  java -cp "$HOME"/software/TranskribusErrorRate/target/TranskribusErrorRate-2.2.7-jar-with-dependencies.jar \
    eu.transkribus.errorrate.HtrErrorTxt \
    <(cut -d" " -f2- "data/lang/word/${x}.gt") \
    <(cut -d" " -f2- "decode/word/${x}.hyp") --wer;
done
