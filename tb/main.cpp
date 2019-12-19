#include <iostream>
#include <cstdio>
#include <getopt.h>
#include <verilated.h>
#include "coreTB.hpp"
#include "top_module.h"
#include VTOP_MODULE_HEADER

#define DEFAULT_NUM_CYCLES 2000


// Usage function
static void usage(char *argv[]);

static void usage(char *argv[])
{
	printf("Source code: https://github.com/marcigarza/PA-MIPS-Processor\n"
		"Usage: %s [OPTIONS]\n"
		"Options:\n"
		"  -n, --num-cycles=N      number of cycles to be executed before stopping\n"
		"  -h, --help              display this help and exit\n"
		, argv[0]);
}

static coreTB *core_tb;

// Main routine
int main(int argc, char *argv[])
{
    static const struct option long_options[] = {
        {"num-cycles", required_argument, NULL, 'n'},
        {"help", no_argument, NULL, 'h'},
        {NULL, 0, NULL, 0}
    };

    int opt;
    VTOP_MODULE *top;
    int ret = 0;
    uint64_t num_cycles = DEFAULT_NUM_CYCLES;
    bool early_exit = false;

    top = new VTOP_MODULE;
    if (!top)
        return -1;

    core_tb = new coreTB(top);
    if (!core_tb) {
        top->final();
        delete top;
    }

    while ((opt = getopt_long(argc, argv, "l:n:h", long_options, NULL)) != -1) {
        if (opt != 0) {
            usage(argv);
            early_exit = true;
            ret = -1;
            break;
        }

        switch (opt) {
            case 'n':
                num_cycles = strtoull(optarg, NULL, 0);
                break;
            case 'h':
                usage(argv);
                early_exit = true;
                break;
        }
    }

    if (early_exit) {
        top->final();
        delete core_tb;
        delete top;
        return ret;
    }

    argc -= optind;
    argv += optind;

    Verilated::commandArgs(argc, argv);

    core_tb->initializeTracing("trace.vcd");
    core_tb->reset_tb_top();

    // Check if we still have cycles to run.
    while ((core_tb->getTimeStamp() < num_cycles) && !Verilated::gotFinish()) {
        core_tb->generate_pulse();
    }

    core_tb->close_trace();
    top->final();
    delete core_tb;
    delete top;

    return ret;
}

