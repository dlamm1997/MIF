cat MIFs_multidomain | parallel -j 8 '
  acc={}
  json=$(curl -s "https://ted.cathdb.info/api/v1/uniprot/summary/$acc?skip=0&limit=100")
  labels=$(echo "$json" | jq -r ".data[].cath_label" | sed "s/^-$/unknown_domain/" | paste -sd "," -)
  echo "$acc $labels"
' > tacc2domlabels
