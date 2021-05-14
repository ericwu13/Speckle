#!/bin/bash

LABEL=arm  # given the cfg file's label
CACHES=skewed_ref

if [[ $LABEL == "arm" ]]; then
   TARGET_RUN="/tools/B/tywu13/gem5/build/ARM/gem5.opt"
   label_suffix="64"
else
   TARGET_RUN="/tools/B/tywu13/gem5/build/X86/gem5.opt"
   label_suffix="m64"
fi

GEM5_CONFIG="/tools/B/tywu13/gem5/configs/example/se.py"
GEM5_OPTIONS="--l1d_size=32kB --l1d_assoc=8 --l1i_size=32kB --l1i_assoc=8 --caches --mem-size=8192MB --tags=skewedassoc"

INPUT_TYPE=ref # THIS MUST BE ON LINE 4 for an external sed command to work!
                # this allows us to externally set the INPUT_TYPE this script will execute

suite_type=intspeed
if [[ $suite_type == *"speed"* ]]; then
   prefix="6"
   class="speed"
   suffix="_s"
   type=${suite_type/%speed/}
   echo type
else
   prefix="5"
   class="rate"
   suffix="_r"
fi

if [[ $suite_type == "intspeed" ]]; then
    BENCHMARKS=(600.perlbench 602.gcc 605.mcf 623.xalancbmk 625.x264 631.deepsjeng 641.leela 657.xz)
elif [[ $suite_type == "intrate" ]]; then
    BENCHMARKS=(500.perlbench 502.gcc 505.mcf 523.xalancbmk 525.x264 531.deepsjeng 541.leela 557.xz)
elif [[ $suite_type == "fpspeed" ]]; then
    BENCHMARKS=(607.cactuBSSN 619.lbm 621.wrf 627.cam4 628.pop2 638.imagick 644.nab 649.fotonik3d 654.roms)
    # BENCHMARKS=(607.cactuBSSN 619.lbm 621.wrf 627.cam4 628.pop2 638.imagick 644.nab 649.fotonik3d 654.roms)
    # BENCHMARKS=(621.wrf 627.cam4)
else
    BENCHMARKS=(507.cactuBSSN 508.namd 510.parest 511.povray 519.lbm 521.wrf 526.blender 527.cam4 538.imagick 544.nab 549.fotonik3d 554.roms)
    # BENCHMARKS=(511.povray 521.wrf 526.blender)
fi

base_dir=$PWD

# Directory where the benchmarks reside
overlay_dir=$PWD/build/overlay

for b in ${BENCHMARKS[@]}; do
   # specify the directory that gem5 will dump the stats
   OUT_DIR=${base_dir}/output/${b}/${LABEL}_${CACHES}/${INPUT_TYPE}
   mkdir -p ${OUT_DIR}
   echo " -== Dumping ${b} stats in ${OUT_DIR} ==-"

    
   # go to the directory where the exectuabl&inputs reside
   BIN_DIR=${overlay_dir}/$suite_type/${b}${suffix}/${LABEL}/${INPUT_TYPE}
   echo "cd ${BIN_DIR}"
   cd ${BIN_DIR}
   # SHORT_EXE=${b##*.}$suffix # cut off the numbers ###.short_exe
   # if [ $b == "*gcc" ]; then 
      # SHORT_EXE=sgcc #WTF SPEC???
   # fi
   BIN=`find ${BIN_DIR} -name "*${suffix}*${LABEL}-${label_suffix}"`

   
   # read the command file
   IFS=$'\n' read -d '' -r -a commands < ${base_dir}/commands/${suite_type}/${b}${suffix}.${INPUT_TYPE}.cmd

   # run each workload
   count=0
   # for input in "${commands[@]}"; do
   input=${commands[0]}
   read -ra input <<< "$input"
   input=${input[@]::${#input[@]}-4}
   # echo $input
   if [[ ${input:0:1} != '#' ]]; then # allow us to comment out lines in the cmd files
       # cmd="${TARGET_RUN} --outdir=${OUT_DIR} $GEM5_CONFIG -c ${SHORT_EXE}_base.${LABEL}-${label_suffix} --options=\"${input}\" $GEM5_OPTIONS"
       cmd="${TARGET_RUN} --outdir=${OUT_DIR} $GEM5_CONFIG -c ${BIN} --options=\"${input}\" $GEM5_OPTIONS"
       echo "workload=[${cmd}]"
       eval ${cmd}
       # ((count++)) 
   fi
   # done
   echo ""

done


echo ""
echo "Done!"
