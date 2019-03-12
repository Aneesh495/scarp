# scarp: High-Throughput Seismic Early Warning and Kinematic Inversion Engine

CC ?= clang
CFLAGS ?= -O3 -Wall -Wextra -pedantic -std=c11 -fPIC -pthread
LDFLAGS ?= -pthread -lm

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	SHLIB_EXT := dylib
	SHLIB_FLAGS := -dynamiclib -install_name @rpath/libscarp_fast.dylib
else
	SHLIB_EXT := so
	SHLIB_FLAGS := -shared
endif

BUILD_DIR := build
BIN_DIR := bin
SRC_C := $(wildcard src/c/*.c)
OBJ_C := $(patsubst src/c/%.c,$(BUILD_DIR)/%.o,$(SRC_C))
TARGET_LIB := $(BUILD_DIR)/libscarp_fast.$(SHLIB_EXT)

PYTHON ?= python3

.PHONY: all build clean test bench lint web doctor dirs

all: build

dirs:
	@mkdir -p $(BUILD_DIR) $(BIN_DIR)

$(BUILD_DIR)/%.o: src/c/%.c | dirs
	$(CC) $(CFLAGS) -Iinclude -Isrc/c -c $< -o $@

build: dirs $(OBJ_C)
	@if [ -n "$(OBJ_C)" ]; then \
		$(CC) $(SHLIB_FLAGS) $(OBJ_C) $(LDFLAGS) -o $(TARGET_LIB); \
		echo "Built $(TARGET_LIB)"; \
	else \
		echo "No C sources compiled yet."; \
	fi

test: build
	$(PYTHON) tools/check_em_dashes.py
	$(PYTHON) tools/scarp_cli.py test

bench: build
	$(PYTHON) tools/scarp_cli.py bench

lint:
	$(PYTHON) tools/check_em_dashes.py

web:
	$(PYTHON) tools/scarp_cli.py web --port 8765

doctor:
	$(PYTHON) tools/scarp_cli.py doctor

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR) *.log
