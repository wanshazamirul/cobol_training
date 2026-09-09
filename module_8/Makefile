#====================================================================#
# Makefile for Module 8: COBOL CI/CD with SQLite & GitHub Actions     #
#====================================================================#

COBC := cobc
CC := gcc
SRC_DIR := src
BIN_DIR := bin
TESTS_DIR := tests
TARGET := $(BIN_DIR)/inventory_app

COBFLAGS := -x -free -I $(SRC_DIR) -Wall
LIBS := -lsqlite3

.PHONY: all check build test clean help

all: build

help:
	@echo "Available targets:"
	@echo "  make check  - Perform syntax checking on COBOL source"
	@echo "  make build  - Compile COBOL app and C SQLite bridge"
	@echo "  make test   - Run automated verification test harness"
	@echo "  make clean  - Remove built binaries and test database artifacts"

check:
	@echo "[CI-STEP] Syntax checking COBOL source..."
	$(COBC) -fsyntax-only -free -I $(SRC_DIR) $(SRC_DIR)/app.cob
	@echo "[CI-STEP] Syntax check passed."

build: $(TARGET)

$(TARGET): $(SRC_DIR)/app.cob $(SRC_DIR)/cob_sqlite.c $(SRC_DIR)/SQLITE.CPY
	@echo "[CI-STEP] Building native binary $(TARGET)..."
	@mkdir -p $(BIN_DIR)
	$(COBC) $(COBFLAGS) $(SRC_DIR)/app.cob $(SRC_DIR)/cob_sqlite.c $(LIBS) -o $(TARGET)
	@echo "[CI-STEP] Build successful: $(TARGET)"

test: build
	@echo "[CI-STEP] Running automated test suite..."
	@bash $(TESTS_DIR)/test_app.sh

clean:
	@echo "[CLEAN] Removing artifacts..."
	@rm -rf $(BIN_DIR)
	@rm -f inventory.db
	@rm -f *.db
	@echo "[CLEAN] Completed."

