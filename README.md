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

# Combining Accessions

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
# Taxonomy Analysis

1. Retreive uniprot to NCBI-TaxID mapping
2. Convert to list of unique TaxIDs
3. Retreive taxonomy summary files from NCBI using the databases software (also in script get_NCBI.sh)

```
curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/gvExAW1mHa?fields=accession%2Corganism_id&format=tsv" -o tmp.tacc2txid.u

awk -F"\t" 'NR > 1{print $3}' tmp.tacc2txid.u | sort -u >  tmp.txid.u

for id in `cat tmp.txid.u`; do datasets download taxonomy taxon $id  --filename /workdir/djl294/NCBI_tax_MIF/$id.zip ; done
```
# Protein Names
1. Get Protein Names from UniProt
   
```
curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/gvExAW1mHa?fields=accession%2Cprotein_name&format=tsv&query=%28*%29" -o combined_uniprot_protnames
```

# Secretion Signal
1. Retreive sequences of MIF-like proteins
2. Retreive UniProt Annotation for Subcellular Localization of MIF like proteins
3. Subset UniProt Annotations for Secreted Proteins
4. Run SignalP 6.0 slow-sequential - note: this failed to produce some individual output files due to long names, but we only needed the summary file
5. Run DeepTMHMM
6. Run DeepLocPro

```
curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/gvExAW1mHa?format=fasta" -o MIFs.fasta

curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/gvExAW1mHa?fields=accession%2Ccc_subcellular_location&format=tsv" -o MIFs_UniProt_SubcellularLocalization

grep "Secreted"  MIFs_UniProt_SubcellularLocalization | awk '{print $1}' > MIFs_UniProt_Secreted

nohup singularity run --bind $PWD:/data --pwd /data /programs/signalp-6/signalp6-cpu.sif   signalp6 --fastafile MIFs.fasta --output_dir signal_p_out --mode slow > signalp_mif.log 2>&1 &

docker1 run -v /workdir/djl294/:/openprotein/data/ -w /openprotein -e LC_ALL=C.UTF-8 -e LANG=C.UTF-8 --rm a982e3785a74 python3 predict.py --fasta data/MIFs.fasta

deeplocpro -f /workdir/djl294/MIFs.fasta  -o /workdir/djl294/deeplocpro_out/
```

   
