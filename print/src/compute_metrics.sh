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
    $HOME/software/kaldi/src/bin/compute-wer-bootci --print-args=false --mode=present \
      "ark:data/lang/${i}/${j}.txt" \
      "ark:decode/${i}/${j}.txt" | \
    awk -F\  '{ print "Kaldi WER:", $3, "[" $8, $9 "] (95% conf)"  }' | tee -a decode/decode.out;

    # Compute CER/WER using Rostock's TranskribusErrorRate
    java -cp $HOME/software/TranskribusErrorRate/target/TranskribusErrorRate-2.2.7-jar-with-dependencies.jar \
      eu.transkribus.errorrate.HtrErrorTxt \
      "data/lang/${i}/${j}.txt" \
      "decode/${i}/${j}.txt" | grep ERR | gawk -F= '{ print "Transkribus CER: " $2 }' | tee -a decode/decode.out;
    java -cp $HOME/software/TranskribusErrorRate/target/TranskribusErrorRate-2.2.7-jar-with-dependencies.jar \
      eu.transkribus.errorrate.HtrErrorTxt \
      "data/lang/${i}/${j}.txt" \
      "decode/${i}/${j}.txt" --wer | grep ERR | gawk -F= '{ print "Transkribus WER: " $2 "\n" }' | tee -a decode/decode.out;
  done;
done;
