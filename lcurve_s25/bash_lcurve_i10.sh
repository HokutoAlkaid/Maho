#!/bin/sh
#---
#   run the lcurve code
#   written by Haopeng Chen, 2021.01.31
#---
path1=/home/chp/sda2/YNjointinv/gmt202310/L_curve/lcurve_s25
path2=/home/chp/sda2/YNjointinv/gmt202310/L_curve
rm lcurveall_nonm.txt
rm -r lcurve
iter="10"
cp -r lcurve_i${iter} lcurve
#echo "dirname  res_s  res_g  resall  lm  mrough">lcurveall.txt
echo "dirname  res_s  res_g  resall  lm  mrough">lcurveall.txt
cd $path2
for file in fninv_s25_3d
do
  cd $file
     for dir in inv_*
     do
        rm -r $dir/lcurve
        cp -r $path1/lcurve $dir
        cd $dir/lcurve
           bash run_lcurve.sh
           lcurve=`tail -n 1 lcurve.txt`
           echo "$file/$dir $lcurve" >> $path1/lcurveall.txt
           echo "$dir  $lcurve" >> $path1/lcurveall_nonm.txt
        cd ../../
        rm -r $dir/lcurve
     done
  cd ..
done

cd $path1

sed -i 's/_/ /g' lcurveall_nonm.txt
#cat lcurveall_nonm.txt | gawk '{printf "%6.1f %6.1f %10.3f %10.3f %10.3f %10.3f %10.3f %10.3f\n", $2,$3,$4,$5,$6,$7,$8,$9}' > 1.txt
cat lcurveall_nonm.txt | gawk '{printf "%10.1f %10.1f %12.3f %12.3f %12.3f %10.3f %10.3f\n", $2,0.01,$3,$4,$5,$6,$7}' > 1.txt
cat 1.txt | sort -n -k1 -k2 > 2.txt
#mv 1.txt lcurveall_nonm.txt
mv 2.txt lcurveall_nonm.txt
rm lcurveall.txt 1.txt
rm -r lcurve
mv lcurveall_nonm.txt lcurveall_i${iter}.txt



