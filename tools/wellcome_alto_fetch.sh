#!/bin/bash
# $1=bid $2=pages.txt $3=out.txt
BID=$1; PAGES=$2; OUT=$3
TOTAL=$(wc -l < "$PAGES")
DONE=$(grep -c "=== page" "$OUT" 2>/dev/null || echo 0)
echo "start $BID total=$TOTAL done=$DONE"
N=$DONE
while [ $N -lt $TOTAL ]; do
  N=$((N+1))
  P=$(sed -n "${N}p" "$PAGES")
  OK=0
  for A in 1 2 3; do
    curl -sL --max-time 25 -o "/tmp/pg_${BID}.xml" "https://api.wellcomecollection.org/text/alto/${BID}/${P}.jp2" && [ "$(stat -c%s /tmp/pg_${BID}.xml)" -gt 200 ] && OK=1 && break
    sleep 2
  done
  if [ $OK -eq 1 ]; then
    TEXT=$(python3 -c "
import re, sys
xml = open('/tmp/pg_${BID}.xml', encoding='utf-8', errors='ignore').read()
words = re.findall(r'CONTENT=\"([^\"]*)\"', xml)
print(' '.join(w for w in words if w.strip()))
")
    echo "" >> "$OUT"; echo "=== page $N ===" >> "$OUT"; echo "$TEXT" >> "$OUT"
  else
    echo "" >> "$OUT"; echo "=== page $N === [FETCH FAILED]" >> "$OUT"
  fi
  if [ $((N % 50)) -eq 0 ]; then echo "$N/$TOTAL"; fi
done
echo "DONE $TOTAL pages"
