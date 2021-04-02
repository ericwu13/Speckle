** SPEC2017 GEM5 Port **

   This branch is a WIP and changes Speckle's usage model. It removes run support,
   and makes the copy mode the default.

   Key changes:
   - Remove Host configurations
   - A target SPEC2017 build is done to generate target binaries
   - A target bin/inputs are located in build/overlay/
   - A run script(run.sh) is generated that executes all the inputs for the benchmark
   - create run-gem5.sh to use gem5 target in se mode (se.py)
   
   
   All of the following sections of the README may be out of date.

**Purpose**

   The goal of this repository is to help you compile and run SPEC. This will
   NOT verify the output of SPEC.

**Requirements**

   - you must have your own copy of SPEC CPU2006 v1.2. 
   - you must have built the tools in SPEC CPU2006 v1.2 (see below for help). 


**Details**

   We will compile the binaries "in vivo", calling into the actual SPEC CPU2006
   directory. Once completed, the binaries are copied into this directory (./build). 
   
   The reasoning is that compiling the benchmarks is complicated and difficult (so
   why redo that effort?), but we want better control over executing the binaries.  Of
   course, we are forgoing the validation and results building infrastructure of
   SPEC. 


**Setup**

   - set the $SPEC_DIR variable in your environment to point to your copy of CPU2006-1.2.
   - modify Speckle/riscv.cfg as desired. It will get copied over to
     $SPEC_DIR/configs when compiling the benchmarks. 
   - modify the BENCHMARKS variable in gen_binaries.sh as required to set which
     benchmarks you would like to compile and run.
   - modify the RUN variable in gen_binaries.sh as required to set how you
     would like to run the binaries (e.g., RUN="spike pk" to run on the Spike
     ISA simulator).


**To compile binaries**

        ./gen_binaries.sh --compile

   You only need to compile SPEC once for a given SPEC input ("test", "train",
   "ref"). It should take about a minute. 


**To run binaries**

        ./gen_binaries.sh --run
        
   However, this only runs the binaries as specified by the $RUN variable in 
   gen_binaries.sh, and it is running them via the symlinked directories in build/.

**Building (and running) the binaries from a portable directory**

   By default, benchmarks are compiled and then symlinked into build/. However,
   for portability reasons, you can use: 
   
         ./gen_binaries.sh --compile --copy
   
   This will copy all the input files and binaries into a new directory (named after 
   your CONFIG file and the INPUT size). This directory will contain a run.sh script 
   and the commands/ directory needed to run SPEC anywhere!
   
   Modify the generated "./${CONFIG}-spec-{$INPUT}/run.sh" script as required to 
   run the binaries in your new environment.  


**TODO**
   
   - add in training input set
   - provide input parameter control over the type and set of SPEC benchmarks built
      (e.g., currently requires manual hacking to build SPECInt vs SPECFP)
   - store output generated by SPEC into a separate /output directory


**Known Issues**

   - Currently, the riscv-pk does not support one of the perlbench.test workloads.
       This is because it calls the fork syscall, which is not supported by riscv-pk.
   - Currently, the riscv-pk exhibits errors on some of the reference input sets 
       (it is reccommended that you use Linux instead).


**Building SPEC Tools**

   These are the instructions that I had to follow to build the CPU2006 v1.2
   tools from scratch on Intel amd64 machines running Ubuntu.

   First, you can try:

        cd $SPEC_DIR/
        ./install.sh

   Hopefully that works. 
   
**Building SPEC Tools: The Hard Way**

   If the Easy Way does not work, you can also try installing the tools from
   scratch.  What follows is a method that worked for me.
   
   Begin by creating a script (my_setup.sh) in cpu2006-1.2/tools/src with the
   following code:

        #!/bin/bash
        PERLFLAGS=-Uplibpth=
        for i in `gcc -print-search-dirs | grep libraries | cut -f2- -d= | tr ':' '\n' | grep -v /gcc`; do
            PERLFLAGS="$PERLFLAGS -Aplibpth=$i"
        done
        export PERLFLAGS
        echo $PERLFLAGS
        export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin

   Then:

        cd cpu2006-1.2/tools/src
        source my_setup.sh
        ./buildtools


