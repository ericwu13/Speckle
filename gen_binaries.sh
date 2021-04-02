#!/bin/bash
#set -e

#############
# TODO
#  * auto-handle output file generation

if [ -z  "$SPEC_DIR" ]; then
   echo "  Please set the SPEC_DIR environment variable to point to your copy of SPEC CPU2017."
   exit 1
fi

# NB: Use the same name in the config "label" as the config filename. See line 33 *.cfg
CONFIG=riscv
CONFIGFILE=${CONFIG}.cfg

# The config used to compile for the host machine
H_CONFIG=host
H_CONFIGFILE=${H_CONFIG}.cfg

# Output redirection redirection to files (names match a spec run)
REDIRECT=false

# CML arguments
# idiomatic parameter and option handling in sh
compileFlag=false
genCommands=false

# intrate, fprate, intspeed, fpspeed
# Supersets spec{speed,rate}, and all, are not supported
suite_type=intspeed

# ref, train, test
input_type=ref

function usage
{
    echo "usage: gen_binaries.sh [--compile | --genCommands] [-H | -h | --help] [--suite [intspeed | intrate | fpspeed | fprate] | --input [train | test | ref]]"
}

while test $# -gt 0
do
   case "$1" in
        --compile)
            compileFlag=true
            ;;
        --genCommands)
            genCommandsFlag=true
            ;;
        --suite)
            shift;
            suite_type=$1
            ;;
        --input)
            shift;
            inputs_type=$1
            ;;
        -h | -H | -help)
            usage
            exit
            ;;
        --*) echo "ERROR: bad option $1"
            usage
            exit 1
            ;;
        *) echo "ERROR: bad argument $1"
            usage
            exit 2
            ;;
    esac
    shift
done

echo "== Speckle Options =="
echo "  Config : " ${CONFIG}
echo "  Suite  : " ${suite_type}
echo "  Input  : " ${input_type}
echo "  compile: " $compileFlag
echo "  genCmd : " $genCommandsFlag
echo ""


# Directory into which speckle will dump logs and the overlay
build_dir=$PWD/build
overlay_dir=$build_dir/overlay

if [[ $suite_type == *"speed"* ]]; then
   prefix="6"
   class="speed"
   suffix="_s"
else
   prefix="5"
   class="rate"
   suffix="_r"
fi

benchmarks=$(basename -s .${input_type}.cmd --multiple $(pwd)/commands/${suite_type}/*."${input_type}".cmd)
mkdir -p build;

# compile the binaries
if [ "$compileFlag" = true ]; then
   echo "Compiling SPEC..."
   # TODO: deal with scrubbing properly
   #cd $SPEC_DIR; . ./shrc; time runcpu --config ${CONFIG} --action scrub ${suite_type}

   # copy over the config file we will use to compile the benchmarks
   cp $build_dir/../${CONFIGFILE} $SPEC_DIR/config
   cp $build_dir/../${H_CONFIGFILE} $SPEC_DIR/config
   echo "Compiling target SPEC with config: ${CONFIGFILE}"
   cd $SPEC_DIR; . ./shrc; time runcpu --verbose 10 --config ${CONFIG} --size ${input_type} \
      --action build ${suite_type} > ${build_dir}/${CONFIG}-${suite_type}-build.log
   echo "Compiling host SPEC and generating inputs with config: ${H_CONFIGFILE}"
   cd $SPEC_DIR; . ./shrc; time runcpu --verbose 10 --config ${H_CONFIG} --size ${input_type} \
      --action runsetup ${suite_type} > ${build_dir}/${H_CONFIG}-${suite_type}-build.log

   for b in ${benchmarks[@]}; do
      output_dir=${overlay_dir}/${suite_type}/$b
      mkdir -p $output_dir
      bmark_base_dir=$SPEC_DIR/benchspec/CPU/$b
      unprefixed=${b:4}
      b_short_name=${unprefixed/%_[sr]/}

      if [[ "${input_type}" == "ref" ]]; then
         host_bmk_dir=${bmark_base_dir}/run/run_base_ref${class}_${H_CONFIG}-m64.0000;
      else
         host_bmk_dir=${bmark_base_dir}/run/run_base_${input}_${H_CONFIG}-m64.0000;
      fi

      # Copy the inputs from the host build
      inputs=$(find "$host_bmk_dir"/* -maxdepth 0 ! -executable -o -type d)
      for input in ${inputs[@]}; do
         echo $input
         cp -rf $input -T $output_dir/$(basename "$input")
      done

      if [[ $b == "523.xalancbmk_r" ]]; then
         target_bin=`find $bmark_base_dir/exe/ -name "cpuxalan*${CONFIG}-64"`
      else
         target_bin=`find $bmark_base_dir/exe/ -name "*${b_short_name}*${CONFIG}-64"`
      fi
      cp -f ${target_bin} $output_dir/

      # Generate a run script
      run_script=${output_dir}/run.sh
      echo "#!/bin/bash" > ${run_script}
      echo "#This script was generated by Speckle gen_binaries.sh" >> ${run_script}

      IFS=$'\n' read -d '' -r -a commands < $build_dir/../commands/$suite_type/${b}.${input_type}.cmd
      workload_idx=0
      for input in "${commands[@]}"; do
         if [[ ${input:0:1} != '#' ]]; then # allow us to comment out lines in the cmd files
            if [[ "$REDIRECT" = false ]]; then
               input=${input% > *}
            fi
            workload_run_script=${output_dir}/run_workload${workload_idx}.sh
            echo "#!/bin/bash" > ${workload_run_script}
            message="echo 'Running: ./$(basename "${target_bin}") ${input}'"
            cmd="./$(basename "${target_bin}") ${input}"
            echo "$message" >> ${run_script}
            echo "$message" >> ${workload_run_script}
            echo "$cmd" >> ${run_script}
            echo "$cmd" >> ${workload_run_script}
            chmod +x $workload_run_script
            ((workload_idx++))
         fi
      done
      chmod +x $run_script
   done
fi

# Produces the .cmd files for a benchmark suite
# These files are committed, but can be regenereated with this command
if [ "$genCommandsFlag" = true ]; then
   # First do a fake run from which will extract the commands
   log_file="${build_dir}/${suite_type}.${input_type}.fakerun.log"
   cd $SPEC_DIR; . ./shrc; time runcpu --config=host.cfg --fake --verbose 9  --size ${input_type} --action=onlyrun ${suite_type} > $log_file

   bmarks=(`grep -nE "Running [5-6]+" $log_file | grep -Eo '[0-9]+\.[0-9a-zA-Z_]+'`)
   mkdir -p $build_dir/../commands/${suite_type}
   echo ${bmarks}
   for bmark in "${bmarks[@]}"; do
      echo $bmark
      start_line=`grep -nE "Running $bmark" $log_file | grep -Eo '^[0-9]+'`
      end_line=`grep -nE "Run $bmark" $log_file | grep -Eo '^[0-9]+'`
      sed "${start_line},${end_line}!d" $log_file | grep '^\.\./run_base' | sed 's/[^ ]* //' > ${build_dir}/../commands/${suite_type}/${bmark}.${input_type}.cmd
   done
fi


echo ""
echo "Done!"

