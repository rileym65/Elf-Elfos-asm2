PROJECT = asm2

asm2.rom: asm2.prg link2.prg
	./combine.pl asm2.prg link2.prg >asm2.rom

$(PROJECT).prg: $(PROJECT).asm bios.inc
	cp asm2.num build.num
	../../dateextended.pl > date.inc
	../../build.pl > build.inc
	cp build.num asm2.num
	asm02 -l -L -DELFOS $(PROJECT).asm
	mv $(PROJECT).prg x.prg
	cat x.prg | sed -f asm2.sed > $(PROJECT).prg
	rm x.prg

link2.prg: link2.asm bios.inc
	cp link2.num build.num
	../../dateextended.pl > date.inc
	../../build.pl > build.inc
	cp build.num link2.num
	asm02 -l -L -DELFOS link2.asm
	mv link2.prg x.prg
	cat x.prg | sed -f link2.sed > link2.prg
	rm x.prg

clean:
	-rm $(PROJECT).prg
	-rm link2.prg


