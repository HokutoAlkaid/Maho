#!/bin/bash
#----
#rm -r allfig
mkdir -p allfig/jpg allfig/eps
rm -f allfig/jpg/*.jpg allfig/eps/*.eps
for i in *km
do
   [ -d "$i" ] || continue
   for fig in "$i"/*.jpg; do
      [ -f "$fig" ] && cp "$fig" allfig/jpg
   done
   for fig in "$i"/*.eps; do
      [ -f "$fig" ] && cp "$fig" allfig/eps
   done
done

cd allfig 
bash all.sh
