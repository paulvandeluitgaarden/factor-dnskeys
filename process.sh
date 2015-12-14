#!/bin/bash
#
#Script processes the a list of unique moduli through FASTGCD software.
#
#Dependencies: fastgcd
#Usage: $0 INFILE FASTGCD OUTDIR
#
#Input:  INFILE  - data set in the format domain;flag;protocol;algorithm;keylength;e;n
#        FASTGCD - path to fastgcd software
#        OUTDIR  - directory in which processing takes place
#Output: file keys.processed which contains the records from the data set which share a
#        factor. Saved in OUTDIR in format domain;flag;protocol;algorithm;keylength;e;n;factor

INFILE="$1"
FASTGCD="$2"
OUTDIR="$3"

if [ -z $INFILE ] || [ -z $FASTGCD ] || [ -z $OUTDIR ]; then
  echo "$0 INFILE OUTDIR"
  echo "INFILE  - data set in the format domain;flag;protocol;algorithm;keylength;e;n"
  echo "FASTGCD - path to fastgcd software"
  echo "OUTDIR  - directory in which processing takes place"
  exit
fi

cd $OUTDIR

#getting moduli from input file, get distinct set
awk -F ";" '{print $7}' $INFILE | sort --parallel=4 -S 2048M | uniq > "processed"

#need to be processed or not
lines=$(wc -l < "processed")
if [ $lines -eq 1 ]; then
   rm "processed"
   exit
fi

#calculate GCDs
$FASTGCD "processed"

if [ ! -f "vulnerable_moduli" ]; then
   rm -f "processed"
   exit
fi

paste -d ";" "vulnerable_moduli" "gcds" > "fastgcd.out" #combine output FASTGCD
rm -f "vulnerable_moduli" "gcds" "processed" *.mpz

fastgcdcount=$(wc -l < "fastgcd.out")
if [ $fastgcdcount -eq 0 ]; then
    rm -f "fastgcd.out"
    exit
fi

#generate output
IFS=';'
while read n p; do
    while read -r line ; do
       echo "$line;$p" >> "keys.processed"
    done < <(LC_ALL=C grep ";$n\$" $INFILE)
done < "fastgcd.out"

rm "fastgcd.out"

