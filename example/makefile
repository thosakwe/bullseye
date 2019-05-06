.PHONY: clean
BLSC = pub run bullseye_lang:blsc
objects = angel/hello.temp.dill

all: angel/hello.dill

clean:
	find . -name '*.dill' -delete

angel/hello.dill: $(objects)
	$(BLSC) -o $@ -L $(objects)

%.temp.dill: %.bls
	$(BLSC) -o $@ $<