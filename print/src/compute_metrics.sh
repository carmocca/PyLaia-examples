#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
    echo "Please, run this script from the experiment top directory!" >&2 && \
    exit 1;

# Compute CER/WER using compute-wer and TranskribusErrorRate.
# Note: the second does not match by id, has to be sorted.

for x in va te; do
  echo "# char/${x}:";
  "$HOME"/software/kaldi/src/bin/compute-wer --print-args=false --mode=strict \
    "ark:data/lang/char/${x}.gt" "ark:decode/char/${x}.hyp";
  java -cp "$HOME"/software/TranskribusErrorRate/target/TranskribusErrorRate-2.2.7-jar-with-dependencies.jar \
    eu.transkribus.errorrate.HtrErrorTxt \
    <(cut -d" " -f2- "data/lang/word/${x}.gt") \
    <(cut -d" " -f2- "decode/word/${x}.hyp");
  echo "";
done

for x in va va_tok te te_tok; do
  echo -e "\n# word/${x}:";
  "$HOME"/software/kaldi/src/bin/compute-wer --print-args=false --mode=strict \
    "ark:data/lang/word/${x}.gt" "ark:decode/word/${x}.hyp";

  java -cp "$HOME"/software/TranskribusErrorRate/target/TranskribusErrorRate-2.2.7-jar-with-dependencies.jar \
    eu.transkribus.errorrate.HtrErrorTxt \
    <(cut -d" " -f2- "data/lang/word/${x}.gt") \
    <(cut -d" " -f2- "decode/word/${x}.hyp") --wer;
done
