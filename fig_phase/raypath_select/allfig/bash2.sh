# The purpos of this program is to merge all the eps figures
# Author: Haopeng Chen
# Creatied time: 2013.11.06 19:00
set -x

#####
#    psimage merge the eps file
#      -Wwidth/height
#      -Cx0/y0 define the loction of the figure
#    ps2raster convert ps file to other formats
#####
psfile1="Fig1_path_jointall.ps"

#rm *.eps *.ps *.jpg *.tif

for i in 012s 015s 020s 030s 040s 050s 060s 080s 048s 
do
   cp ../$i/$i.eps .
done
 
psimage 040s.eps -W7c -C0/0c/BL -K > ${psfile1}
psimage 048s.eps -W7c -C7.2c/0c/BL -O -K >> ${psfile1}
psimage 020s.eps -W7c -C0/6.2c/BL -O -K >> ${psfile1}
psimage 030s.eps -W7c -C7.2c/6.2c/BL -O -K  >> ${psfile1}
psimage 012s.eps -W7c -C0/12.4c/BL -O -K >> ${psfile1}
psimage 015s.eps -W7c -C7.2c/12.4c/BL -O  >> ${psfile1}

#ps2raster -A -P -Te ${psfile}
ps2raster -A -P -Tj ${psfile1}
rm *.eps
rm *.ps

