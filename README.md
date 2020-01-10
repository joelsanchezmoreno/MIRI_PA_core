# PA-MIPS-Processor

How to compile?

    make clean; 
    make verilate 2>&1 |tee build.log; 

How to run?

    ./obj_dir/Vcore_tb 100

How to open the generated waveform?
    
    gtkwave trace.vcd


TESTS:
How to generate new *a*,*b* and *c* matrixs? (a x b = c)

    python matrixGenerator.py
    python mxmValidator.py

//NOTE: In matrixGenerator you can indicate the maximum randon number that the
//matrixGenerator can assing to matrix *a* and *b* (randint(0, X)), if the number is to big 
//the mxmValidator will complain because there will be results bigger than 32 bits.

