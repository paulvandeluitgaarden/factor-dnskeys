#!/bin/sh

#install dependencies
sudo apt-get python-dev libgmp3-dev libmpfr-dev libmpc-dev python-ldns python-gmpy2 -y

#install fastgcd software
curl -O "https://factorable.net/fastgcd-1.0.tar.gz"
tar -xzf "fastgcd-1.0.tar.gz"
cd fastgcd

echo "How many cores may be used to process?"
read cores
sed -i "s/^#define NTHREADS 4/#define NTHREADS $cores/" "fastgcd.c"

#install gmp patch
curl -O "ftp://ftp.gmplib.org/pub/gmp-5.0.5/gmp-5.0.5.tar.bz2"
tar -jxf "gmp-5.0.5.tar.bz2"
cd "gmp-5.0.5"
patch -p 1 < "../gmp-5.0.5.patch"
mkdir "../gmp-patched"
./configure --prefix="$PWD/../gmp-patched/"
make
make install
cd ..
make

#remove resources
rm -f "dnsgcd.zip" "fastgcd-1.0.tar.gz"

#done
echo "Installation succeeded. Proceed with: $(pwd)/dnskeyprocess.sh 'full-path-to-data-set' 'full-path-to-dest-dir'"
