#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
echo "Please, run this script from the experiment top directory!" >&2 && \
exit 1;

wspace="<space>";
tokenize=true;

for set in tr va te; do
  wo="data/lang/word/${set}.gt";

  # Delete empty images and their transcriptions
  gawk 'NF <= 1' "${wo}" | xargs -I{} find "data/imgs/lines/${set}" -name {}.png -delete;
  gawk -i inplace 'NF > 1' "${wo}";

  # Sort inplace by id
  sort -k1 "${wo}" -o "${wo}";

  if [ "$tokenize" = true ]; then
    # Save original
    cp "${wo}" "data/lang/word/${set}_og.gt"
    # Tokenize
    awk '{ print $1 }' "${wo}" > tmp_id.txt;
    cut -d" " -f2- "${wo}" | sed 's/\([.,:;+-=¿?()¡!/\„“—#%¬]\)/ \1 /g' > tmp_gt.txt;
    paste -d" " tmp_id.txt tmp_gt.txt > "${wo}";
    rm -f tmp_id.txt tmp_gt.txt;
  fi
  # Strip leading, trailing, and contiguous whitespace
  sed -i -r 's/^ +//g; s/ +/ /g; s/ $//g' "${wo}";
done

# Prepare character-level transcripts.
mkdir -p "data/lang/char";
for set in tr va te; do
  wo="data/lang/word/${set}.gt";
  ch="data/lang/char/${set}.gt"
  gawk -v ws="$wspace" '{
    printf("%s", $1);
    for(i=2;i<=NF;++i) {
      for(j=1;j<=length($i);++j) {
        printf(" %s", substr($i, j, 1));
      }
      if (i < NF) printf(" %s", ws);
    }
    printf("\n");
  }' "${wo}" | sort -k1 > "${ch}" || { echo "ERROR: Creating file \"${ch}\"!" >&2; exit 1; }
done

# Create syms file
cut -d" " -f2- data/lang/char/{tr,va}.gt |
  tr \  \\n |
  sort -u |
  gawk 'BEGIN{ print "<ctc>", 0; }{ print $1, NR; }' > "data/lang/syms.txt";
