#!/bin/sh

privateKey=Keys/MIB-High_DK_private.pem

if [ "$#" -lt "2" ]
then
  echo "Usage: $0 <metainfo2 file> <metainfo2 output> [path/to/privateKey]"
  exit
fi

if [ ! -f $1 ]
then
  echo "Original Metainfo file not exists!"
  exit
fi

if [ -f $2 ]
then
  echo "Output Metainfo file exists!"
  exit
fi

if [ "x$3" != "x$3" ]
then
  if [ -f $3 ]
  then
	privateKey=$3
  else
	echo "Private key ($3) not exist!. Use default $privateKey"
  fi
fi

tmpFile=$2

grep -iv signature $1 > $tmpFile

echo "[Signature]" >> $tmpFile

echo "Sign with $privateKey"
ix=0;
for lin in $(openssl dgst -sha1 -binary -sign $privateKey metainfo2.txt |xxd -c 16 -p)
do
echo "signature$(($ix+1)) = \"$lin\"" >> $tmpFile
ix=$(($ix+1))
done
echo "Output: $2"

