#!/bin/sh
set -x
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SURF_RESULTS_DIR="$SCRIPT_DIR/../surf"
rm -r *km
velfile="joint_mod_iter.dat"
rm *.dat
rm $velfile
cp ../$velfile .

for i in 002 004 006 008 010 015 020 025 030 035 040 
do
  rm vel.dat
  awk '{if($3==depth1) print $1,$2,$4}' depth1=$i $velfile > vel.dat
  cp -r demo ${i}km
  mv vel.dat ${i}km/vel.dat
  cd ${i}km
  #--
  #  create the depth file
  #--
  echo ${i}km >depth.dat

  if [ ! -f "$SURF_RESULTS_DIR/${i}km/scale.dat" ]; then
    echo "Error: missing surface-wave color scale at $SURF_RESULTS_DIR/${i}km/scale.dat" >&2
    exit 1
  fi

  cp "$SURF_RESULTS_DIR/${i}km/scale.dat" .

  bash scale.sh
  cd ..
done

bash copyfig.sh

#rm -r *km
