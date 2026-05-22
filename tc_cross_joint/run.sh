set -x

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

timefile="runtime.txt"
logdir="logs"
mkdir -p "$logdir"
rm -f "$timefile"

terminal_log="$logdir/terminal_output.log"
exec > >(tee -a "$terminal_log") 2>&1

start=`date`
DATE1=`date +%s%N|cut -c1-13`

# create initial velocity model
cd surf_inv_direct
  bash run.sh > ../$logdir/surf_inv_direct.log 2>&1
  cd results
    python3 out2init.py mod_iter10.dat MOD
    cp MOD ../../surf_inv
  cd ..
cd ..

# pass the initial Vs model directly into JointSG so the gravity branch
# follows the official JDSurfG parameterization (JointSG converts Vs to
# density internally when computing gravity).
cp surf_inv_direct/results/mod_iter10.dat \
   gravity_inv/initial/joint_mod_iter.dat

cd surf_inv
  rm -f info*
cd ..

cd gravity_inv
  rm -f info*
cd ..

echo "Pre-calculating Gravity Matrix..."
cd gravity_inv
  if [ ! -f MOD ]; then
      cd initial && bash bash.sh > ../../$logdir/gravity_initial.log 2>&1 && cd ..
  fi

  mkmat DSurfTomo.in obsgrav.dat MOD > info_mkmat.txt 2> ../$logdir/mkmat.log

  if [ -f gravmat.dat ]; then
      echo "Gravity Matrix generated successfully."
  else
      echo "Error: gravmat.dat failed to generate."
      exit 1
  fi
cd ..

for i in {1..10}
  do
  echo "===== Joint iteration $i / 10 ====="

  cd surf_inv
    bash run.sh > ../$logdir/surf_iter${i}.log 2>&1
    cp info_surf.txt info_surf${i}.txt
    rm -f info_surf.txt
    cd results
      bash bash.sh
      cp delta_ms0.dat ../../data
      cp mod_iter1.dat ../../data
      cp mod_iter0.dat ../../data/mod_iter0.dat
    cd ..
  cd ..

  cd gravity_inv
    bash run.sh > ../$logdir/gravity_iter${i}.log 2>&1
    cp info_joint.txt info_joint${i}.txt
    cd results
      bash bash.sh
      cp delta_mg0.dat ../../data
      cp joint_mod_iter1.dat ../../data
      cp joint_mod_iter0.dat ../../data/joint_mod_iter0.dat
    cd ..
  cd ..

  python3 crossgradient_inversion.py

  cd results
    python3 out2init.py mod_iter.dat MOD
    cp MOD ../surf_inv
    cp joint_mod_iter.dat ../gravity_inv/initial/joint_mod_iter.dat
  cd ..
done

cd results/surf
  bash bash.sh > ../../$logdir/results_surf.log 2>&1
cd ../gravity
  bash bash.sh > ../../$logdir/results_gravity.log 2>&1
cd ../gmt_slice_ref
  bash bash.sh > ../../$logdir/gmt_slice_ref.log 2>&1
cd ../..

end=`date`
DATE2=`date +%s%N|cut -c1-13`

echo start time > "$timefile"
echo "$start" >> "$timefile"
echo end time >> "$timefile"
echo "$end" >> "$timefile"
echo "Running time:: $(($((${DATE2}-${DATE1}))/60000)) min" >> "$timefile"
echo "terminal log:: $terminal_log" >> "$timefile"
echo "surf direct log:: $logdir/surf_inv_direct.log" >> "$timefile"
echo "gravity init log:: $logdir/gravity_initial.log" >> "$timefile"
echo "mkmat log:: $logdir/mkmat.log" >> "$timefile"
echo "results surf log:: $logdir/results_surf.log" >> "$timefile"
echo "results gravity log:: $logdir/results_gravity.log" >> "$timefile"
echo "gmt slice log:: $logdir/gmt_slice_ref.log" >> "$timefile"

echo "Collecting key results..."
bash "$ROOT_DIR/collect_key_results.sh" | tee -a "$timefile"
