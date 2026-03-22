# Build with: make LLVM_CONFIG=/path/to/llvm-config
# Default uses llvm-config from PATH.

LLVM_CONFIG ?= llvm-config

CXX := clang++
CXXFLAGS := $(shell $(LLVM_CONFIG) --cxxflags) -Wall -Wextra -g -O2
LDFLAGS := $(shell $(LLVM_CONFIG) --ldflags)
LIBS := $(shell $(LLVM_CONFIG) --libs core irreader support analysis)

TARGET := ll-dump
SRC := src/ll-dump.cpp

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) -o $@ $< $(LDFLAGS) $(LIBS)

clean:
	rm -f $(TARGET)

.PHONY: all clean web-serve

# From repo root: copy JSON next to the page, then open http://localhost:8765/
web-serve:
	@test -f output.json && cp -f output.json web/output.json || true
	cd web && python3 -m http.server 8765
