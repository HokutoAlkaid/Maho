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
  {
    sum[$3] += $4
    count[$3] += 1
    value[NR] = $4
    depth[NR] = $3
  }
  END {
    maxabs = 0
    for (i = 1; i <= NR; i++) {
      anom = value[i] - sum[depth[i]] / count[depth[i]]
      if (anom < 0) {
        anom = -anom
      }
      if (anom > maxabs) {
        maxabs = anom
      }
    }
    maxabs = int(maxabs * 100 + 0.999999) / 100
    if (maxabs < 0.01) {
      maxabs = 0.01
    }
    printf "%.2f %.2f\n", -maxabs, maxabs
  }
' "$velfile")
EOF

for i in $depth_list
do
  rm -f vel.dat
  awk '
    $3 == depth1 {
      sum += $4
      count += 1
      line[count] = $1 " " $2 " " $4
    }
    END {
      if (count == 0) {
        exit 1
      }
      mean = sum / count
      for (j = 1; j <= count; j++) {
        split(line[j], item, " ")
        print item[1], item[2], item[3] - mean
      }
    }
  ' depth1=$i $velfile > vel.dat
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

echo "grav_density_anom_80.0_0.1" > plot_name.dat
bash copyfig.sh

#rm -r *km
