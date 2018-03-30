.PHONY: all clean

PROGRAM = dazzlie

all: $(PROGRAM)

clean:
	rm -f $(PROGRAM)

CRYSTAL_FILES := $(shell find src/ lib/ -type f -name "*.cr" 2> /dev/null)

$(PROGRAM): src/main.cr lib $(CRYSTAL_FILES)
	crystal build -o $@ $<

lib: shard.yml shard.lock
	crystal deps install
	@touch lib
