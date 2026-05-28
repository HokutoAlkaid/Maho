#!/bin/sh
set -x
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
rm -rf *km
velfile="joint_density_iter.dat"
rm -f *.dat
rm -f "$velfile"
if [ ! -f "../$velfile" ]; then
  echo "Error: missing density model ../$velfile" >&2
  exit 1
fi
cp ../$velfile .

depth_list="002 004 006 008 010 015 020 025 030 035 040 045 050 055"

read scale_min scale_max <<EOF
$(awk '
  NR == 1 { min = $4; max = $4 }
  $4 < min { min = $4 }
  $4 > max { max = $4 }
  END {
    min = int(min * 100) / 100
    max = int(max * 100 + 0.999999) / 100
    if (min == max) {
      min -= 0.01
      max += 0.01
    }
    printf "%.2f %.2f\n", min, max
  }
' "$velfile")
EOF

for i in $depth_list
do
  rm -f vel.dat
  awk '{if($3==depth1) print $1,$2,$4}' depth1=$i $velfile > vel.dat
  cp -r demo ${i}km
  mv vel.dat ${i}km/vel.dat
  cd ${i}km
  #--
  #  create the depth file
  #--
  echo ${i}km >depth.dat

  echo "$scale_min $scale_max" > scale.dat

  bash scale.sh
  cd ..
done

echo "grav_density_abs_80.0_0.1" > plot_name.dat
bash copyfig.sh

#rm -r *km
