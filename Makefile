.PHONY: all clean

PROGRAM = bin/dazzlie

all: $(PROGRAM)

clean:
	rm -f $(PROGRAM)

install: all
	install -m 555 $(PROGRAM) /usr/local/bin/$(notdir $(PROGRAM))

CRYSTAL_FILES := $(shell find src/ lib/ -type f -name "*.cr" 2> /dev/null)

$(PROGRAM): src/main.cr lib $(CRYSTAL_FILES)
	crystal build -o $@ $<

lib: shard.yml shard.lock
	crystal deps install
	@touch lib
