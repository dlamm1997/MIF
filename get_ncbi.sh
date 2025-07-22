for id in `cat tmp.txid.u`; do datasets download taxonomy taxon $id  --filename /workdir/djl294/NCBI_tax_MIF/$id.zip ; done
