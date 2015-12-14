#!/bin/sh
#
#Script converts data set and its factorable moduli to a sqlite3 database.
#
#Dependencies: sqlite3
#Usage: $0 KEYFILE GCDFILE OUTFILE
#
#Input:  KEYFILE - the data set in format domain;flag;protocol;algorithm;length;e;n
#        GCDFILE - the factorable records from KEYFILE in format domain;flag;protocol;algorithm;length;e;n;factor
#        OUTFILE - a name for a new sqlite3 database
#Output: a sqlite3 database in OUTFILE

KEYFILE="$1"
GCDFILE="$2"
OUTFILE="$3"

if [ -z $KEYFILE ] || [ -z $GCDFILE ] || [ -z $OUTFILE ]; then
  echo "Usage: $0 KEYFILE GCDFILE OUTFILE"
  echo "KEYFILE - the data set in format domain;flag;protocol;algorithm;length;e;n"
  echo "GCDFILE - the factorable records from KEYFILE in format domain;flag;protocol;algorithm;length;e;n;factor"
  echo "OUTFILE - a name for a new sqlite3 database"
  exit
fi

domains=$(mktemp)
keys=$(mktemp)
rrs=$(mktemp)
factors=$(mktemp)

echo "[$( date +%T )]: Gathering data"
echo "domain" > $domains
echo "e;n;length" > $keys
sed '1s/^/domain;flag;protocol;algorithm;length;e;n\n/' $KEYFILE > $rrs
sed '1s/^/domain;flag;protocol;algorithm;length;e;n;factor\n/' $GCDFILE > $factors

awk -F ";" '{print $1}' $KEYFILE | sort | uniq >> $domains
awk -F ";" '{print $6";"$7";"$5}' $KEYFILE | sort | uniq >> $keys

echo "[$( date +%T )]: Creating tables for database $OUTFILE"
echo "CREATE TABLE domains ( id INTEGER PRIMARY KEY AUTOINCREMENT, domain TEXT);" | sqlite3 $OUTFILE
echo "CREATE TABLE keys ( id INTEGER PRIMARY KEY AUTOINCREMENT, e TEXT, n TEXT, length INTEGER);" | sqlite3 $OUTFILE
echo "CREATE TABLE rrs ( id INTEGER PRIMARY KEY AUTOINCREMENT, domainid INTEGER, keyid INTEGER, algorithm INTEGER, flag INTEGER, FOREIGN KEY(keyid) REFERENCES keys(id), FOREIGN KEY(domainid) REFERENCES domains(id) );" | sqlite3 $OUTFILE
echo "CREATE TABLE factors ( id INTEGER PRIMARY KEY AUTOINCREMENT, rrid INTEGER, factor TEXT, FOREIGN KEY(rrid) REFERENCES rrs(id) );" | sqlite3 $OUTFILE

echo "[$( date +%T )]: Fill table domains (data from: $domains)"
echo ".import $domains tmp" | sqlite3 $OUTFILE
echo "INSERT INTO domains(domain) SELECT * FROM tmp;" | sqlite3 $OUTFILE
echo "DROP TABLE tmp;" | sqlite3 $OUTFILE

echo "[$( date +%T )]: Fill table keys (data from: $keys)"
echo ".separator ;\n.import $keys tmp" | sqlite3 $OUTFILE
echo "INSERT INTO keys(e,n,length) SELECT * FROM tmp;" | sqlite3 $OUTFILE
echo "DROP TABLE tmp;" | sqlite3 $OUTFILE

echo "[$( date +%T )]: Fill table rrs (data from: $rrs)"
echo ".separator ;\n.import $rrs tmp" | sqlite3 $OUTFILE
echo "INSERT INTO rrs(domainid,keyid,algorithm,flag) SELECT d.id, k.id, a.algorithm, a.flag FROM domains AS d, keys AS k, tmp AS a WHERE a.domain = d.domain AND k.n = a.n AND k.e = a.e;" | sqlite3 $OUTFILE
echo "DROP TABLE tmp;" | sqlite3 $OUTFILE

echo "[$( date +%T )]: Fill table factors (data from: $factors)"
echo ".separator ;\n.import $factors tmp" | sqlite3 $OUTFILE
echo "INSERT INTO factors(rrid,factor) SELECT r.id, a.factor FROM domains AS d, keys AS k, rrs AS r, tmp AS a WHERE r.keyid = k.id AND r.domainid = d.id AND a.domain = d.domain AND k.n = a.n AND k.e = a.e AND k.length = a.length AND r.algorithm = a.algorithm AND r.flag = a.flag;" | sqlite3 $OUTFILE
echo "DROP TABLE tmp;" | sqlite3 $OUTFILE

echo "[$( date +%T )]: Done"

rm -f $domains $keys $rrs $factors
