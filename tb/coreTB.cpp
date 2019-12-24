#include "coreTB.hpp"

coreTB::coreTB(VTOP_MODULE *top) :
	top(top), timeStamp(0), vcd_trace(nullptr)
{
}

coreTB::~coreTB()
{
    // Enable trace dumping to FST format
	if (vcd_trace) {
		vcd_trace->dump(timeStamp);
		vcd_trace->close();
		delete vcd_trace;
	}
}

// Return the timeStamp private variable
uint64_t coreTB::getTimeStamp(void)
{
	return timeStamp;
}

// Increase timeStamp and dump if needed
void coreTB::advanceTimeStamp(void)
{
    // In case of waveform dump the given timeStamp
	if (vcd_trace)
		vcd_trace->dump(timeStamp);

    // Increase the timeStamp
	timeStamp++;
}

// Reset behaviour for the testbench
void coreTB::reset_tb_top(void)
{
	top->clk_i = 0;
	top->reset_i = 1;
	top->eval();

	advanceTimeStamp();

    top->clk_i = 1;
	top->reset_i = 1;
	top->eval();

	advanceTimeStamp();

    top->clk_i = 0;
	top->reset_i = 1;
	top->eval();

	advanceTimeStamp();

    top->clk_i = 1;
	top->reset_i = 1;
	top->eval();

	advanceTimeStamp();
	top->clk_i = 0;
	top->eval();

	advanceTimeStamp();

	top->reset_i = 0;
}

// Generate a pulse on the testbench clock
void coreTB::generate_pulse(void)
{
	top->clk_i = 1;
	top->eval();

	advanceTimeStamp();

	top->clk_i = 0;
	top->eval();

	advanceTimeStamp();
}

// Initialize the VCD waveform openning the trace
void coreTB::initializeTracing(const char *vcdname)
{
	if (vcd_trace)
		return;

	Verilated::traceEverOn(true);

	vcd_trace = new VerilatedVcdC;

    if (!vcd_trace)
		return;

	top->trace(vcd_trace, 99);
    vcd_trace->open(vcdname);
}

void coreTB::close_trace(void) 
{
	if (vcd_trace) {
		vcd_trace->close();
		vcd_trace = NULL;
	}
}

