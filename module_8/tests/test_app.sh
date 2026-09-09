#!/usr/bin/env bash
#====================================================================#
# test_app.sh - Automated CI/CD Test Runner for Module 8              #
# Evaluates COBOL binary execution, exit codes, and SQLite database  #
#====================================================================#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_PATH="${MODULE_DIR}/bin/inventory_app"
DB_PATH="${MODULE_DIR}/inventory.db"

GREEN="\033[32m"
RED="\033[31m"
BLUE="\033[34m"
RESET="\033[0m"

echo -e "${BLUE}======================================================${RESET}"
echo -e "${BLUE}       MODULE 8 AUTOMATED REGRESSION & CI TEST        ${RESET}"
echo -e "${BLUE}======================================================${RESET}"

# 1. Ensure binary exists
if [ ! -f "${BIN_PATH}" ]; then
    echo -e "${RED}[FAIL] Binary not found at: ${BIN_PATH}${RESET}"
    echo "Attempting to build target..."
    make -C "${MODULE_DIR}" build
fi

# 2. Clean previous test database
rm -f "${DB_PATH}"

# 3. Execute application from module directory
echo -e "${BLUE}[TEST 1/3] Executing COBOL Inventory application...${RESET}"
cd "${MODULE_DIR}"
set +e
OUTPUT=$("${BIN_PATH}")
APP_EXIT_CODE=$?
set -e

echo "${OUTPUT}"

if [ ${APP_EXIT_CODE} -ne 0 ]; then
    echo -e "${RED}[FAIL] Application exited with non-zero code: ${APP_EXIT_CODE}${RESET}"
    exit 1
fi
echo -e "${GREEN}[PASS] Execution completed with return code 0.${RESET}"

# 4. Check SQLite database creation and file existence
echo -e "${BLUE}[TEST 2/3] Verifying SQLite database file creation...${RESET}"
if [ ! -f "${DB_PATH}" ]; then
    echo -e "${RED}[FAIL] Database file '${DB_PATH}' was not created.${RESET}"
    exit 1
fi
echo -e "${GREEN}[PASS] Database file '${DB_PATH}' verified.${RESET}"

# 5. Direct Database Assertions using sqlite3 CLI
echo -e "${BLUE}[TEST 3/3] Querying database directly to assert data integrity...${RESET}"
ROW_COUNT=$(sqlite3 "${DB_PATH}" "SELECT COUNT(*) FROM inventory;")
TOTAL_QTY=$(sqlite3 "${DB_PATH}" "SELECT SUM(quantity) FROM inventory;")

echo "Direct SQLite inspection: ${ROW_COUNT} rows, ${TOTAL_QTY} total units."

if [ "${ROW_COUNT}" -ne 4 ]; then
    echo -e "${RED}[FAIL] Row count mismatch! Expected 4, got: ${ROW_COUNT}${RESET}"
    exit 1
fi

if [ "${TOTAL_QTY}" -ne 39 ]; then
    echo -e "${RED}[FAIL] Total quantity mismatch! Expected 39, got: ${TOTAL_QTY}${RESET}"
    exit 1
fi

echo -e "${GREEN}[PASS] Database data integrity verified successfully.${RESET}"

echo -e "${BLUE}======================================================${RESET}"
echo -e "${GREEN}   ALL MODULE 8 CI/CD TESTS PASSED SUCCESSFULLY!     ${RESET}"
echo -e "${BLUE}======================================================${RESET}"
exit 0

