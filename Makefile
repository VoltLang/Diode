# Makefile for windows.
# Intended for Digital Mars Make and GNU Make.

VOLT = volt
TARGET = diode.exe
include sources.mk


all: $(TARGET)

$(TARGET):
	$(VOLT) --internal-perf -o $(TARGET) -I src $(SRC)

clean:
	del /q $(TARGET)

.PHONY: all clean
