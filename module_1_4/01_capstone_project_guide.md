# Chapter 1: Capstone Project Guide - Core Banking Engine

The **Enterprise Core Banking & Ledger Engine** simulates a high-reliability transaction processing core for a financial institution. In this project, you will build and harden a COBOL service that manages customer accounts, executes batch debits and credits with strict ACID compliance, prevents overdrafts and numerical overflows, and produces an audited ledger statement from an embedded SQLite database.

---

## 1. System Architecture

```text
               +--------------------------------------------------+
               |                  BankingApp.cob                  |
               |                                                  |
               |  1. Free-Format Modular COBOL Program (Module 1) |
               |  2. Domain Logic & Rule Evaluation    (Module 2) |
               |  3. Safe Mathematical Ops (COMP-3/5)  (Module 4) |
               |  4. Hardware Table Indexing (INDEXED) (Module 4) |
               |  5. Conditional Debug Traces (>>D)    (Module 4) |
               +------------------------+-------------------------+
                                        |
                            CALL "cob_sqlite_*"
                                        |
                                        v
               +--------------------------------------------------+
               |                   cob_sqlite.c                   |
               |                                                  |
               |  Type-Safe, Bounds-Checked C Bridge   (Module 3) |
               |  Null-Termination, Alignment-Safe Buffer Copy    |
               +------------------------+-------------------------+
                                        |
                                        v
               +--------------------------------------------------+
               |                  SQLite3 Engine                  |
               |                  bank_master.db                  |
               |                                                  |
               |  ACID Storage: accounts & transactions (Module 3)|
               +--------------------------------------------------+
```

---

## 2. Database Schema & Tables

The service initializes two relational tables in `bank_master.db`:

### `accounts` Table
| Column | Type | Description |
| :--- | :--- | :--- |
| `account_id` | `INT PRIMARY KEY` | Unique 9-digit account identifier (e.g., `1001`, `1002`). |
| `holder_name` | `TEXT` | Name of account owner (up to 25 characters). |
| `account_type`| `TEXT` | Account category (`CHECKING`, `SAVINGS`, `CORPORATE`). |
| `balance` | `REAL` | Current cleared account balance. |
| `status` | `TEXT` | Account lifecycle state (`ACTIVE`, `FROZEN`, `RESTRICTED`). |

### `transactions` Table
| Column | Type | Description |
| :--- | :--- | :--- |
| `txn_id` | `INT PRIMARY KEY` | Transaction sequential identifier. |
| `account_id` | `INT` | Foreign reference to `accounts(account_id)`. |
| `txn_type` | `TEXT` | Type of movement (`CREDIT`, `DEBIT`, `TRANSFER`). |
| `amount` | `REAL` | Currency value of the movement. |
| `txn_timestamp` | `TEXT` | Execution timestamp (ISO-8601 or date format). |

---

## 3. Data Dictionary (`BANKING.CPY`)

The domain structures are standardized in `BANKING.CPY`:

```cobol
       *> Account Record Layout
        01  ACCOUNT-RECORD.
            05  ACC-ID                    PIC S9(9) COMP-5.
            05  ACC-HOLDER-NAME           PIC X(25).
            05  ACC-TYPE                  PIC X(12).
            05  ACC-BALANCE               PIC S9(9)V99 COMP-3.
            05  ACC-STATUS                PIC X(10).

       *> In-Memory Batch Transaction Table (Hardware Indexed)
        01  BATCH-TRANSACTION-TABLE.
            05  BATCH-TXN-ITEM            OCCURS 5 TIMES
                                          INDEXED BY TXN-IDX.
                10  B-TXN-ID              PIC S9(9) COMP-5.
                10  B-ACC-ID              PIC S9(9) COMP-5.
                10  B-TYPE                PIC X(10).
                10  B-AMOUNT              PIC 9(7)V99 COMP-3.
                10  B-TIMESTAMP           PIC X(20).

       *> Reporting Editing Masks
        01  DISP-ACC-ID                   PIC ZZZZZZZZ9.
        01  DISP-AMOUNT                   PIC $$$,$$$,$$9.99.
        01  DISP-BALANCE                  PIC -$$$,$$$,$$9.99.
        01  DISP-TOTAL-ASSETS             PIC $$$$,$$$,$$9.99.
```

---

## 4. The 4 Starter Challenges (TODO Tasks)

The starter project (`exercises/capstone_banking_engine/starter/BankingApp.cob`) contains the application skeleton with 4 specific implementation challenges:

### TODO 1: Atomic Account Seeding (Module 3)
In paragraph `2000-SEED-ACCOUNTS`, wrap the insertion of initial customer accounts inside an atomic transaction:
1. Execute `BEGIN TRANSACTION;`.
2. Insert initial accounts (e.g. Account `1001` Alice, `1002` Bob, `1003` Acme Corp).
3. If any insert returns `NOT SQL-OK`, perform `3500-ROLLBACK-AND-ABORT`.
4. Commit the transaction with `COMMIT;`.

### TODO 2: Hardware-Indexed Batch Traversal (Module 4)
In paragraph `3000-PROCESS-BATCH-TXNS`, use hardware table indexing rather than slow numeric subscripts:
1. Initialize the index: `SET TXN-IDX TO 1`.
2. Loop over the 5 batch items: `PERFORM 3100-EXECUTE-SINGLE-TXN VARYING TXN-IDX FROM 1 BY 1 UNTIL TXN-IDX > 5`.
3. Read fields using `B-ACC-ID (TXN-IDX)`, `B-TYPE (TXN-IDX)`, and `B-AMOUNT (TXN-IDX)`.

### TODO 3: Resilient Balance Calculation & Overdraft Defense (Modules 2 & 4)
In paragraph `3100-EXECUTE-SINGLE-TXN`:
1. Start an atomic transaction for the transaction item (`BEGIN TRANSACTION;`).
2. If `B-TYPE = "CREDIT"`:
   - Add deposit amount to balance using `ADD B-AMOUNT (TXN-IDX) TO WS-TEMP-BAL ON SIZE ERROR ...`.
3. If `B-TYPE = "DEBIT"`:
   - Verify `WS-TEMP-BAL >= B-AMOUNT (TXN-IDX)`. If insufficient funds, reject the transaction with an overdraft warning, rollback, and skip account update.
   - Subtract debit amount safely: `SUBTRACT B-AMOUNT (TXN-IDX) FROM WS-TEMP-BAL ON SIZE ERROR ...`.
4. Update the account balance in SQLite and log the audit entry into `transactions`.
5. Commit the transaction.

### TODO 4: SQLite Cursor Stepping & Ledger Report (Modules 1 & 3)
In paragraph `4000-QUERY-LEDGER`:
1. Prepare cursor: `SELECT account_id, holder_name, account_type, balance, status FROM accounts ORDER BY account_id;`.
2. Loop with `cob_sqlite_step` until `SQL-ROW` is false.
3. Extract columns into `ACCOUNT-RECORD` using `cob_sqlite_get_int`, `cob_sqlite_get_text`, and `cob_sqlite_get_double`.
4. Check for clean completion with `SQL-DONE`.
5. Accumulate total bank assets and print the formatted summary report.
6. Finalize statement and close database cleanly.

---

## 5. Expected Output

When properly implemented, running `./BankingApp` produces:

```text
=====================================================================
     ENTERPRISE CORE BANKING & TRANSACTION PROCESSING ENGINE         
=====================================================================
[INFO] Connecting to SQLite database 'bank_master.db'...
[INFO] Connected successfully.
 
[INFO] Initializing banking database schema...
[INFO] Schema initialized cleanly.
 
[INFO] Seeding initial customer accounts in atomic transaction...
[INFO] 3 master accounts seeded successfully.
 
[INFO] Loading batch transaction payload into indexed memory table...
[INFO] 5 batch transactions loaded.
 
[INFO] Processing batch transactions with ACID verification...
  [TXN 501] CREDIT  $1,500.00 to Acc 1001 -> SUCCESS (New Bal: $11,000.00)
  [TXN 502] DEBIT     $500.00 from Acc 1002 -> SUCCESS (New Bal: $2,000.00)
  [TXN 503] DEBIT   $5,000.00 from Acc 1002 -> REJECTED: Insufficient Funds (Overdraft Blocked)
  [TXN 504] CREDIT $25,000.00 to Acc 1003 -> SUCCESS (New Bal: $175,000.00)
  [TXN 505] DEBIT  $10,000.00 from Acc 1001 -> SUCCESS (New Bal: $1,000.00)
[INFO] Batch transaction processing completed.
 
[INFO] Generating General Ledger Audit Report from SQLite cursor...
-------------------------------------------------------------------------------------
ACCOUNT ID | HOLDER NAME               | TYPE         | CURRENT BALANCE | STATUS     
-------------------------------------------------------------------------------------
      1001 | Alice Jenkins             | CHECKING     |       $1,000.00 | ACTIVE     
      1002 | Bob Rodriguez             | SAVINGS      |       $2,000.00 | ACTIVE     
      1003 | Acme Corp Enterprise      | CORPORATE    |     $175,000.00 | ACTIVE     
-------------------------------------------------------------------------------------
Total Accounts Active : 0003
Total Ledger Assets   :     $178,000.00
Processed Moves Count : 0004
Rejected Moves Count  : 0001
 
[INFO] Closing database connection...
[INFO] Database closed cleanly.
=====================================================================
Banking engine operations completed successfully.
```

---

## 6. Verification Steps

### Standard Run
```bash
cd exercises/capstone_banking_engine/solution
cobc -Wall -Wextra -x -free BankingApp.cob cob_sqlite.c -lsqlite3 -o BankingApp
./BankingApp
echo "Exit status: $?"
```

### Debugging Mode (`>>D`)
```bash
cobc -x -free -debug BankingApp.cob cob_sqlite.c -lsqlite3 -o BankingApp_Debug
./BankingApp_Debug
```
Observe the low-level diagnostic traces printed for each transaction step.

