# This Makefile can be used from each of the Part subdirectories
# For example:    'make s1'

BSC=bsc

# ----------------------------------------------------------------
# Bluesim targets

.PHONY: dag dag2 test

test:
	#$(BSC)  -verilog -u -cpp -parallel-sim-link 8 -no-warn-action-shadowing TestBench.bsv
	#$(BSC)  -verilog -o ver -e mkTestBench *.v 
	$(BSC)  -sim  -u -g mkXilibus -show-schedule -parallel-sim-link 8 -no-warn-action-shadowing -show-range-conflict -cpp  Xilibus.bsv
	$(BSC)  -sim  -e mkXilibus  -o ram  *.ba image-utilities.cpp

check:
	$(BSC)  -sim  -u -g mkTB2 -show-schedule -parallel-sim-link 8 -no-warn-action-shadowing -show-range-conflict -cpp  TB2.bsv
	$(BSC)  -sim  -e mkTB2  -o ram  *.ba 
 


# -----------------------------------------------------------------

.PHONY: clean fullclean

# Clean all intermediate files
clean:
	rm -f  *~  *.bi  *.bo  *.ba  *.h  *.cxx  *.o

# Clean all intermediate files, plus Verilog files, executables, schedule outputs
fullclean:
	rm -rf  *~  *.bi  *.bo  *.ba  *.h  *.cxx  *.o v* x* 
	rm -rf  *.exe   *.so  *.sched   *.vcd x*  v*

