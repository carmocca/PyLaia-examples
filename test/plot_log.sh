#!/bin/bash
set -e;

[ $# -lt 2 ] && echo "Usage: ${0##*/} measure log [log ...]" >&2 && exit 1;
case "$1" in
  tr_loss)
    regex="^.* Epoch( =)? +([0-9]+),.* TR Loss = +([0-9e+.-]+),.*$";
  ;;
  va_loss)
    regex="^.* Epoch( =)? +([0-9]+),.* VA Loss = +([0-9e+.-]+),.*$";
  ;;
  tr_cer)
    regex="^.* Epoch( =)? +([0-9]+),.* TR CER = +([0-9.]+)%.*$";
  ;;
  va_cer)
    regex="^.* Epoch( =)? +([0-9]+),.* VA CER = +([0-9.]+)%.*$";
  ;;
  tr_wer)
    regex="^.* Epoch( =)? +([0-9]+),.* TR WER = +([0-9.]+)%.*$";
  ;;
  va_wer)
    regex="^.* Epoch( =)? +([0-9]+),.* VA WER = +([0-9.]+)%.*$";
  ;;
  *)
    echo "Unknown measure \"$1\"!" >&2;
    exit 1;
esac;
shift 1;

files=();
tmpfiles=();
while [ $# -gt 0 ]; do
  files+=("$(echo "$1" | sed -r 's|_|\\_|g')");
  tmpfiles+=("$(mktemp)");
  gawk -v regex="$regex" '{
    if(match($0, regex, arr)) {
      print arr[2], arr[3];
    }
  }' "$1" > "${tmpfiles[-1]}";
  shift 1;
done;

{
  echo "set logscale y";
  echo "set grid ytics mytics";
  echo "plot \\";
  for i in $(seq "${#tmpfiles[@]}"); do
    echo -n "'${tmpfiles[i-1]}' u 1:2 w l t '${files[i-1]}'";
    if [ "$i" -lt "${#tmpfiles[@]}" ]; then
      echo ", \\";
    else
      echo "";
    fi;
  done;
} | gnuplot -p;
rm -f "${#tmpfiles[@]}";
