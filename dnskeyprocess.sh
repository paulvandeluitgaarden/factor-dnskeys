#!/bin/bash
#
#Script tries to factor moduli and returns the moduli that can have a shared factor and private key
#information for those moduli, if it can be calculated.
#
#Dependencies: process.sh; dnskey.py (must be in same folder as this file)
#Usage: $0 INFILE OUTDIR
#
#Input:  INFILE - the data file in format: domain;flag;protocol;algorithm;length;n;e
#        OUTDIR - the directory where the output files are placed
#Output: keys.out  - factorable records from INFILE with additional the factor
#                    (if data set is split, factorable moduli may occur multiple times in this file)
#        *.ds      - DS record for an obtained modulo
#        *.private - The private key for an obtained modulo
#        *.key     - Public key for an obtained modulo

INFILE="$1"
OUTDIR="$2"
BINDIR=$(cd `dirname ${0}` ; pwd)
MAX_PROCESS_SIZE=2000000 #can be tweaked

if [ -z $INFILE ] || [ -z $OUTDIR ]; then
  echo "$0 INFILE OUTDIR"
  echo "INFILE - the data file in format: domain;flag;protocol;algorithm;length;n;e"
  echo "OUTDIR - the directory where the output files are placed"
  exit
fi

mkdir -p $OUTDIR

echo "[$( date +%T )]: Stage 1: Split data"

block_size=$(($MAX_PROCESS_SIZE / 2))
lines=$(wc -l < $INFILE)
blocks=$(printf %0.f $(echo "$lines/$block_size + 0.5" | bc -l)) #round to nearest integer

for (( i=0; i < $blocks; i++))
do
  start=$((i * $block_size + 1))
  end=$(((i+1) * $block_size))
  sed -n "$start,${end}p" $INFILE > "$OUTDIR/set-${i}.csv"
done

if [ $(($blocks - 1)) -eq 0 ]; then
  cat "$OUTDIR/set-0.csv" > "$OUTDIR/set-process.csv"
  $BINDIR/process.sh "$OUTDIR/set-process.csv" "$BINDIR/fastgcd/fastgcd" $OUTDIR
fi

for (( i=0; i < $(($blocks - 1)); i++))
do
  for (( j=$(($i + 1)); j < $blocks; j++))
  do
    echo "[$( date +%T )]: Comparing set-$i.csv with set-$j.csv"
    cat "$OUTDIR/set-$i.csv" "$OUTDIR/set-$j.csv" > "$OUTDIR/set-process.csv"
    $BINDIR/process.sh "$OUTDIR/set-process.csv" "$BINDIR/fastgcd/fastgcd" $OUTDIR
  done
done

echo "[$( date +%T )]: Stage 2: Concat output"
cat "$OUTDIR/keys.processed" | sort | uniq > "$OUTDIR/keys.out"
rm -f "$OUTDIR/keys.processed" "$OUTDIR/set-*"

echo "[$( date +%T )]: Stage 3: Calculating private keys"
python "$BINDIR/dnskey.py" $OUTDIR

echo "[$( date +%T )]: Process end"
