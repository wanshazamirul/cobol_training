        >>SOURCE FORMAT FREE
        IDENTIFICATION DIVISION.
        PROGRAM-ID. BankingApp.
       *> Author: COBOL Modernization Series

       *>==================================================================*
       *> Module 1-4 Capstone: Enterprise Core Banking & Ledger Engine     *
       *> Integrates:                                                      *
       *> - Module 1: Free-format, copybooks, edited numeric displays      *
       *> - Module 2: Modular business logic & status transitions          *
       *> - Module 3: SQLite relational storage & ACID transactions        *
       *> - Module 4: Hardware indexing, COMP-3/5, ON SIZE ERROR, >>D      *
       *>                                                                  *
       *> Command: cobc -x -free BankingApp.cob cob_sqlite.c -lsqlite3     *
       *> Debug:   cobc -x -free -debug BankingApp.cob cob_sqlite.c        *
       *>               -lsqlite3 -o BankingApp_Debug                      *
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
            DISPLAY "Banking engine operations completed successfully." END-DISPLAY
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

            MOVE "BEGIN TRANSACTION;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                DISPLAY "[ERROR] Failed starting seed transaction: " SQLITE-STATUS END-DISPLAY
                PERFORM 5000-CLEANUP
                MOVE 1 TO RETURN-CODE
                STOP RUN
            END-IF

            MOVE "INSERT INTO accounts VALUES (1001, 'Alice Jenkins', 'CHECKING', 9500.00, 'ACTIVE');"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                PERFORM 2900-ROLLBACK-AND-ABORT
            END-IF

            MOVE "INSERT INTO accounts VALUES (1002, 'Bob Rodriguez', 'SAVINGS', 2500.00, 'ACTIVE');"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                PERFORM 2900-ROLLBACK-AND-ABORT
            END-IF

            MOVE "INSERT INTO accounts VALUES (1003, 'Acme Corp Enterprise', 'CORPORATE', 150000.00, 'ACTIVE');"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                PERFORM 2900-ROLLBACK-AND-ABORT
            END-IF

            MOVE "COMMIT;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                PERFORM 2900-ROLLBACK-AND-ABORT
            END-IF

            DISPLAY "[INFO] 3 master accounts seeded successfully." END-DISPLAY
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
            PERFORM 3600-EXECUTE-SINGLE-TXN VARYING TXN-IDX FROM 1 BY 1 UNTIL TXN-IDX > 5
            DISPLAY "[INFO] Batch transaction processing completed." END-DISPLAY
            DISPLAY " " END-DISPLAY.

        3600-EXECUTE-SINGLE-TXN.
           *> Conditional debug line (Module 4)
            >>D DISPLAY "[DEBUG] Evaluating Txn " B-TXN-ID (TXN-IDX) " for Acc " B-ACC-ID (TXN-IDX) END-DISPLAY

           *> 1. Query current balance from SQLite
            PERFORM 3700-LOOKUP-ACCOUNT-BALANCE

            IF LK-FOUND = "N"
                MOVE B-TXN-ID (TXN-IDX) TO STR-TXN-ID
                MOVE B-ACC-ID (TXN-IDX) TO STR-ACC-ID
                DISPLAY "  [TXN " STR-TXN-ID "] Account " STR-ACC-ID " not found! Skipping." END-DISPLAY
                ADD 1 TO WS-TXN-REJECTED END-ADD
                EXIT PARAGRAPH
            END-IF

           *> 2. Evaluate business rules & perform calculations
            MOVE B-AMOUNT (TXN-IDX) TO DISP-AMOUNT
            MOVE B-TXN-ID (TXN-IDX) TO STR-TXN-ID
            MOVE B-ACC-ID (TXN-IDX) TO STR-ACC-ID

            IF B-TYPE (TXN-IDX) = "CREDIT"
                MOVE "N" TO WS-CALC-OVERFLOW
                ADD B-AMOUNT (TXN-IDX) TO LK-BALANCE-DEC GIVING WS-NEW-BALANCE
                    ON SIZE ERROR
                        MOVE "Y" TO WS-CALC-OVERFLOW
                END-ADD

                IF WS-CALC-OVERFLOW = "Y"
                    DISPLAY "  [TXN " STR-TXN-ID "] REJECTED: Arithmetic capacity overflow!" END-DISPLAY
                    ADD 1 TO WS-TXN-REJECTED END-ADD
                    EXIT PARAGRAPH
                END-IF

                PERFORM 3800-COMMIT-TXN-UPDATE
            ELSE
                IF B-TYPE (TXN-IDX) = "DEBIT"
                    IF LK-BALANCE-DEC < B-AMOUNT (TXN-IDX)
                        DISPLAY "  [TXN " STR-TXN-ID "] DEBIT  " DISP-AMOUNT 
                                " from Acc " STR-ACC-ID 
                                " -> REJECTED: Insufficient Funds (Overdraft Blocked)" END-DISPLAY
                        ADD 1 TO WS-TXN-REJECTED END-ADD
                        EXIT PARAGRAPH
                    END-IF

                    MOVE "N" TO WS-CALC-OVERFLOW
                    SUBTRACT B-AMOUNT (TXN-IDX) FROM LK-BALANCE-DEC GIVING WS-NEW-BALANCE
                        ON SIZE ERROR
                            MOVE "Y" TO WS-CALC-OVERFLOW
                    END-SUBTRACT

                    IF WS-CALC-OVERFLOW = "Y"
                        DISPLAY "  [TXN " STR-TXN-ID "] REJECTED: Arithmetic capacity overflow!" END-DISPLAY
                        ADD 1 TO WS-TXN-REJECTED END-ADD
                        EXIT PARAGRAPH
                    END-IF

                    PERFORM 3800-COMMIT-TXN-UPDATE
                END-IF
            END-IF.

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

            MOVE "SELECT account_id, holder_name, account_type, balance, status FROM accounts ORDER BY account_id;"
                TO SQL-STATEMENT
            CALL "cob_sqlite_prepare" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE STMT-HANDLE
                BY REFERENCE SQLITE-STATUS
            END-CALL

            IF NOT SQL-OK
                DISPLAY "[ERROR] Cursor preparation failed: " SQLITE-STATUS END-DISPLAY
                PERFORM 5000-CLEANUP
                MOVE 1 TO RETURN-CODE
                STOP RUN
            END-IF

            PERFORM FOREVER
                CALL "cob_sqlite_step" USING
                    BY REFERENCE STMT-HANDLE
                    BY REFERENCE SQLITE-STATUS
                END-CALL

                IF SQL-ROW
                    CALL "cob_sqlite_get_int" USING
                        BY REFERENCE STMT-HANDLE
                        BY VALUE 0
                        BY REFERENCE Q-ACC-ID
                    END-CALL

                    CALL "cob_sqlite_get_text" USING
                        BY REFERENCE STMT-HANDLE
                        BY VALUE 1
                        BY REFERENCE Q-HOLDER-NAME
                        BY VALUE 25
                    END-CALL

                    CALL "cob_sqlite_get_text" USING
                        BY REFERENCE STMT-HANDLE
                        BY VALUE 2
                        BY REFERENCE Q-ACC-TYPE
                        BY VALUE 12
                    END-CALL

                    CALL "cob_sqlite_get_double" USING
                        BY REFERENCE STMT-HANDLE
                        BY VALUE 3
                        BY REFERENCE Q-ACC-BAL-DBL
                    END-CALL

                    CALL "cob_sqlite_get_text" USING
                        BY REFERENCE STMT-HANDLE
                        BY VALUE 4
                        BY REFERENCE Q-ACC-STATUS
                        BY VALUE 10
                    END-CALL

                    COMPUTE Q-ACC-BAL-DEC ROUNDED = Q-ACC-BAL-DBL END-COMPUTE
                    ADD 1 TO WS-ACC-COUNT END-ADD
                    ADD Q-ACC-BAL-DEC TO WS-TOTAL-ASSETS END-ADD

                    MOVE Q-ACC-ID TO DISP-ACC-ID
                    MOVE Q-ACC-BAL-DEC TO DISP-BALANCE
                    DISPLAY DISP-ACC-ID " | " Q-HOLDER-NAME " | " Q-ACC-TYPE " | " DISP-BALANCE " | " Q-ACC-STATUS
                    END-DISPLAY
                ELSE
                    IF NOT SQL-DONE
                        DISPLAY "[ERROR] Cursor error during fetch: " SQLITE-STATUS END-DISPLAY
                        CALL "cob_sqlite_finalize" USING
                            BY REFERENCE STMT-HANDLE
                            BY REFERENCE SQLITE-STATUS
                        END-CALL
                        PERFORM 5000-CLEANUP
                        MOVE 1 TO RETURN-CODE
                        STOP RUN
                    END-IF
                    EXIT PERFORM
                END-IF
            END-PERFORM

            CALL "cob_sqlite_finalize" USING
                BY REFERENCE STMT-HANDLE
                BY REFERENCE SQLITE-STATUS
            END-CALL

            MOVE WS-ACC-COUNT TO DISP-COUNT
            MOVE WS-TOTAL-ASSETS TO DISP-TOTAL-ASSETS

            DISPLAY "-------------------------------------------------------------------------------------" END-DISPLAY
            DISPLAY "Total Accounts Active : " DISP-COUNT END-DISPLAY
            DISPLAY "Total Ledger Assets   : " DISP-TOTAL-ASSETS END-DISPLAY
            MOVE WS-TXN-SUCCESS TO DISP-COUNT
            DISPLAY "Processed Moves Count : " DISP-COUNT END-DISPLAY
            MOVE WS-TXN-REJECTED TO DISP-COUNT
            DISPLAY "Rejected Moves Count  : " DISP-COUNT END-DISPLAY
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

