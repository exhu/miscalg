FPC ?= fpc
LAZBUILD ?= lazbuild
FPC_FLAGS = -Mobjfpc -Sh -FEbin -FUbuild -Fu./src

.PHONY: all test debug lazbuild clean

all: pdiskpofftui

dirs:
	@mkdir -p bin build

pdiskpofftui: dirs
	$(FPC) $(FPC_FLAGS) -O3 -XX -CX pdiskpofftui.lpr

debug: dirs
	$(FPC) $(FPC_FLAGS) -gl -O- -gh -Cr -Ci -Co -Sa pdiskpofftui.lpr

test: dirs
	$(FPC) $(FPC_FLAGS) -gl -O- ./tests/test_runner.lpr
	./bin/test_runner

lazbuild:
	$(LAZBUILD) pdiskpofftui.lpi
	$(LAZBUILD) tests/test_runner.lpi

clean:
	rm -rf bin build
	rm -f src/*.o src/*.ppu src/*.compiled
	rm -f tests/*.o tests/*.ppu tests/*.compiled
	rm -f *.o *.ppu *.compiled
