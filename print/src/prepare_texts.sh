#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
echo "Please, run this script from the experiment top directory!" >&2 && \
exit 1;

wspace="<space>";

for set in tr va te; do
  wo="data/lang/word/${set}.gt";
  # Save original
  cp "${wo}" "data/lang/word/${set}_og.gt"
  # Tokenize
  ./src/tokenize.sh "${wo}";
done

# Prepare character-level transcripts.
mkdir -p "data/lang/char";
for version in "" "_og"; do
  for set in tr va te; do
    wo="data/lang/word/${set}${version}.gt";
    ch="data/lang/char/${set}${version}.gt"
    gawk -v ws="$wspace" '{
      printf("%s", $1);
      for(i=2;i<=NF;++i) {
        for(j=1;j<=length($i);++j) {
          printf(" %s", substr($i, j, 1));
        }
        if (i < NF) printf(" %s", ws);
      }
      printf("\n");
    }' "${wo}" > "${ch}" || { echo "ERROR: Creating file \"${ch}\"!" >&2; exit 1; }
  done
done

# Create syms file
cut -d" " -f2- data/lang/char/{tr,va}.gt |
  tr \  \\n |
  sort -u |
  gawk 'BEGIN{ print "<ctc>", 0; }{ print $1, NR; }' > "data/lang/syms.txt";
