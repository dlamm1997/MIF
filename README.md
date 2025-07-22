# FoldSeek Search & Filtering

1. Search MIF & DDT strucutures against alphafold foldseek database.
2. Filter for TM score >= 0.5, and probability score = 1
3. Get unique list of target accessions.
4. Retrieve uniprot mapping with taxanomy information.
5. Filter for bacterial accessions.
6. Use bacterial accessions to filter alignemnet data.

```
nohup ~/foldseek/bin/foldseek easy-search mif_ddt_structs/ /local/workdir/refdbs/foldseek_afdb/afdb Foldseek_hits_exhaustive_cov80.m8 tmpfolder --threads 50 --exhaustive-search  -c 0.8 --cov-mode 0 --format-output "query,target,pident,alntmscore,prob,evalue,alnlen,qstart,qend,tstart,tend,qseq,tseq" &
awk -F"\t" '$4 >= 0.5 && $5 == 1 {print $0}' Foldseek_hits_exhaustive_cov80.m8 > Foldseek_hits_exhaustive_cov80_TM50_prob1.m8
awk -F"\t" '{print $2}' Foldseek_hits_exhaustive_cov80_TM50_prob1.m8  | sort -u | awk -F"-" '{print $2}' > taccs.u
curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/zWKOzO4Y88?fields=accession%2Corganism_name%2Clineage&format=tsv" -o FS_uniprot_taxa_mapping
grep "Bacteria" FS_uniprot_taxa_mapping | awk '{print $1}' > FS_bacc
cat FS_bacc | grep -f- Foldseek_hits_exhaustive_cov80_TM50_prob1.m8 > Foldseek_hits_exhaustive_cov80_TM50_prob1_bact.m8
```


# HMMER Search & Filtering

1. Search MIF & DDT Sequences against all uniprot swiss-prot and tremble sequences
2. Filter for E-value <= 10^-6
3. Get unique list of target accessions.
4. Retreive uniprot list of bacterial accessions

```
nohup phmmer  --tblout phmmer_hits.tsv  mif_ddt.fasta /local/workdir/refdbs/UniProtKB/uniprot_sprot_trembl.fasta.gz  &
awk 'NR > 3  && $5 <= 0.000001 {print $0}' phmmer_hits.tsv > phmmer_hits_E-6.tsv
awk -F"|" '{print $2}' phmmer_hits_E-6.tsv  | sort -u  > taccs.u
curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/nXYNvhQTCc?format=list&query=%28%28taxonomy_id%3A2%29%29" -o HMMER_bacc
cat HMMER_bacc | grep -f- phmmer_hits_E-6.tsv  > phmmer_hits_E-6_bact.tsv
```

#Combining Accessions

1. Get querry -> target mapping from foldseek results.
2. Get querry -> target mapping from hmmer results.
3. Get just unique target accessions from foldseek results.
4. Get just unique target accessions from hmmer results.
5. Get unique set of combinded accessions.

```
awk -F"-" '{print $2, $5}' Foldseek_hits_exhaustive_cov80_TM50_prob1_bact.m8  > FS_qacc2tacc
awk  '{print $1, $3}' phmmer_hits_E-6_bact.tsv  | awk -F"|" '{print $2,$3}' | awk '{print $1, $3}' | sed 's/MIF_//g' | awk '{print $2, $1}' > HMMER_qacc2tacc
awk '{print $2}'  FS_qacc2tacc | sort -u >  FS_tacc.u
awk '{print $2}' HMMER_qacc2tacc | sort -u > HMMER_tacc.u
awk '{print $0}' FS_tacc.u HMMER_tacc.u  | sort -u > combined_tacc.u
```

