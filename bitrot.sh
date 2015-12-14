#!/bin/sh
#
#This script searches for bitrot in the set of moduli and reports the moduli which suffer
#from bitrot.
#
#Usage: $0 INFILE
#
#Input:  INFILE - distinct and sorted set of moduli
#Output: file mod.bitrot contains the moduli which suffer from bitrot

if [ -z "$1" ]; then
  echo "$0 INFILE"
  echo "INFILE - distinct and sorted set of moduli"
  exit
fi

prevline=""
while read line
do
    modheadfst=$(echo $prevline | head -c 10)
    modheadsnd=$(echo $line | head -c 10)

    modtailfst=$(echo $prevline | tail -c 10)
    modtailsnd=$(echo $line | tail -c 10)

    if [ "$modheadfst" = "$modheadsnd" ] || [ "$modtailfst" = "$modtailsnd" ]; then
      echo "Original: $prevline" >> "mod.bitrot"
      echo "Bitrot:   $line" >> "mod.bitrot"
      echo "" >> "mod.bitrot"
    else
      prevline=$line
    fi
done < "$1"

