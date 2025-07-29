cat tmp.txid.u | parallel 'count=$(curl -s "https://rest.uniprot.org/uniprotkb/stream?format=list&query=(taxonomy_id:{})" | wc -l); echo {} $count >> taxid2count'
