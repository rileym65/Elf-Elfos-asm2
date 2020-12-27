PROJECT = asm2

asm2.rom: asm2.prg link2.prg
	./combine.pl asm2.prg link2.prg >asm2.rom

$(PROJECT).prg: $(PROJECT).asm bios.inc
	cp asm2.num build.num
	../dateextended.pl > date.inc
	../build.pl > build.inc
	cp build.num asm2.num
	rcasm -l -v -x -d1802 $(PROJECT) 2>&1 | tee $(PROJECT).lst
	cat $(PROJECT).prg | sed -f asm2.sed > x.prg
	rm $(PROJECT).prg
	mv x.prg $(PROJECT).prg

link2.prg: link2.asm bios.inc
	cp link2.num build.num
	../dateextended.pl > date.inc
	../build.pl > build.inc
	cp build.num link2.num
	rcasm -l -v -x -d1802 link2 2>&1 | tee link2.lst
	cat link2.prg | sed -f link2.sed > x.prg
	rm link2.prg
	mv x.prg link2.prg

clean:
	-rm $(PROJECT).prg
	-rm link2.prg


