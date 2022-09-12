# change OUTPUT to your output dir of https://github.com/aquasecurity/libbpfgo
# after running `make selftest-static-run`
OUTPUT = ./output

LIBBPF_OBJ = $(abspath $(OUTPUT)/libbpf.a)

CC = gcc
CLANG = clang
GO = go

MAKE = make
ARCH := $(shell uname -m | sed 's/x86_64/amd64/g; s/aarch64/arm64/g')

CFLAGS = -g -O2 -Wall -fpie
LDFLAGS =

CGO_CFLAGS_STATIC = "-I$(abspath $(OUTPUT))"
CGO_LDFLAGS_STATIC = "-lelf -lz $(LIBBPF_OBJ)"
CGO_EXTLDFLAGS_STATIC = '-w -extldflags "-static"'

CGO_CFLAGS_DYN = "-I. -I/usr/include/ -I$(abspath $(OUTPUT))"
CGO_LDFLAGS_DYN = "-lelf -lz -lbpf -L$(abspath $(OUTPUT))"

.PHONY: $(TARGET)
.PHONY: $(TARGET).go
.PHONY: $(TARGET).bpf.c

TARGET = hoge

all: $(TARGET)-static

.PHONY: libbpfgo-static
.PHONY: libbpfgo-dynamic

## test bpf dependency

$(TARGET).bpf.o: $(TARGET).bpf.c
	# $(CLANG) $(CFLAGS) -target bpf -D__TARGET_ARCH_$(ARCH) -I$(OUTPUT) -c $< -o $@
	$(CLANG) $(CFLAGS) -target bpf -D__TARGET_ARCH_x86 -I$(OUTPUT) -c $< -o $@

## test

.PHONY: $(TARGET)-static
.PHONY: $(TARGET)-dynamic

$(TARGET)-static: libbpfgo-static | $(TARGET).bpf.o
	CC=$(CLANG) \
		CGO_CFLAGS=$(CGO_CFLAGS_STATIC) \
		CGO_LDFLAGS=$(CGO_LDFLAGS_STATIC) \
		GOOS=linux GOARCH=$(ARCH) \
		$(GO) build \
		-tags netgo -ldflags $(CGO_EXTLDFLAGS_STATIC) \
		-o $(TARGET)-static ./$(TARGET).go

$(TARGET)-dynamic: libbpfgo-dynamic | $(TARGET).bpf.o
	CC=$(CLANG) \
		CGO_CFLAGS=$(CGO_CFLAGS_DYN) \
		CGO_LDFLAGS=$(CGO_LDFLAGS_DYN) \
		$(GO) build -o ./$(TARGET)-dynamic ./$(TARGET).go

## run

.PHONY: run
.PHONY: run-static
.PHONY: run-dynamic

run: run-static

run-static: $(TARGET)-static
	sudo ./$(TARGET)-static

run-dynamic: $(TARGET)-dynamic
	sudo ./$(TARGET)-dynamic

clean:
	rm -f *.o *-static *-dynamic
