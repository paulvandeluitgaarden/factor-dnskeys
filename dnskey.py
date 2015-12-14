#!/usr/bin/env python
#
#This script tries to reconstruct the private keys using the moduli and factors in keys.out.
#
#Dependencies: python-dev libgmp3-dev libmpfr-dev libmpc-dev python-ldns python-gmpy2
#Usage: dnskey.py OUTDIR
#
#Input:  OUTDIR is the folder that contains the keys.out file
#Output: DS-record, private key and public key file for each moduli
#        for which the private key can be reconstructed

import sys
import os
import base64
import hashlib
import struct
import gmpy2
import csv
import ldns

def phi(n):
    result = n
    i = 2
    while i * i <= n:
        if n % i == 0:
            while n % i == 0:
                n //= i
            result -= result // i
        i += 1
    if n > 1:
        result -= result // n
    return result

def getFactor(x):
    if gmpy2.is_prime(x):
      factor=x-1
    else:
      if len(str(x)) <= 20:
        factor=phi(x)
      else:
        factor=None    
    return factor

def getDigestType(algorithm):
    switcher = {
        1: 1, #?
        #2: ,
        #3: 1,
        5: 1,
        #6: 1,
        7: 2,
        8: 2,
        10: 2, #?
        12: 3,
        13: 2,
        14: 4,
    }
    return switcher.get(algorithm, "nothing")

def getAlgorithmName(algorithm):
    switcher = {
        1: "RSAMD5",
        #2: "DH",
        #3: "DSA",
        5: "RSASHA1",
        #6: "DSA-NSEC3-SHA1",
        7: "RSASHA1-NSEC3-SHA1",
        8: "RSASHA256",
       10: "RSASHA512",
       #12: "ECC-GOST",
       #13: "ECDSAP256SHA256",
       #14: "ECDSAP384SHA384"
    }
    return switcher.get(algorithm, "nothing")

def format(x):
   s = x.digits(16)
   if len(s) % 2 == 0:
     return base64.b64encode(s.decode('hex'))
   else:
     return base64.b64encode(("0" + s).decode('hex'))

keyinfile = open(sys.argv[1] + '/keys.out', 'r')
reader = csv.reader(keyinfile, delimiter=';')

for row in reader:
   #parse data
   domain = str(row[0])
   flags = int(row[1])
   protocol = int(row[2])
   algorithm = int(row[3])
   #keylength = int(row[4])
   e = gmpy2.mpz("0x" + row[5])
   n = gmpy2.mpz("0x" + row[6]) 
   p = gmpy2.mpz("0x" + row[7])  
   q = n/p

   p_factor = getFactor(p)
   q_factor = getFactor(q)   

   if p_factor != None and q_factor != None:
       #we only take RSA into account
       #1: RSAMD5; 5: RSASHA1; 7: RSASHA1-NSEC3-SHA1; 8: RSASHA256; 10: RSASHA512
       if algorithm != 1 and algorithm != 5 and algorithm != 7 and algorithm != 8 and algorithm != 10:
           print domain + " uses algorithm " + str(algorithm) + ", which is not RSA. Currently only RSA is supported."
           continue
       
       phi_n = p_factor * q_factor
       d = gmpy2.invert(e, phi_n)
       u = gmpy2.invert(q, p)

       #check if pub exponent matches priv exponent
       if (e * d) % phi_n == 1:
         print domain
         #construct RSA-CRT private key
         fw = open("key.priv","w")
         file = """Private-key-format: v1.2
Algorithm: {0:s} ({1:s})
Modulus: {2:s}
PublicExponent: {3:s}
PrivateExponent: {4:s}
Prime1: {5:s}
Prime2: {6:s}
Exponent1: {7:s}
Exponent2: {8:s}
Coefficient: {9:s}""".format(str(algorithm), getAlgorithmName(algorithm),
                             format(n), format(e), format(d), format(p), format(q),
                             format(d % p_factor), format(d % q_factor), format(u)
                            )
         fw.write(file)
         fw.close()

         #construct DNSKEY and DS record
         fw = open("key.priv", "r")
         key = ldns.ldns_key.new_frm_fp(fw)
         key.set_pubkey_owner(ldns.ldns_dname(domain))
         key.set_flags(flags)
         
         pubkey = key.key_to_rr()
         ds = ldns.ldns_key_rr2ds(pubkey, getDigestType(algorithm))

         owner, algo, tag = pubkey.owner(), str(algorithm).zfill(3), key.keytag()
         
         fw = open(sys.argv[1] + "/K%s+%s+%d.key" % (owner,algo,tag), "wb")
         pubkey.print_to_file(fw)

         fw = open(sys.argv[1] + "/K%s+%s+%d.private" % (owner,algo,tag), "wb")
         key.print_to_file(fw)

         fw = open(sys.argv[1] + "/K%s+%s+%d.ds" % (owner,algo,tag), "wb")
         ds.print_to_file(fw)
         
         os.remove("key.priv")
