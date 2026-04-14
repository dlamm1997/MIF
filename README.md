
# Foldseek Search & Filtering

1. Search MIF & DDT structures against AlphaFold and Foldseek database.
2. Filter for TM score >= 0.5, and probability score = 1
3. Get unique list of target accessions.
4. Retrieve UniProt mapping with taxonomy information.
5. Filter for bacterial accessions; remove redundant accession from mapping
6. Use bacterial accessions to filter alignment data.

```
nohup ~/foldseek/bin/foldseek easy-search mif_ddt_structs/ /local/workdir/refdbs/foldseek_afdb/afdb Foldseek_hits_exhaustive_Qcov80.m8 tmpfolder --threads 50 --exhaustive-search  -c 0.8 --cov-mode 2 --format-output "query,target,pident,alntmscore,prob,evalue,alnlen,qstart,qend,tstart,tend,qseq,tseq" &
awk -F"\t" '$4 >= 0.5 && $5 == 1 {print $0}' Foldseek_hits_exhaustive_Qcov80.m8 > Foldseek_hits_exhaustive_Qcov80_TM50_prob1.m8
awk -F"\t" '{print $2}' Foldseek_hits_exhaustive_Qcov80_TM50_prob1.m8  | sort -u | awk -F"-" '{print $2}' > taccs.u
curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/lDM0I865cp?fields=accession%2Clineage&format=tsv" -o FS_uniprot_taxa_mapping_qcov80
grep "Bacteria" FS_uniprot_taxa_mapping_qcov80 | awk '{print $2}' | sort -u > FS_qcov80_bacc
cat FS_qcov80_bacc | grep -f- Foldseek_hits_exhaustive_Qcov80_TM50_prob1.m8 > Foldseek_hits_exhaustive_Qcov80_TM50_prob1_bact.m8
```


# HMMER Search & Filtering


1. Search MIF & DDT Sequences against all UniProt Swiss-Prot and TrEMBL sequences
2. Filter for E-value <= 10^-6
3. Get unique list of target accessions.
4. Retrieve UniProt list of bacterial accessions
5. Remove redundant accessions from mapping
6. Filter HMMER results for bacterial accessions.

```
nohup phmmer  --tblout phmmer_hits.tsv  mif_ddt.fasta /local/workdir/refdbs/UniProtKB/uniprot_sprot_trembl.fasta.gz  &
awk 'NR > 3  && $5 <= 0.000001 {print $0}' phmmer_hits.tsv > phmmer_hits_E-6.tsv
awk -F"|" '{print $2}' phmmer_hits_E-6.tsv  | sort -u  > taccs.u
curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/nXYNvhQTCc?format=list&query=%28%28taxonomy_id%3A2%29%29" -o HMMER_bacc
sort -u HMMER_bacc > HMMER_bacc.u
cat HMMER_bacc.u | grep -f- phmmer_hits_E-6.tsv  > phmmer_hits_E-6_bact.tsv
```

# Combining Accessions

1. Get query -> target mapping from Foldseek results.
2. Get query -> target mapping from HMMER results.
3. Get just unique target accessions from Foldseek results.
4. Get just unique target accessions from HMMER results.
5. Get unique set of combined accessions.

```
awk -F"-" '{print $2, $5}' Foldseek_hits_exhaustive_Qcov80_TM50_prob1_bact.m8  > FS_qacc2tacc_Qcov80
awk  '{print $1, $3}' phmmer_hits_E-6_bact.tsv  | awk -F"|" '{print $2,$3}' | awk '{print $1, $3}' | sed 's/MIF_//g' | awk '{print $2, $1}' > HMMER_qacc2tacc
awk '{print $2}'  FS_qacc2tacc_Qcov80 | sort -u >  FS_tacc_Qcov80.u
awk '{print $2}' HMMER_qacc2tacc | sort -u > HMMER_tacc.u
awk '{print $0}' FS_tacc_Qcov80.u HMMER_tacc.u  | sort -u > combined_tacc_FSQcov80.u
```
# Taxonomy Analysis

1. Retrieve UniProt to NCBI-TaxID mapping
2. Remove any redundant accessions from the UniProt mapping
3. Convert to list of unique TaxIDs
4. Retrieve taxonomy summary files from NCBI using the databases software (also in script get_NCBI.sh)

```
curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/cR3BNoAqhC?fields=accession%2Corganism_id&format=tsv" -o tmp.tacc2txid
awk -F"\t" 'NR > 1 {OFS="\t" ; print $2, $3}'   tmp.tacc2txid >  tmp.tacc2txid.u
awk -F"\t" 'NR > 1{print $3}' tmp.tacc2txid.u | sort -u >  tmp.txid.u
for id in `cat tmp.txid.u`; do datasets download taxonomy taxon $id  --filename /workdir/djl294/NCBI_tax_MIF/$id.zip ; done
```

# Protein Names

1. Get protein names from UniProt
2. Remove redundant accessions
   
```
curl "https://rest.uniprot.org/idmapping/uniprotkb/results/stream/nV2GFE0eyo?fields=accession%2Cprotein_name&format=tsv" -o combined_uniprot_protnames_Qcov80
awk -F"\t" 'NR > 1 {OFS="\t" ; print $2, $3}' combined_uniprot_protnames_Qcov80 | sort -u > combined_uniprot_protnames_Qcov80.u
```

# Secretion Signal

1. Retrieve sequences of MIF mimics
2. Retrieve UniProt annotation for subcellular localization of MIF mimics
3. Subset UniProt annotations for secreted proteins
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



# Motif Analysis 

1. Retrieved relevant structures for structure guided motif analysis (see jupyter notebook for details).

```
cat combined_tacc_FSQcov80.u | parallel "curl 'https://alphafold.ebi.ac.uk/files/AF-{}-F1-model_v4.pdb' -o /local/workdir/djl294/all_mif_structs
```


# Domain Analysis 

-Couldn't find a good space for this in the publication. There are some multidomain MIF mimic proteins.

1. Retrieve domain counts from TED database
2. Get subset of MIFs with multiple domains
3. For multidomain MIFs, retrieve associated CATH labels
4. Retrieve CATH database label to description (name) mapping
5. Simplify the above to a TSV file that can be easily read into pandas
6. Get list of non-redundant single domain proteins for use in MOTIF analysis

```
cat combined_tacc_FSQcov80.u   | parallel -j 8 'count=$(curl -s "https://ted.cathdb.info/api/v1/uniprot/summary/{}?skip=0&limit=100" | jq ".count") echo "{}, $count"' > tacc2domcounts

awk -F"," '$2 >= 2 {print $1}' tacc2domcounts > MIFs_multidomain

cat MIFs_multidomain | parallel -j 8 'acc={} json=$(curl -s "https://ted.cathdb.info/api/v1/uniprot/summary/$acc?skip=0&limit=100") labels=$(echo "$json" | jq -r ".data[].cath_label" | sed "s/^-$/unknown_domain/" | paste -sd "," -) echo "$acc $labels"' > tacc2domlabels

curl "http://download.cathdb.info/cath/releases/latest-release/cath-classification-data/cath-names.txt" -o cath-names.txt

awk -F"    " 'NR > 17 {OFS="\t"; print $1, $3 }' cath-names.txt | sed 's/://g' > cathid2name

awk -F", " 'FNR==NR {arr[$1] ; next} $1 in arr {print $0}' combined_tacc_FSQcov80.u  tacc2domcounts | awk -F", " '$2==1 {print $1}' > tacc2domcounts_nonredun_singledom_accs
```
# Note: 

After initially running this pipeline we made two major updates.

1) Changing original Foldseek parameters from **--cove-mode 0 ** (target and query coverage of 80% in the alignment) to **--cov-mode 2 ** (just query coverage of 80% in the alignment) to avoid filtering out multidomain MIF mimics 
2) An earlier version of the pipeline pulled accessions from the first column when using UniProt ID mapping. This results in redundant accessions in cases where IDs have been merged. We went back and removed those redundant accessions, however we are okay with redundant/identical sequences if they are still mapped to unique accessions as this may represent and identical gene in different but closely related organisms.

In both of the above cases we either:
a) Re-ran the pipeline steps with adjusted parameters/input data
b) Ran the same analysis on just the new accessions and then merged with the old accessions for time/compute intensive task
c) Removed the redundant accessions at the output steps for time/compute intensive task

