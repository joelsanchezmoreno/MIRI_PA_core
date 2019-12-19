# PA-MIPS-Processor

How to compile?

    make clean; 
    make verilate 2>&1 |tee build.log; 

How to run?

    ./obj_dir/Vcore_tb 100

How to open the generated waveform?
    
    gtkwave trace.vcd
