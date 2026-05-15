#!/bin/sh
#####
#    The purpose of the Script is to plot the ray paths of Huabei Region
#####
#    Author:Chen Haopeng,PHD of SGG,Wuhan Univeristy,China
#    Email: chp@whu.edu.cn
#    Creatied time     : 2012.06.04 10:50
#    Last Modified time: 2013.04.08 21:12
#####
gmtset PLOT_DEGREE_FORMAT ddd
gmtset GRID_PEN_PRIMARY 0.5p,255
#####
#    Define the default name of the PostScript output
#####
FNAME="scsea.ps"

rm *.ps *.eps *.tif *.jpg

period=$1
label=$2

#####
#    Define the file name of the raypath file
#####
raypathfile="raypath.txt"

#####
#    Define map bounds: MINLON/MAXLON/MINLAT/MAXLAT 
#####
LATLON="96/117/7/26"
#####
#    Define Mercator projection: Center lon,la, Plot_Width   
#####
PROJ="M118.0/5/5i"

#####
#    Define Coastline resolution: one of fhilc 
#    (f)ull, (h)igh, (i)ntermediate, (l)ow, and (c)rude)
#  . The resolution drops off by 80% between data sets.
#####
RESCOAST="h"

#####
#    Define boundaries for pscoast 
#    1 = National boundaries 
#    2 = State boundaries within the Americas 
#    3 = Marine boundaries 
#    a = All boundaries (1-3) pscoast 
#####
BDRYS="3"

#####
#    Sets map boundary annotation and tickmark intervals
#    2 is the latitude interval, and f represents the minor tick spacing(1)
#    1 is the longitude tick space. 
#    for small region, "m" reprsents arc minute and "c" represent arc second
#####
TICS="5/5"


#####
#    Set DEM data
#    The DEM is GTOP, which is sepreated into 33 regions
#    grdraster: extract subregion from a binary raster and write a grid file
#               -I option, set grid spacing. m is arc minite 
#    grd2cpt  : Make a color palette table from grid files.
#               -C option.Specify a colortable [Default is rainbow]
#                  topo-Sandwell/Anderson colors for topography[-7000/+7000]
#               -S -Szstart/zstop/zinc
#               -Z Will create a continuous color palette
#####



#pscoast  -J${PROJ} -R${LATLON} -B${TICS} -W1  -A500 -Df -K -P  > ${FNAME}

#####
#    Map the coast
#    definations of some options:
#    -G Select filling or clipping of "dry" areas, here -G200 is grey.  
#    -W Draw shorelines [Default is no shorelines].When is used,
#       [Defaults: width = 0.25p, color = black, texture = solid]
#       GMT length unit c, i, m, p(cm, inch, m, and point)
#    -P Selects Portrait plotting mode [Default is Landscape]
#    -K More PostScript code will be appended later [Default terminates
#       the plot system].
#####
pscoast -J${PROJ} -R${LATLON} -B${TICS} -D${RESCOAST} -N${BDRYS} -G200 -W1 -A1000 -P -K  > ${FNAME}

#####
#    Map great circle ray paths
#    definations of some options:
#    -O Selects Overlay plot mode [Default initializes a new plot system].
#    -W Set pen attributes for lines or the outline of symbols [Defaults: 
#       width = 0.25p, color = black, texture = solid]
#    -m Multiple segment file. Segments are separated by a record whose 
#       first character is flag [Default is ¡¯>¡¯]
#    -K More PostScript code will be appended later [Default terminates
#       the plot system].
#    -V Selects verbose mode, which will send progress reports to stderr 
#       [Default runs "silently"]. Not necessary
#    By default line segments are drawn as greth circle arcs.To draw them 
#    as sgtraight lines,use the -A flag.
#####
psxy $raypathfile -J${PROJ} -R${LATLON} -W1.0p -m -O -K -V >> ${FNAME}

#psxy psclip.txt -J${PROJ} -R${LATLON}  -L -W2.0p,0/0/255 -O -K -V >> ${FNAME}
#psxy psclip.txt -J${PROJ} -R${LATLON}  -L -W2.0p,white -O -K -V >> ${FNAME}
echo 98.0 11.0 18 0 0 CM $period| pstext -J${PROJ} -R${LATLON}  -O -P -K -V >> ${FNAME}
#echo 98.0 24.5 22 0 0 CM "$label"| pstext -J${PROJ} -R${LATLON}  -O -P -V  >> ${FNAME}

#####
#     plot the stations
#####
stlalo="scsallstationfn_select.txt"
gawk '{print $2, $1}' $stlalo | psxy -J${PROJ} -R${LATLON} -St0.20i  -Gred -O  -V >>${FNAME}

#path="tectonic"
#psxy $path/citylalon.txt -J${PROJ} -R${LATLON} -Skstar/0.12i  -G255/0/0 -O  -K -V >>${FNAME}
#pstext $path/cityname.txt -J${PROJ} -R${LATLON}  -G255/0/0 -Y0.15 -O -P -V  >> ${FNAME}


cp ${FNAME} $period.ps
ps2raster -A -P -Te $period.ps
ps2raster -A -P -Tj $period.ps
rm  ${FNAME} 
rm *.ps

