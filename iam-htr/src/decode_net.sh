#!/bin/bash
set -e;
export LC_NUMERIC=C;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
    echo "Please, run this script from the experiment top directory!" >&2 && \
    exit 1;

lang=puigcerver;

for f in data/lang/"$lang"/lines/{char,word}/{te,va}.txt; do
  [ ! -s "$f" ] && echo "ERROR: File \"$f\" does not exist!" >&2 && exit 1;
done;

hasComputeWer=0;
if which compute-wer-bootci &> /dev/null; then hasComputeWer=1; fi;
[ $hasComputeWer -ne 0 ] ||
echo "WARNING: compute-wer-bootci was not found, so CER/WER won't be computed!" >&2;

mkdir -p decode/{forms,lines}/{char,word};

for p in va te; do
  lines_char="decode/lines/char/${p}.txt";
  lines_word="decode/lines/word/${p}.txt";
  forms_char="decode/forms/char/${p}.txt";
  forms_word="decode/forms/word/${p}.txt";
  img_list="data/splits/$lang/${p}.lst";

  # Decode lines
  pylaia-htr-decode-ctc \
    syms.txt \
    "$img_list" \
    --config=decode_config.yaml \
  | sort -V > "$lines_char";
  # Note: The decoding step does not return the output
  # In the same order as the input unless batch size 1
  # is used. Sort must be done afterwards

  # Get word-level transcript hypotheses for lines
  gawk '{
    printf("%s ", $1);
    for (i=2;i<=NF;++i) {
      if ($i == "<space>")
        printf(" ");
      else
        printf("%s", $i);
    }
    printf("\n");
  }' "$lines_char" > "$lines_word";

  # Get form char-level transcript hypothesis
  gawk '{
    if (match($1, /^([^ ]+)-[0-9]+$/, A)) {
      if (A[1] != form_id) {
        if (form_id != "") printf("\n");
        form_id = A[1];
        $1 = A[1];
        printf("%s", $1);
      } else {
        printf(" %s", "<space>");
      }
      for (i=2; i<= NF; ++i) { printf(" %s", $i); }
    }
  }' < "$lines_char" > "$forms_char";

  # Get form word-level transcript hypothesis
  gawk '{
    if (match($1, /^([^ ]+)-[0-9]+$/, A)) {
      if (A[1] != form_id) {
        if (form_id != "") printf("\n");
        form_id = A[1];
        $1 = A[1];
        printf("%s", $1);
      }
      for (i=2; i<= NF; ++i) { printf(" %s", $i); }
    }
  }' < "$lines_word" > "$forms_word";
done;

if [ $hasComputeWer -eq 1 ]; then
  rm -f decode/decode.out;
  for i in lines forms; do
    for j in char word; do
      for k in va te; do
        # Compute CER and WER using Kaldi's compute-wer-bootci
        compute-wer-bootci \
          --print-args=false \
          --mode=strict \
          "ark:data/lang/$lang/${i}/${j}/${k}.txt" \
          "ark:decode/${i}/${j}/${k}.txt" | \
        awk -v i=$i -v j=$j -v k=$k '{ $1=""; $2=":"; print i"/"j"/"k$0}' | \
        tee -a decode/decode.out;
      done;
    done;
  done;
fi;
