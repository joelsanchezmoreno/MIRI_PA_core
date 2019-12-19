#ifndef CORETB_HPP
#define CORETB_HPP

#include <cstdint>
#include <map>
#include <verilated.h>
#include "verilated_vcd_c.h"
//#include <verilated_fst_c.h>
#include "top_module.h"
#include VTOP_MODULE_HEADER

class coreTB {
public:
	coreTB(VTOP_MODULE *top);
	~coreTB();

	void reset_tb_top(void);
	void generate_pulse(void);
	void initializeTracing(const char *vcdname);
    void close_trace(void);
    
	uint64_t getTimeStamp(void);
    
private:
	VTOP_MODULE *top;

    // Tick counter (2 ticks == 1 cycle)
	uint64_t timeStamp;

    // Waveform 
	//VerilatedFstC *fst;
    VerilatedVcdC *vcd_trace;

	void advanceTimeStamp(void);
};

#endif
