#!/usr/bin/env bash
#
# Download AlphaFold DB structures for UniProt accessions read from stdin.
#
# Usage:
#   cat combined_tacc.u | ./script.sh
#
# Optional environment variables:
#   JOBS=16             number of parallel downloads (default 16)
#   FORMAT=pdb          "pdb" or "cif" (default pdb)
#   OUTDIR=all_mif_structs
#
# Re-running is safe: files that already exist are skipped, so an
# interrupted run can simply be restarted with the same command.

set -uo pipefail

export OUTDIR="${OUTDIR:-mam_mif_structs}"
export FORMAT="${FORMAT:-pdb}"
JOBS="${JOBS:-16}"
export FAILED_LOG="$OUTDIR/failed_ids.txt"

if [[ -t 0 ]]; then
    echo "Usage: cat ids.txt | $0" >&2
    exit 1
fi

if [[ "$FORMAT" != "pdb" && "$FORMAT" != "cif" ]]; then
    echo "FORMAT must be 'pdb' or 'cif'" >&2
    exit 1
fi

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

mkdir -p "$OUTDIR"
: > "$FAILED_LOG"

fetch_one() {
    local id="$1"
    local out="$OUTDIR/${id}.${FORMAT}"

    # Skip anything already downloaded
    [[ -s "$out" ]] && return 0

    # Ask the AlphaFold API for the current file URL (handles model version changes)
    local json url
    if ! json=$(curl -sS --fail --retry 3 --retry-delay 2 --max-time 60 \
            "https://alphafold.ebi.ac.uk/api/prediction/${id}" 2>/dev/null); then
        echo -e "${id}\tno_alphafold_entry" >> "$FAILED_LOG"
        return 0
    fi

    url=$(printf '%s' "$json" \
        | grep -o "\"${FORMAT}Url\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -n 1 \
        | sed 's/.*"\(https\{0,1\}:[^"]*\)"$/\1/')

    if [[ -z "$url" ]]; then
        echo -e "${id}\tno_${FORMAT}_url" >> "$FAILED_LOG"
        return 0
    fi

    # Download to a temp name, then rename, so partial files never look complete
    if curl -sS --fail --retry 3 --retry-delay 2 --max-time 300 \
            -o "${out}.part" "$url" 2>/dev/null; then
        mv "${out}.part" "$out"
    else
        rm -f "${out}.part"
        echo -e "${id}\tdownload_failed" >> "$FAILED_LOG"
    fi
}
export -f fetch_one

# Clean input: drop CRLF, blank lines, anything after whitespace,
# pull the accession out of "sp|P12345|NAME" style lines, and dedupe.
IDLIST=$(mktemp)
trap 'rm -f "$IDLIST"' EXIT

tr -d '\r' \
    | sed 's/^[[:space:]]*//; s/[[:space:]].*$//' \
    | awk -F'|' 'NF >= 2 { print $2; next } { print }' \
    | grep -v '^$' \
    | sort -u > "$IDLIST"

TOTAL=$(wc -l < "$IDLIST")
echo "Fetching $TOTAL unique IDs into $OUTDIR/ with $JOBS parallel jobs..."

xargs -P "$JOBS" -n 1 bash -c 'fetch_one "$1"' _ < "$IDLIST"

DONE=$(find "$OUTDIR" -maxdepth 1 -name "*.${FORMAT}" | wc -l)
FAILED=$(wc -l < "$FAILED_LOG")
echo "Done. $DONE structures in $OUTDIR/, $FAILED failures (see $FAILED_LOG)."
