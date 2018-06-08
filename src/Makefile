# This Makefile can be used from each of the Part subdirectories
# For example:    'make s1'

BSC=bsc

# ----------------------------------------------------------------
# Bluesim targets

.PHONY: dag multi multi4 single channel ram switch gauss

gauss:
	$(BSC)  -verilog  -u -g mkGaussBlur  -show-schedule -cpp  GaussBlur.bsv
	$(BSC)  -sim  -e mkGaussBlur  -o gauss  *.ba image-utilities.cpp

dummy:
	#$(BSC)  -verilog -u -cpp  +RTS -K20M -RTS -parallel-sim-link 8 -no-warn-action-shadowing Stage.bsv
	$(BSC)  -sim  -u -g mkDummy  +RTS -K20M -RTS -show-schedule -parallel-sim-link 8 -no-warn-action-shadowing -show-range-conflict -cpp  Dummy.bsv
	$(BSC)  -sim  -e mkDummy  -o ram  *.ba 
dag:
	#$(BSC)  -verilog -u -cpp +RTS -K20M -RTS -parallel-sim-link 8 -no-warn-action-shadowing TestBench.bsv
	#$(BSC)  -verilog -o ver -e mkTestBench *.v	
	$(BSC)  -sim  -u -g mkXilibus  +RTS -K20M -RTS -show-schedule -parallel-sim-link 8 -no-warn-action-shadowing -show-range-conflict -cpp  Xilibus.bsv
	$(BSC)  -sim  -e mkXilibus  -o ram  *.ba image-utilities.cpp

sane:
	$(BSC)  -verilog -u -cpp  +RTS -K20M -RTS -parallel-sim-link 8 -no-warn-action-shadowing Iso.bsv
	$(BSC)  -sim  -u -g mkIso  +RTS -K20M -RTS -show-schedule -parallel-sim-link 8 -no-warn-action-shadowing -cpp  Iso.bsv
	$(BSC)  -sim  -e mkIso  -o ram  *.ba image-utilities.cpp


multi:	
	$(BSC)  -sim  -u -g mkMultirate  -show-schedule -cpp  Multirate.bsv
	$(BSC)  -sim  -e mkMultirate  -o multi  *.ba image-utilities.cpp

multi4:  
	$(BSC)  -sim  -u -g mkMultirate4  -show-schedule -cpp  Multirate4.bsv
	$(BSC)  -sim  -e mkMultirate4  -o multi  *.ba image-utilities.cpp

single:  
	$(BSC)  -sim  -u -g mkSinglerate  -show-schedule -cpp  Singlerate.bsv
	$(BSC)  -sim  -e mkSinglerate  -o single  *.ba image-utilities.cpp

channel:  
	$(BSC)  -sim  -u -g mkTestBench  -show-schedule -cpp  TestBench.bsv
	$(BSC)  -sim  -e mkTestBench  -o ram  *.ba image-utilities.cpp

ram:  
	$(BSC)  -sim  -u -g mkCheckBRAM  -show-schedule -cpp CheckBRAM.bsv
	$(BSC)  -sim  -e mkCheckBRAM  -o ramc  *.ba image-utilities.cpp

switch:  
	$(BSC)  -sim  -u -g mkTestSwitch  -show-schedule TestSwitch.bsv
	$(BSC)  -sim  -e mkTestSwitch  -o ram  *.ba  



# -----------------------------------------------------------------

.PHONY: clean fullclean

# Clean all intermediate files
clean:
	rm -f  *~  *.bi  *.bo  *.ba  *.h  *.cxx  *.o

# Clean all intermediate files, plus Verilog files, executables, schedule outputs
fullclean:
	rm -f  *~  *.bi  *.bo  *.ba  *.h  *.cxx  *.o *.v
	rm -f  *.exe   *.so  *.sched  *.v  *.vcd

