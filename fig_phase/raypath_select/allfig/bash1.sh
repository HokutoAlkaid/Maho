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
psfile1="Fig1_path_joint1.ps"
psfile2="Fig1_path_joint2.ps"
psfile3="Fig1_path_joint3.ps"
psfile4="Fig1_path_joint4.ps"

rm *.eps *.ps *.jpg *.tif

for i in 005s 006s 007s 008s 009s 010s 011s 012s 015s 020s 030s 040s 048s 050s 060s 
do
   cp ../$i/$i.eps .
done

for i in 005s 006s 007s 008s 009s 010s 011s 012s 015s 020s 030s 040s 048s 050s 060s 
do
   cp ../$i/$i.jpg .
done

psimage 0040s.eps -W7c -C0/0c/BL -K > ${psfile1}
psimage 0060s.eps -W7c -C7.2c/0c/BL -O -K >> ${psfile1}
psimage 0010s.eps -W7c -C0/6.2c/BL -O -K >> ${psfile1}
psimage 0020s.eps -W7c -C7.2c/6.2c/BL -O  >> ${psfile1}

psimage 011s.eps -W7c -C0/0c/BL -K > ${psfile2}
psimage 012s.eps -W7c -C7.2c/0c/BL -O -K >> ${psfile2}
psimage 009s.eps -W7c -C0/6.2c/BL -O -K >> ${psfile2}
psimage 010s.eps -W7c -C7.2c/6.2c/BL -O  >> ${psfile2}

psimage 030s.eps -W7c -C0/0c/BL -K > ${psfile3}
psimage 040s.eps -W7c -C7.2c/0c/BL -O -K >> ${psfile3}
psimage 015s.eps -W7c -C0/6.2c/BL -O -K >> ${psfile3}
psimage 020s.eps -W7c -C7.2c/6.2c/BL -O  >> ${psfile3}

psimage 048s.eps -W7c -C0/0c/BL -K > ${psfile4}
psimage 050s.eps -W7c -C7.2c/0c/BL -O -K >> ${psfile4}
psimage 060s.eps -W7c -C0/6.2c/BL -O >> ${psfile4}

ps2raster -A -P -Tj ${psfile1}
ps2raster -A -P -Tj ${psfile2}
ps2raster -A -P -Tj ${psfile3}
ps2raster -A -P -Tj ${psfile4}

#ps2raster -A -P -Tt ${psfile}
#ps2raster -A -P -E400 -Tt ${psfile}
rm *.eps

