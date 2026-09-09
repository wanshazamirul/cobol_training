        >>SOURCE FORMAT FREE
        IDENTIFICATION DIVISION.
        PROGRAM-ID. BankingApp.
       *> Author: COBOL Modernization Series

       *>==================================================================*
       *> Module 1-4 Capstone: Enterprise Core Banking & Ledger Engine     *
       *> (Starter Challenge Implementation)                               *
       *>                                                                  *
       *> Challenge Overview:                                              *
       *> 1. TODO 1: Implement atomic transaction seeding in 2500.         *
       *> 2. TODO 2: Implement hardware indexing batch loop in 3500.       *
       *> 3. TODO 3: Implement resilient math & overdraft checks in 3600.  *
       *> 4. TODO 4: Implement cursor stepping & report in 4000.           *
       *>                                                                  *
       *> Command: cobc -Wall -Wextra -x -free BankingApp.cob              *
       *>               cob_sqlite.c -lsqlite3 -o BankingApp               *
       *> Debug:   cobc -x -free -fdebugging-line BankingApp.cob           *
       *>               cob_sqlite.c -lsqlite3 -o BankingApp_Debug         *
       *>==================================================================*

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        COPY "SQLITE.CPY".
        COPY "BANKING.CPY".

       *> Extracted Cursor Columns (01-level items for safe C bridge linkage)
        01  Q-ACC-ID                  PIC S9(9) COMP-5.
        01  Q-HOLDER-NAME             PIC X(25).
        01  Q-ACC-TYPE                PIC X(12).
        01  Q-ACC-BAL-DBL             USAGE COMP-2 SYNC.
        01  Q-ACC-BAL-DEC             PIC S9(9)V99 COMP-3.
        01  Q-ACC-STATUS              PIC X(10).

       *> Single Account Query Variables
        01  LK-BALANCE-DBL            USAGE COMP-2 SYNC.
        01  LK-BALANCE-DEC            PIC S9(9)V99 COMP-3.
        01  LK-FOUND                  PIC X VALUE "N".

       *> SQL String Conversion Buffers (Module 1 / Module 3 Data Mapping)
        01  STR-ACC-ID                PIC 9(9).
        01  STR-TXN-ID                PIC 9(9).
        01  STR-AMOUNT                PIC 9(7).99.
        01  STR-BALANCE               PIC -(9)9.99.

       *> Arithmetic & Control Variables (Module 4 Performance Tuning)
        01  WS-NEW-BALANCE            PIC S9(9)V99 COMP-3 VALUE 0.
        01  WS-CALC-OVERFLOW          PIC X VALUE "N".
        01  WS-TOTAL-ASSETS           PIC S9(11)V99 COMP-3 VALUE 0.
        01  WS-ACC-COUNT              PIC 9(4) COMP-5 VALUE 0.
        01  WS-TXN-SUCCESS            PIC 9(4) COMP-5 VALUE 0.
        01  WS-TXN-REJECTED           PIC 9(4) COMP-5 VALUE 0.

       *> Formatted Output Helpers
        01  DISP-COUNT                PIC 9(4).
        01  DISP-NEW-BAL              PIC $$$$,$$$,$$9.99.

        PROCEDURE DIVISION.
        0000-MAIN.
            DISPLAY "=====================================================================" END-DISPLAY
            DISPLAY "     ENTERPRISE CORE BANKING & TRANSACTION PROCESSING ENGINE         " END-DISPLAY
            DISPLAY "=====================================================================" END-DISPLAY

            PERFORM 1000-CONNECT-DB
            PERFORM 2000-INIT-SCHEMA
            PERFORM 2500-SEED-ACCOUNTS
            PERFORM 3000-LOAD-BATCH-PAYLOAD
            PERFORM 3500-PROCESS-BATCH-TXNS
            PERFORM 4000-QUERY-LEDGER
            PERFORM 5000-CLEANUP

            DISPLAY "=====================================================================" END-DISPLAY
            DISPLAY "Banking engine operations completed." END-DISPLAY
            MOVE 0 TO RETURN-CODE
            STOP RUN.

        1000-CONNECT-DB.
            DISPLAY "[INFO] Connecting to SQLite database 'bank_master.db'..." END-DISPLAY
            MOVE "bank_master.db" TO SQL-STATEMENT
            CALL "cob_sqlite_open" USING
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQLITE-STATUS
            END-CALL

            IF NOT SQL-OK
                DISPLAY "[ERROR] Could not open database. Code: " SQLITE-STATUS END-DISPLAY
                MOVE 1 TO RETURN-CODE
                STOP RUN
            END-IF
            DISPLAY "[INFO] Connected successfully." END-DISPLAY
            DISPLAY " " END-DISPLAY.

        2000-INIT-SCHEMA.
            DISPLAY "[INFO] Initializing banking database schema..." END-DISPLAY
            
            MOVE "CREATE TABLE IF NOT EXISTS accounts (account_id INT PRIMARY KEY, holder_name TEXT, account_type TEXT, balance REAL, status TEXT);"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                DISPLAY "[ERROR] Failed creating accounts table: " SQLITE-STATUS END-DISPLAY
                PERFORM 5000-CLEANUP
                MOVE 1 TO RETURN-CODE
                STOP RUN
            END-IF

            MOVE "CREATE TABLE IF NOT EXISTS transactions (txn_id INT PRIMARY KEY, account_id INT, txn_type TEXT, amount REAL, txn_timestamp TEXT);"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                DISPLAY "[ERROR] Failed creating transactions table: " SQLITE-STATUS END-DISPLAY
                PERFORM 5000-CLEANUP
                MOVE 1 TO RETURN-CODE
                STOP RUN
            END-IF

            MOVE "DELETE FROM transactions;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL

            MOVE "DELETE FROM accounts;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL

            DISPLAY "[INFO] Schema initialized cleanly." END-DISPLAY
            DISPLAY " " END-DISPLAY.

        2500-SEED-ACCOUNTS.
            DISPLAY "[INFO] Seeding initial customer accounts in atomic transaction..." END-DISPLAY

           *>------------------------------------------------------------------*
           *> TODO 1: Wrap initial seed inserts inside an atomic SQLite        *
           *>         transaction (BEGIN TRANSACTION / COMMIT).                *
           *>         If any insert fails, PERFORM 2900-ROLLBACK-AND-ABORT.    *
           *>------------------------------------------------------------------*

           *> >>> YOUR CODE HERE: BEGIN TRANSACTION <<<

            MOVE "INSERT INTO accounts VALUES (1001, 'Alice Jenkins', 'CHECKING', 9500.00, 'ACTIVE');"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL

            MOVE "INSERT INTO accounts VALUES (1002, 'Bob Rodriguez', 'SAVINGS', 2500.00, 'ACTIVE');"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL

            MOVE "INSERT INTO accounts VALUES (1003, 'Acme Corp Enterprise', 'CORPORATE', 150000.00, 'ACTIVE');"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL

           *> >>> YOUR CODE HERE: COMMIT TRANSACTION & ERROR CHECKING <<<

            DISPLAY "[INFO] 3 master accounts seeded." END-DISPLAY
            DISPLAY " " END-DISPLAY.

        2900-ROLLBACK-AND-ABORT.
            DISPLAY "[ERROR] Seed operation failed. Rolling back..." END-DISPLAY
            MOVE "ROLLBACK;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL
            PERFORM 5000-CLEANUP
            MOVE 1 TO RETURN-CODE
            STOP RUN.

        3000-LOAD-BATCH-PAYLOAD.
            DISPLAY "[INFO] Loading batch transaction payload into indexed memory table..." END-DISPLAY

            SET TXN-IDX TO 1
            MOVE 501 TO B-TXN-ID (TXN-IDX)
            MOVE 1001 TO B-ACC-ID (TXN-IDX)
            MOVE "CREDIT" TO B-TYPE (TXN-IDX)
            MOVE 1500.00 TO B-AMOUNT (TXN-IDX)
            MOVE "2026-09-09 09:00:00" TO B-TIMESTAMP (TXN-IDX)

            SET TXN-IDX TO 2
            MOVE 502 TO B-TXN-ID (TXN-IDX)
            MOVE 1002 TO B-ACC-ID (TXN-IDX)
            MOVE "DEBIT" TO B-TYPE (TXN-IDX)
            MOVE 500.00 TO B-AMOUNT (TXN-IDX)
            MOVE "2026-09-09 09:05:00" TO B-TIMESTAMP (TXN-IDX)

            SET TXN-IDX TO 3
            MOVE 503 TO B-TXN-ID (TXN-IDX)
            MOVE 1002 TO B-ACC-ID (TXN-IDX)
            MOVE "DEBIT" TO B-TYPE (TXN-IDX)
            MOVE 5000.00 TO B-AMOUNT (TXN-IDX)
            MOVE "2026-09-09 09:10:00" TO B-TIMESTAMP (TXN-IDX)

            SET TXN-IDX TO 4
            MOVE 504 TO B-TXN-ID (TXN-IDX)
            MOVE 1003 TO B-ACC-ID (TXN-IDX)
            MOVE "CREDIT" TO B-TYPE (TXN-IDX)
            MOVE 25000.00 TO B-AMOUNT (TXN-IDX)
            MOVE "2026-09-09 09:15:00" TO B-TIMESTAMP (TXN-IDX)

            SET TXN-IDX TO 5
            MOVE 505 TO B-TXN-ID (TXN-IDX)
            MOVE 1001 TO B-ACC-ID (TXN-IDX)
            MOVE "DEBIT" TO B-TYPE (TXN-IDX)
            MOVE 10000.00 TO B-AMOUNT (TXN-IDX)
            MOVE "2026-09-09 09:20:00" TO B-TIMESTAMP (TXN-IDX)

            DISPLAY "[INFO] 5 batch transactions loaded." END-DISPLAY
            DISPLAY " " END-DISPLAY.

        3500-PROCESS-BATCH-TXNS.
            DISPLAY "[INFO] Processing batch transactions with ACID verification..." END-DISPLAY

           *>------------------------------------------------------------------*
           *> TODO 2: Traverse BATCH-TRANSACTION-TABLE using the hardware index*
           *>         TXN-IDX (Module 4 optimization). Loop from 1 to 5.       *
           *>------------------------------------------------------------------*

           *> >>> YOUR CODE HERE: PERFORM 3600-EXECUTE-SINGLE-TXN ... <<<

            DISPLAY "[INFO] Batch transaction processing completed." END-DISPLAY
            DISPLAY " " END-DISPLAY.

        3600-EXECUTE-SINGLE-TXN.
           *> Conditional debug line (Module 4)
            >>D DISPLAY "[DEBUG] Evaluating Txn " B-TXN-ID (TXN-IDX) " for Acc " B-ACC-ID (TXN-IDX) END-DISPLAY

            PERFORM 3700-LOOKUP-ACCOUNT-BALANCE

            IF LK-FOUND = "N"
                MOVE B-TXN-ID (TXN-IDX) TO STR-TXN-ID
                MOVE B-ACC-ID (TXN-IDX) TO STR-ACC-ID
                DISPLAY "  [TXN " STR-TXN-ID "] Account " STR-ACC-ID " not found! Skipping." END-DISPLAY
                ADD 1 TO WS-TXN-REJECTED END-ADD
                EXIT PARAGRAPH
            END-IF

           *>------------------------------------------------------------------*
           *> TODO 3: Resilient Balance Calculation & Overdraft Defense:       *
           *>   - For CREDIT: Add B-AMOUNT to LK-BALANCE-DEC with ON SIZE ERROR*
           *>   - For DEBIT: Check LK-BALANCE-DEC >= B-AMOUNT.                 *
           *>     If insufficient: Display rejection and ADD 1 TO WS-TXN-REJECT*
           *>     If sufficient: Subtract with ON SIZE ERROR                   *
           *>   - If arithmetic overflow occurs: Display error & reject.       *
           *>   - If valid: PERFORM 3800-COMMIT-TXN-UPDATE                     *
           *>------------------------------------------------------------------*

           *> >>> YOUR CODE HERE: IMPLEMENT CREDIT/DEBIT LOGIC & SAFETY <<<

            .

        3700-LOOKUP-ACCOUNT-BALANCE.
            MOVE "N" TO LK-FOUND
            MOVE B-ACC-ID (TXN-IDX) TO STR-ACC-ID
            INITIALIZE SQL-STATEMENT
            STRING "SELECT balance FROM accounts WHERE account_id = " 
                   FUNCTION TRIM(STR-ACC-ID) ";"
                INTO SQL-STATEMENT
            END-STRING

            CALL "cob_sqlite_prepare" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE STMT-HANDLE
                BY REFERENCE SQLITE-STATUS
            END-CALL

            IF SQL-OK
                CALL "cob_sqlite_step" USING
                    BY REFERENCE STMT-HANDLE
                    BY REFERENCE SQLITE-STATUS
                END-CALL

                IF SQL-ROW
                    CALL "cob_sqlite_get_double" USING
                        BY REFERENCE STMT-HANDLE
                        BY VALUE 0
                        BY REFERENCE LK-BALANCE-DBL
                    END-CALL
                    COMPUTE LK-BALANCE-DEC ROUNDED = LK-BALANCE-DBL END-COMPUTE
                    MOVE "Y" TO LK-FOUND
                END-IF

                CALL "cob_sqlite_finalize" USING
                    BY REFERENCE STMT-HANDLE
                    BY REFERENCE SQLITE-STATUS
                END-CALL
            END-IF.

        3800-COMMIT-TXN-UPDATE.
           *> Execute balance update and audit logging inside atomic transaction
            MOVE "BEGIN TRANSACTION;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL

           *> 1. Update Account balance
            MOVE B-ACC-ID (TXN-IDX) TO STR-ACC-ID
            MOVE WS-NEW-BALANCE TO STR-BALANCE
            INITIALIZE SQL-STATEMENT
            STRING "UPDATE accounts SET balance = " FUNCTION TRIM(STR-BALANCE) 
                   " WHERE account_id = " FUNCTION TRIM(STR-ACC-ID) ";"
                INTO SQL-STATEMENT
            END-STRING
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL

           *> 2. Insert into transactions table
            MOVE B-TXN-ID (TXN-IDX) TO STR-TXN-ID
            MOVE B-AMOUNT (TXN-IDX) TO STR-AMOUNT
            INITIALIZE SQL-STATEMENT
            STRING "INSERT INTO transactions VALUES (" FUNCTION TRIM(STR-TXN-ID) ", " 
                   FUNCTION TRIM(STR-ACC-ID) ", '" FUNCTION TRIM(B-TYPE (TXN-IDX)) "', " 
                   FUNCTION TRIM(STR-AMOUNT) ", '" FUNCTION TRIM(B-TIMESTAMP (TXN-IDX)) "');"
                INTO SQL-STATEMENT
            END-STRING
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL

            MOVE "COMMIT;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL

            ADD 1 TO WS-TXN-SUCCESS END-ADD
            MOVE WS-NEW-BALANCE TO DISP-NEW-BAL
            DISPLAY "  [TXN " STR-TXN-ID "] " B-TYPE (TXN-IDX) " " DISP-AMOUNT 
                    " to Acc " STR-ACC-ID 
                    " -> SUCCESS (New Bal: " DISP-NEW-BAL ")" END-DISPLAY.

        4000-QUERY-LEDGER.
            DISPLAY "[INFO] Generating General Ledger Audit Report from SQLite cursor..." END-DISPLAY
            DISPLAY "-------------------------------------------------------------------------------------" END-DISPLAY
            DISPLAY "ACCOUNT ID | HOLDER NAME               | TYPE         | CURRENT BALANCE | STATUS     " END-DISPLAY
            DISPLAY "-------------------------------------------------------------------------------------" END-DISPLAY

           *>------------------------------------------------------------------*
           *> TODO 4: Prepare the cursor query:                                *
           *>         SELECT account_id, holder_name, account_type, balance,   *
           *>                status FROM accounts ORDER BY account_id;         *
           *>         Loop through cursor using cob_sqlite_step (SQL-ROW),     *
           *>         extract columns into Q-ACC-ID, Q-HOLDER-NAME, etc.,      *
           *>         accumulate total bank assets, and display each row.      *
           *>         Finalize statement with cob_sqlite_finalize.             *
           *>------------------------------------------------------------------*

           *> >>> YOUR CODE HERE: CURSOR QUERY, LOOP & AGGREGATION <<<

            DISPLAY "-------------------------------------------------------------------------------------" END-DISPLAY
            DISPLAY " " END-DISPLAY.

        5000-CLEANUP.
            IF DB-HANDLE NOT = NULL
                DISPLAY "[INFO] Closing database connection..." END-DISPLAY
                CALL "cob_sqlite_close" USING
                    BY REFERENCE DB-HANDLE
                    BY REFERENCE SQLITE-STATUS
                END-CALL
                IF SQL-OK
                    DISPLAY "[INFO] Database closed cleanly." END-DISPLAY
                ELSE
                    DISPLAY "[WARN] Database close returned status: " SQLITE-STATUS END-DISPLAY
                END-IF
            END-IF.

