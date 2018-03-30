.PHONY: all clean

PROGRAMS = dazzlie

all: $(PROGRAMS)

clean:
	rm -f $(PROGRAMS)

CRYSTAL_FILES := $(shell find src/ lib/ -type f -name "*.cr" 2> /dev/null)

$(PROGRAMS): %: src/%.cr lib $(CRYSTAL_FILES)
	crystal build -o $@ $<

lib: shard.yml shard.lock
	crystal deps install
	@touch lib
