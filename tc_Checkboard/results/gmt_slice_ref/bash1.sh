#!/bin/sh

#----
#    The purpose of this program is to simultaneously run the program
#    Author        :: Haopeng Chen
#    Email         :: chp@whu.edu.cn
#    Creatied time :: 2015.03.29 10:10
#    Modified time :: 2015.03.29 10:10
#----
set -x
#rm -r allfig
#mkdir allfig
velfile="mod_iter.dat"
fixed_lscale="-0.3"
fixed_hscale="0.3"
rm *.dat
rm $velfile
cp ../$velfile .
n=0
for i in 24.75 25.25
do
  rm vel.dat
  #awk '{if($3==depth1) print $1,$2,$4}' depth1=$i $velfile > vel.dat
  awk '{if($2==lat1) print $1,$3,$4}' lat1=$i $velfile > vel.dat
  
  # Remove the 1-D reference trend so the section shows the checkerboard anomaly.
  awk '{print $1,$2,$3-(2.5+0.02*$2)}' vel.dat > veln.dat
  mv veln.dat vel.dat
  
  n=$(($n+1))
  rm -r ${i}_sli
  cp -r demo1 ${i}_sli
  mv vel.dat ${i}_sli/vel.dat
  label=`head -n $n label.txt | tail -n 1 | awk '{ print $1 }'`
  cd ${i}_sli
     echo $i $label >depth.dat
     #---
     #   Use a common anomaly color range for all sections.
     #---
     printf "%10.1f%10.1f\n" $fixed_lscale $fixed_hscale > scale.dat
     bash scale2.sh
  cd ..
done

#cd allfig
#   bash bash.sh
#cd ..
