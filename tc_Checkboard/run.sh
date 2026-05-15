set -x

start=`date`
DATE1=`date +%s%N|cut -c1-13`
timefile="runtime.txt"
logdir="logs"
rm -f $timefile
mkdir -p $logdir

#---
#   Firstly, We create the initial model
#---
cd check1
   bash bash.sh > ../$logdir/check1_build.log 2>&1
   #bash bash.sh
cd ..

#---
#   Secondly, We perform the inversion with only surface wave data
#---

cd surf_inv_direct
   bash run_cb.sh > ../$logdir/surf_inv_direct.log 2>&1
   cd results
    python3 out2init.py mod_iter10.dat MOD
    cp MOD ../../surf_inv
   cd ..
cd ..

#使用经验公式将速度模型转化为初始密度模型
python3 veltodensi.py \
    surf_inv_direct/results/mod_iter10.dat \
    gravity_inv/initial/joint_mod_iter.dat
############
echo "Pre-calculating Gravity Matrix..."
cd gravity_inv
  if [ ! -f MOD ]; then
      cd initial && bash bash.sh > ../../$logdir/gravity_initial.log 2>&1 && cd ..
  fi
  
  # 运行一次 mkmat，生成 gravmat.dat
  mkmat DSurfTomo.in obsgrav.dat MOD > info_mkmat.txt 2> ../$logdir/mkmat.log
  
  if [ -f gravmat.dat ]; then
      echo "Gravity Matrix generated successfully."
  else
      echo "Error: gravmat.dat failed to generate."
      exit 1
  fi
cd ..
###########
#---
#   Thirdly, We perform the cross joint inversion code
#---
for i in {1..10}
  do
  echo "===== Joint iteration $i / 10 ====="
  # direct surf inversion
  cd surf_inv
    bash run_cb.sh > ../$logdir/surf_iter${i}.log 2>&1
    cp info_surf.txt info_surf${i}.txt
    rm -f info_surf.txt
    cd results 
     bash bash.sh
     cp delta_ms0.dat ../../data
     cp mod_iter1.dat ../../data
     cp mod_iter0.dat ../../data/mod_iter0.dat    # 将旧模型 (mod_iter0.dat) 复制到数据交换区
    cd ..
  cd ..

  # direct gravity inversion
  cd gravity_inv
    bash run_cb.sh > ../$logdir/gravity_iter${i}.log 2>&1
    cp info_joint.txt info_joint${i}.txt
    cd results 
      bash bash.sh
      cp delta_mg0.dat ../../data
      cp joint_mod_iter1.dat ../../data
      cp joint_mod_iter0.dat ../../data/joint_mod_iter0.dat  #    # 将旧模型复制到数据交换区
    cd ../
  cd ../

  # cross-gradient inversion
  python3 crossgradient_inversion.py

  #trans mod_iter into MOD
  cd results
    python3 out2init.py mod_iter.dat MOD
    cp MOD ../surf_inv
    cp joint_mod_iter.dat ../gravity_inv/initial/joint_mod_iter.dat
  cd ../
  
done
###########

#plot results
cd results/gmt_vel_joint
  bash bash.sh > ../../$logdir/gmt_vel_joint.log 2>&1
cd ..

end=`date`
DATE2=`date +%s%N|cut -c1-13`

echo start time > $timefile
echo $start >> $timefile
echo end time >>$timefile
echo $end   >>$timefile
echo "Running time:: $(($((${DATE2}-${DATE1}))/60000)) min" >>$timefile
echo "check1 log:: $logdir/check1_build.log" >>$timefile
echo "plot log:: $logdir/gmt_vel_joint.log" >>$timefile
