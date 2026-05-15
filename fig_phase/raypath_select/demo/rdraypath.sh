#!/bin/sh
#####
#    The purpose of the Script is to  prepare the raypath information for gmt plot
#####
#    Author:Chen Haopeng,PHD of SGG,Wuhan Univeristy,China
#    Email: chp@whu.edu.cn
#    Creatied time     : 2013.05.02 11:44
#    Last Modified time: 2013.05.02 11:44
#####
rm *.eps *.ps

read period label< label.dat

rm raypath.txt

cat disp.c1.txt | gawk 'NR>1{print $1,$2,$3,$4}' >disp.c2.txt

while read  stlo stla evlo evla
do
   echo ">" >>raypath.txt
   echo " $stlo $stla" >>raypath.txt
   echo " $evlo $evla" >>raypath.txt
done < disp.c2.txt

rm disp.c2.txt

bash coast.sh $period $label


