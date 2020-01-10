#include "coreTB.hpp"

coreTB::coreTB(VTOP_MODULE *top) :
	top(top), timeStamp(0), trace(nullptr)
{
}

coreTB::~coreTB()
{
    // Enable trace dumping to FST format
	if (trace) {
		trace->dump(timeStamp);
		trace->close();
		delete trace;
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
	if (trace)
		trace->dump(timeStamp);

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

// Initialize the waveform openning the trace
void coreTB::initializeTracing(const char *trace_name)
{
	if (trace)
		return;

	Verilated::traceEverOn(true);

	//trace = new VerilatedVcdC;
	trace = new VerilatedFstC;

    if (!trace)
		return;

	top->trace(trace, 99);
    trace->open(trace_name);
}

void coreTB::close_trace(void) 
{
	if (trace) {
		trace->close();
		trace = NULL;
	}
}

