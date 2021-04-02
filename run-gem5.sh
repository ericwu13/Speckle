#!/bin/bash

TARGET_RUN="/tools/B/tywu13/gem5/build/ARM/gem5.opt"
GEM5_CONFIG="/tools/B/tywu13/gem5/configs/example/se.py"
GEM5_OPTIONS="--l1d_size=64kB --l1i_size=16kB --caches"

INPUT_TYPE=test # THIS MUST BE ON LINE 4 for an external sed command to work!
                # this allows us to externally set the INPUT_TYPE this script will execute
LABEL=arm # given the cfg file's label
if [[ $LABEL == "arm" ]]; then
   label_suffix="64"
else
   label_suffix="m64"
fi

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
    #BENCHMARKS=(600.perlbench 602.gcc)
    BENCHMARKS=(605.mcf 620.omnetpp 623.xalancbmk 625.x264 631.deepsjeng 641.leela 648.exchange2 657.xz)
elif [[ $suite_type == "intrate" ]]; then
    BENCHMARKS=()
else
    BENCHMARKS=()
fi

base_dir=$PWD

# Directory where the benchmarks reside
overlay_dir=$PWD/build/overlay

for b in ${BENCHMARKS[@]}; do
   # specify the directory that gem5 will dump the stats
   OUT_DIR=${base_dir}/output/${b}/${LABEL}/${INPUT_TYPE}
   mkdir -p ${OUT_DIR}
   echo " -== Dumping ${b} stats in ${OUT_DIR} ==-"

    
   # go to the directory where the exectuabl&inputs reside
   BIN_DIR=${overlay_dir}/$suite_type/${b}${suffix}/${LABEL}/${INPUT_TYPE}
   echo "cd ${BIN_DIR}"
   cd ${BIN_DIR}
   SHORT_EXE=${b##*.}$suffix # cut off the numbers ###.short_exe
   if [ $b == "602.gcc" ]; then 
      SHORT_EXE=sgcc #WTF SPEC???
   fi
   
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
       cmd="${TARGET_RUN} --outdir=${OUT_DIR} $GEM5_CONFIG -c ${SHORT_EXE}_base.${LABEL}-${label_suffix} --options=\"${input}\" $GEM5_OPTIONS"
       echo "workload=[${cmd}]"
       eval ${cmd}
       # ((count++)) 
   fi
   # done
   echo ""

done


echo ""
echo "Done!"
