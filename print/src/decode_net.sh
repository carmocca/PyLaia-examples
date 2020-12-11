#!/bin/bash
set -e;
export LC_NUMERIC=C;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
echo "Please, run this script from the experiment top directory!" >&2 && \
exit 1;

for f in data/lang/{char,word}/{te,va}.gt data/lang/syms.txt; do
  [ ! -s "$f" ] && echo "ERROR: File \"$f\" does not exist!" >&2 && exit 1;
done;

mkdir -p decode/{char,word};

for set in va te; do
  ch="decode/char/${set}.hyp";
  # Decode lines
  pylaia-htr-decode-ctc \
    data/lang/syms.txt \
    <(cut -d" " -f1 "data/lang/char/${set}.gt") \
    --img_dirs=[data/imgs/lines_h128/${set}] \
    --config=decode_config.yaml > "${ch}";

  # Clean hyp file. Remove paths from ids
  tmp=$(mktemp);
  while read line; do
    id=$(echo "$line" | awk '{ print $1 }' | xargs -I{} basename {} .png);
    nf=$(echo "$line" | awk '{ print NF }');
    if [ "${nf}" -gt 1 ]; then hyp=$(echo "$line" | cut -d" " -f2-); else hyp=""; fi
    echo "${id}" "${hyp}" >> "${tmp}";
  done < "${ch}";
  mv "${tmp}" "${ch}";

  # Sort by ground truth id
  tmp=$(mktemp);
  awk '{ print $1 }' "data/lang/char/${set}.gt" | while read id; do
    grep -m1 "$id " "$ch" >> "${tmp}";
  done;
  mv "${tmp}" "${ch}";

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
  }' "${ch}" > "decode/word/${set}.hyp";

  # Tokenize word hypotheses
  cp decode/word/${set}{,_tok}.hyp;
  ./src/tokenize.sh decode/word/${set}_tok.hyp;
done;
