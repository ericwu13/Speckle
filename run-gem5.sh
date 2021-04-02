#!/bin/bash

TARGET_RUN="/tools/B/tywu13/gem5/build/X86/gem5.opt"
GEM5_CONFIG="/tools/B/tywu13/gem5/configs/example/se.py"
GEM5_OPTIONS="--l1d_size=64kB --l1i_size=16kB --caches"

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
    BENCHMARKS=(600.perlbench 602.gcc)
    # 605.mcf 620.omnetpp 623.xalancbmk 625.x264 631.deepsjeng 641.leela 648.exchange2 657.xz)
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
   rm -rf ${base_dir}/output/${b}
   mkdir -p ${base_dir}/output/${b}
   echo " -== Dumping ${b} stats in ${base_dir}/output/${b}  ==-"
    
   # go to the directory where the exectuabl&inputs reside
   echo "cd ${overlay_dir}/$suite_type/${b}${suffix}/${INPUT_TYPE}"
   cd ${overlay_dir}/$suite_type/${b}${suffix}/${INPUT_TYE}
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
       cmd="${TARGET_RUN} --outdir=${base_dir}/output/${b} $GEM5_CONFIG -c ${SHORT_EXE}_base.mytest-m64 --options=\"${input}\" $GEM5_OPTIONS"
       echo "workload=[${cmd}]"
       eval ${cmd}
       # ((count++)) 
   fi
   # done
   echo ""

done


echo ""
echo "Done!"
