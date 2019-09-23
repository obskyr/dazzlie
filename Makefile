.PHONY: all clean

PROGRAM_FILENAME = dazzlie
BUILD_DIR = bin/
PROGRAM = $(BUILD_DIR)$(PROGRAM_FILENAME)

all: $(PROGRAM)

clean:
	rm -f $(PROGRAM)

install: all
	install -m 555 $(PROGRAM) /usr/local/bin/$(PROGRAM_FILENAME)

CRYSTAL_FILES := $(shell find src/ lib/ -type f -name "*.cr" 2> /dev/null)

$(PROGRAM): src/main.cr lib $(CRYSTAL_FILES)
	@mkdir -p $(BUILD_DIR)
	crystal build -o $@ $<

lib: shard.yml shard.lock
	shards install
	@touch lib
