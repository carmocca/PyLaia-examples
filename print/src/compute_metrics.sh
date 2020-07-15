#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
    echo "Please, run this script from the experiment top directory!" >&2 && \
    exit 1;

rm -f decode/decode.out;

for i in char word; do
  for j in te va; do
    echo "# ${i}/${j}:" | tee -a decode/decode.out;

    # Compute CER/WER using Kaldi's compute-wer-bootci
    $HOME/software/kaldi/src/bin/compute-wer-bootci --print-args=false --mode=strict \
      "ark:data/lang/${i}/${j}.gt" \
      "ark:decode/${i}/${j}.hyp" | \
    awk -F\  '{ print "Kaldi WER:", $3, "[" $8, $9 "] (95% conf)"  }' | \
    tee -a decode/decode.out;

    # Compute CER/WER using Rostock's TranskribusErrorRate.
    # The tool does not match by id. remove it:
    awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}' data/lang/${i}/${j}.gt > tmp.gt
    awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}' decode/${i}/${j}.hyp > tmp.hyp

    java -cp $HOME/software/TranskribusErrorRate/target/TranskribusErrorRate-2.2.7-jar-with-dependencies.jar \
      eu.transkribus.errorrate.HtrErrorTxt \
      tmp.gt tmp.hyp | \
    grep ERR | \
    gawk -F= '{ printf "Transkribus CER: %.3f\n", $2 * 100 }' | \
    tee -a decode/decode.out;

    java -cp $HOME/software/TranskribusErrorRate/target/TranskribusErrorRate-2.2.7-jar-with-dependencies.jar \
      eu.transkribus.errorrate.HtrErrorTxt \
      tmp.gt tmp.hyp --wer | \
    grep ERR | \
    gawk -F= '{ printf "Transkribus WER: %.3f\n\n", $2 * 100 }' | \
    tee -a decode/decode.out;
  done;
done;

rm -f tmp.gt tmp.hyp;
