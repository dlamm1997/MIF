cat combined_tacc.u | parallel -j 8 '
  count=$(curl -s "https://ted.cathdb.info/api/v1/uniprot/summary/{}?skip=0&limit=100" | jq ".count")
  echo "{}, $count"
' > tacc2domcounts
