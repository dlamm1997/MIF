# FoldSeek Search

1. Search MIF & DDT strucutures against alphafold foldseek database.
2. Filter for TM score >= 0.5, and probability score = 1
3. Get unique list of target accessions.
4. Retrieve uniprot mapping with taxanomy information.
5. Filter for bacterial accessions.
6. Use bacterial accessions to filter alignemnet data.

```nohup ~/foldseek/bin/foldseek easy-search mif_ddt_structs/ /local/workdir/refdbs/foldseek_afdb/afdb Foldseek_hits_exhaustive_cov80.m8 tmpfolder --threads 50 --exhaustive-search  -c 0.8 --cov-mode 0 --format-output "query,target,pident,alntmscore,prob,evalue,alnlen,qstart,qend,tstart,tend,qseq,tseq" &

awk -F"\t" '$4 >= 0.5 && $5 == 1 {print $0}' Foldseek_hits_exhaustive_cov80.m8 > Foldseek_hits_exhaustive_cov80_TM50_prob1.m8

awk -F"\t" '{print $2}' Foldseek_hits_exhaustive_cov80_TM50_prob1.m8  | sort -u | awk -F"-" '{print $2}' > taccs.u

curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/zWKOzO4Y88?fields=accession%2Corganism_name%2Clineage&format=tsv" -o FS_uniprot_taxa_mapping

grep "Bacteria" FS_uniprot_taxa_mapping | awk '{print $1}' > FS_bacc
 cat FS_bacc | grep -f- Foldseek_hits_exhaustive_cov80_TM50_prob1.m8 > Foldseek_hits_exhaustive_cov80_TM50_prob1_bact.m8 ```
