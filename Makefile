VERILATOR ?= verilator

TOP_MODULE = core_tb
TRACE_FILE = trace.fst # GTKWwave format

VERILOG_HEADERS= rtl/inc
VERILOG_SOURCES = $(shell find rtl -name *.v -o -name *.sv )
#VERILOG_SOURCES = rtl/inc/macros.vh rtl/inc/main_memory.vh rtl/inc/core_defines.vh rtl/inc/core_types.vh rtl/inc/soc.vh \
#				  rtl/fetch/icache_lru.v rtl/fetch/instruction_cache.v rtl/fetch/fetch_top.v \
#				  rtl/decode/regFile.v rtl/decode/decode_top.v \
#				  rtl/alu/alu_top.v \
#				  rtl/cache/store_buffer_lru.v rtl/cache/dcache_lru.v rtl/cache/data_cache.v rtl/cache/cache_top.v \
#				  rtl/writeback/wb_top.v \
#				  rtl/core_top.v rtl/core_tb.v

VERILATOR_TB_SOURCES = tb/main.cpp tb/coreTB.cpp
TEST_SOURCES = test/test.s

VERILATOR_VTOP = V$(TOP_MODULE)
CFLAGS = -std=c++11 -DVTOP_MODULE=$(VERILATOR_VTOP) -DTRACE_FILE=""$(TRACE_FILE)"" 
VERILATOR_FLAGS = -Wall -Wno-fatal --unroll-count 2048 --x-initial-edge --top-module $(TOP_MODULE)
TEST_CFLAGS = -march=rv32im -mabi=ilp32 -nostartfiles -nostdlib
HEXDUMP_FLAGS = -ve '1/1 "%02X "'

all: lint

#### Verilator ####
obj_dir/$(VERILATOR_VTOP): $(VERILOG_SOURCES) $(VERILATOR_TB_SOURCES)
	$(VERILATOR) $(VERILATOR_FLAGS) -CFLAGS "$(CFLAGS)"  -I$(VERILOG_HEADERS) --trace-fst --trace-structs --cc --exe $^
	make -j4 -k -C obj_dir -f $(VERILATOR_VTOP).mk $(VERILATOR_VTOP)
	chmod -R g+w,o+w obj_dir

verilate: obj_dir/$(VERILATOR_VTOP)
	@chmod -R g+w,o+w obj_dir

lint:
	@$(VERILATOR) $(VERILATOR_FLAGS) --lint-only $(VERILOG_SOURCES) -I$(VERILOG_HEADERS)

run: test.bin obj_dir/$(VERILATOR_VTOP)
	@hexdump $(HEXDUMP_FLAGS) $< > memory.hex.txt
	@obj_dir/$(VERILATOR_VTOP) $(ARGS)
	@chmod -R g+w,o+w obj_dir

$(TRACE_FILE): run

gtkwave: $(TRACE_FILE)
	@gtkwave $(TRACE_FILE) trace.sav

#### Common rules ####
clean: 
	@rm -rf obj_dir work $(TRACE_FILE) $(TRACE_FILE).hier *.elf *.bin *.hex.txt \
		vsim.wlf transcript

.PHONY:
	verilate run trace gtkwave clean
