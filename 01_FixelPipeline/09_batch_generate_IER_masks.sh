#!/bin/bash
module load mrtrix
# Specify the directory containing the folders
parent_dir="/nfs/corenfs/psych-mercury-data/Data/DTI/Fixel_analysis/subjects"

cd $parent_dir

#cd ../template
#### To create a spherical ROI:

warpinit MNI152_T1_1mm_Brain.mif pos-[].mif
## Create images of coordinates 

#mredit -sphere -19 -34 59 6 pos.mif
    
# Set location and radius of sphere (using BASH variables)

# inter-effectors (M1) MNI space
xsl=-19 ysl=-34 zsl=59 rsl=60  # Superior L | radius 6mm   
xsr=20 ysr=-31 zsr=58 rsr=6  # Superior R | radius 6 mm 
xml=-38 yml=-18 zml=44 rml=6  # Middle   L | radius 6 mm   
xmr=40 ymr=-15 zmr=43 rmr=6  # Middle   R | radius 6 mm  
xil=-54 yil=-3  zil=14 ril=6  # Inferior L | radius 6 mm  
xir=56 yir=-1  zir=16 rir=6  # Inferior R | radius 6 mm 

#Compute ROI using [mrcalc](note stack-based syntax – not pretty, but very effective)

mrcalc pos-0.mif $xsl -sub 2 -pow pos-1.mif $ysl -sub 2 -pow pos-2.mif $zsl -sub 2 -pow -add -add $rsl 2 -pow -lt roi_sl.mif

mrcalc pos-0.mif $xsr -sub 2 -pow pos-1.mif $ysr -sub 2 -pow pos-2.mif $zsr -sub 2 -pow -add -add $rsr 2 -pow -lt roi_sr.mif

mrcalc pos-0.mif $xml -sub 2 -pow pos-1.mif $yml -sub 2 -pow pos-2.mif $zml -sub 2 -pow -add -add $rml 2 -pow -lt roi_ml.mif

mrcalc pos-0.mif $xmr -sub 2 -pow pos-1.mif $ymr -sub 2 -pow pos-2.mif $zmr -sub 2 -pow -add -add $rmr 2 -pow -lt roi_mr.mif

mrcalc pos-0.mif $xil -sub 2 -pow pos-1.mif $yil -sub 2 -pow pos-2.mif $zil -sub 2 -pow -add -add $ril 2 -pow -lt roi_il.mif

mrcalc pos-0.mif $xir -sub 2 -pow pos-1.mif $yir -sub 2 -pow pos-2.mif $zir -sub 2 -pow -add -add $rir 2 -pow -lt roi_ir.mif



