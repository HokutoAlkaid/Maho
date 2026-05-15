#---
# This program is used compile the code to calculate L-curve
# Author:: This script is written by Haopeng Chen from HUST.
# lcurve.cpp is written by Nanqiao Du form CAS and then modified by Haopeng Chen
# Modified for the new code, modified tiem 2023.10.29
#---
#   note that you need to modify the lmcal.cpp code for your study area
#   int main()
#{
#    int nx = 20,ny=22,nz=20;
#    int n = (nx-2) * (ny-2) * (nz - 1);
#---
#---
#set -x 
#---
#   step 1
#   compile the code
#---
cd src
   bash compile.sh
cd ..

#---
#   step 2
#   calculate the model difference of final model and initial model,
#   and model roughness ||m||^2, the input file is mod0.dat, mod1.dat
#   The output file is "mod2.dat" and rough.txt
#---
rm mod0.dat mod1.dat
cp ../results/joint_mod_iter0.dat mod0.dat
cp ../results/joint_mod_iter10.dat mod1.dat
python mrough.py

#---
#   step 3
#   calculate the ||Lm||^2 of both mod_iter10.dat and the model difference
#   the mod2.dat. The latter is correct. 
#   The output file is lm.txt
#---
rm lm.txt
cp mod2.dat mod_iter.dat
./bin/lmcal

rm mod_iter.dat

#---
#   step 4
#   calculate the data residual. I think we should use ||Ws*Rs||^2+||Wg*Rg||^2
#   rather than ||Rs||^2+||Rg||^2
#   format of ref_surf10.dat : dist, obs_traveltime, theory_traveltime
#   format of ref_grav10.dat : obs_gravity theory_gravity
#---
rm JointSG.in res_surf.dat res_grav.dat
cp ../JointSG.in .
cp ../results/res_surf10.dat res_surf.dat
cp ../results/res_grav10.dat res_grav.dat

cat res_surf.dat | gawk '{print $1,$2,$3}' >1.dat
mv 1.dat res_surf.dat

#--
#  sigmat and sigmag are the error of surface wave and gravity data
#  wts is the weight of surface wave data.
#  ns and ng are number of surface wave data and gravity data.
#--
sigmat=`tail -n 4 JointSG.in | head -n 1 | gawk '{print $1}'`
sigmag=`tail -n 4 JointSG.in | head -n 1 | gawk '{print $2}'`
wts=`tail -n 5 JointSG.in | head -n 1 | gawk '{print $1}'`
ns=`cat res_surf.dat | wc -l`
ng=`cat res_grav.dat | wc -l`
echo "$wts $sigmat $sigmag $ns $ng" > para.txt
cat para.txt
python residual.py
#rm para.txt

read lm < lm.txt
read mrough < mrough.txt
read res_s res_g resall < resi.txt
#rm resi.txt mrough.txt

echo "res_s  res_g  resall  lm  mrough" > lcurve.txt
echo "res_s  res_g  resall  lm  mrough"
echo "$res_s $res_g $resall $lm $mrough" >> lcurve.txt
echo "$res_s $res_g $resall $lm $mrough"


