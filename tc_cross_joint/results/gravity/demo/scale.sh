#!/bin/sh
set -x
#####
#    The purpose of the Script is to copy the data for gmt plot
#####
#    Author:Chen Haopeng,PHD of SGG,Wuhan Univeristy,China
#    Email: chp@whu.edu.cn
#    Creatied time     : 2013.06.17 19:11
#    Last Modified time: 2013.08.17 11:11
#    Modified time :: 2020.02.01 20:56
#    Modification  ::
#     (1) we donot use the scale.f90 program anymore.
#####
read depth < depth.dat
read lscalev hscalev < scale.dat
rm -f *.ps *eps *.jpg
rm -f depth.dat 
bash tomo_v6.sh $depth
