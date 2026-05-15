#!/bin/sh

#----
#    The purpose of this program is to simultaneously run the program
#    Author        :: Haopeng Chen
#    Email         :: chp@whu.edu.cn
#    Creatied time :: 2015.03.29 10:10
#    Modified time :: 2015.03.29 10:10
#----
set -x
rm -r *s
n=0
dir="../phase_select"
for i in 005s 007s 006s 008s 009s 012s 015s 020s 030s 040s 050s 060s 048s 010s 011s
do
  n=$(($n+1))
  cp -r demo $i
  cp $dir/disp$i.c1.txt $i/disp.c1.txt
  label=`head -n $n label.txt | tail -n 1 | awk '{ print $1 }'`
  cd $i
  echo $i $label >label.dat
  bash rdraypath.sh
  cd ..
done

cd allfig
   bash bash1.sh
   bash bash2.sh
cd ..
