CXX = g++
CXXFLAGS = -std=c++17 -O3 -Wall -Wextra

TARGET = sha256_golden_model
SRC = sha256_golden_model.cpp
VECTORS = input_vectors.txt intermediate_states.txt final_hashes.txt

ifeq ($(OS),Windows_NT)
    BIN = $(TARGET).exe
    RM = del /Q /F
else
    BIN = $(TARGET)
    RM = rm -f
endif

.PHONY: all build run clean

all: build run

build: $(BIN)

$(BIN): $(SRC)
	$(CXX) $(CXXFLAGS) $< -o $@

run: $(BIN)
	./$(BIN)

clean:
	-$(RM) $(BIN) $(VECTORS)
