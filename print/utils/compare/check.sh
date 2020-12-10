#!/bin/bash
set -e;

gt_dir=$1;
hyp_dir=$2;

# Generate ground-truth file
rm -f word.gt;
find "${gt_dir}/page" -type f \( -iname \*.xml \) |
while read xml; do
  python3 parse_pagexml_text.py "${xml}" >> word.gt;
done

# Generate hypothesis file
rm -f word.hyp;
find "${hyp_dir}/page" -type f \( -iname \*.xml \) |
while read xml; do
  python3 parse_pagexml_text.py "${xml}" >> word.hyp;
done

# Remove special characters
tmpid=$(mktemp); tmpgt=$(mktemp);
awk '{ print $1 }' word.hyp > "${tmpid}";
cut -d" " -f2- word.hyp | sed 's/\([.,:;+-=¿?()¡!/\„“—#%¬’]\)//g' > "${tmpgt}";
paste -d" " "${tmpid}" "${tmpgt}" > word.hyp;
rm -f "${tmpid}" "${tmpgt}";
tmpid=$(mktemp); tmpgt=$(mktemp);
awk '{ print $1 }' word.gt > "${tmpid}";
cut -d" " -f2- word.gt | sed 's/\([.,:;+-=¿?()¡!/\„“—#%¬’]\)//g' > "${tmpgt}";
paste -d" " "${tmpid}" "${tmpgt}" > word.gt;
rm -f "${tmpid}" "${tmpgt}";

# Sort by ID
sort -k1 word.hyp -o word.hyp;
sort -k1 word.gt -o word.gt;

# Check ID order
awk '{ print $1 }' word.hyp > id.hyp;
awk '{ print $1 }' word.gt > id.gt;
if diff -q id.hyp id.gt; then echo "ID order is correct"; else echo "Incorrect ID order"; fi
rm -f id.hyp id.gt;

# Prepare character-level transcripts.
for x in gt hyp; do
  gawk -v ws="<space>" '{
    printf("%s", $1);
    for(i=2;i<=NF;++i) {
      for(j=1;j<=length($i);++j) {
        printf(" %s", substr($i, j, 1));
      }
      if (i < NF) printf(" %s", ws);
    }
    printf("\n");
  }' "word.${x}" > "char.${x}";
done

echo "Kaldi CER:";
"$HOME"/software/kaldi/src/bin/compute-wer --print-args=false --mode=strict \
  "ark:char.gt" "ark:char.hyp";

echo "Kaldi WER:";
"$HOME"/software/kaldi/src/bin/compute-wer --print-args=false --mode=strict \
  "ark:word.gt" "ark:word.hyp";

echo -e "\nTranskribusErrorRate CER";
java -cp "$HOME"/software/TranskribusErrorRate/target/TranskribusErrorRate-2.2.7-jar-with-dependencies.jar \
  eu.transkribus.errorrate.HtrErrorTxt \
  <(cut -d" " -f2- "word.gt") \
  <(cut -d" " -f2- "word.hyp");

echo -e "\nTranskribusErrorRate WER";
java -cp "$HOME"/software/TranskribusErrorRate/target/TranskribusErrorRate-2.2.7-jar-with-dependencies.jar \
  eu.transkribus.errorrate.HtrErrorTxt \
  <(cut -d" " -f2- "word.gt") \
  <(cut -d" " -f2- "word.hyp") --wer;

rm -rf word.gt word.hyp char.gt char.hyp logs;
