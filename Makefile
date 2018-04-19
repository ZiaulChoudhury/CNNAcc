# This Makefile can be used from each of the Part subdirectories
# For example:    'make s1'

BSC=bsc

# ----------------------------------------------------------------
# Bluesim targets

.PHONY: dag dag2
 
dag:
	$(BSC)  -verilog -u -cpp -parallel-sim-link 8 -no-warn-action-shadowing Stage.bsv
	$(BSC)  -sim  -u -g mkTB -show-schedule -parallel-sim-link 8 -no-warn-action-shadowing -show-range-conflict -cpp  TB.bsv
	#$(BSC)  -sim  -u -g mkXilibus  +RTS -K20M -RTS -show-schedule -parallel-sim-link 8 -no-warn-action-shadowing -show-range-conflict -cpp  Xilibus.bsv
	$(BSC)  -sim  -e mkTB  -o ram  *.ba
	#$(BSC)  -sim  -e mkXilibus  -o ram  *.ba image-utilities.cpp


dag2:
	#$(BSC)  -verilog -u -cpp +RTS -K20M -RTS -parallel-sim-link 8 -no-warn-action-shadowing Stage.bsv
	$(BSC)  -sim  -u -g mkTB2  +RTS -K20M -RTS -show-schedule -parallel-sim-link 8 -no-warn-action-shadowing -show-range-conflict -cpp  TB2.bsv
	#$(BSC)  -sim  -u -g mkXilibus  +RTS -K20M -RTS -show-schedule -parallel-sim-link 8 -no-warn-action-shadowing -show-range-conflict -cpp  Xilibus.bsv
	$(BSC)  -sim  -e mkTB2  -o ram  *.ba
	#$(BSC)  -sim  -e mkXilibus  -o ram  *.ba image-utilities.cpp



# -----------------------------------------------------------------

.PHONY: clean fullclean

# Clean all intermediate files
clean:
	rm -f  *~  *.bi  *.bo  *.ba  *.h  *.cxx  *.o

# Clean all intermediate files, plus Verilog files, executables, schedule outputs
fullclean:
	rm -f  *~  *.bi  *.bo  *.ba  *.h  *.cxx  *.o *.v
	rm -f  *.exe   *.so  *.sched  *.v  *.vcd

