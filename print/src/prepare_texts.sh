#!/bin/bash
set -e;

# Directory where the script is placed.
SDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)";
[ "$(pwd)/src" != "$SDIR" ] && \
echo "Please, run this script from the experiment top directory!" >&2 && \
exit 1;

source "../utils/functions_check.inc.sh" || exit 1;
check_all_programs cut gawk sed sort tr || exit 1;

wspace="@";
help_message="
Usage: ${0##*/} [options]

Options:
  --wspace     : (type = string, default = \"$wspace\")
                 Use this symbol to represent the whitespace character.
";
source "../utils/parse_options.inc.sh" || exit 1;

# Prepare character-level transcripts.
mkdir -p "data/lang/char";
for set in tr va te; do
  wo="data/lang/word/${set}.txt";
  ch="data/lang/char/${set}.txt"
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

# Join sets
cat "data/lang/word/{tr,va,te}.txt" > "data/lang/word/all.txt";
cat "data/lang/char/{tr,va,te}.txt" > "data/lang/word/all.txt";
