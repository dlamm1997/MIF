cat combined_tacc_FSQcov80.u   | parallel -j 8 '
  count=$(curl -s "https://ted.cathdb.info/api/v1/uniprot/summary/{}?skip=0&limit=100" | jq ".count")
  echo "{}, $count"
' > tacc2domcounts
