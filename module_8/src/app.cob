       >>SOURCE FORMAT FREE
       IDENTIFICATION DIVISION.
       PROGRAM-ID. InventoryApp.
      *>==================================================================*
      *> Module 8: CI/CD Training with SQLite & GitHub Actions            *
      *> Application: Enterprise Inventory Tracker                        *
      *>                                                                  *
      *> Purpose:                                                         *
      *>   1. Connect to SQLite database 'inventory.db'                   *
      *>   2. Create table schema if not present                          *
      *>   3. Seed inventory items within an atomic transaction           *
      *>   4. Query items via cursor step & compute inventory valuation   *
      *>   5. Return exit code 0 on success (or non-zero on failure)      *
      *>      for automated CI/CD pipeline verification                   *
      *>==================================================================*

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "SQLITE.CPY".

      *> Record Fields
       01  ITEM-ID                       PIC S9(9) COMP-5 VALUE 0.
       01  ITEM-SKU                      PIC X(12) VALUE SPACES.
       01  ITEM-NAME                     PIC X(25) VALUE SPACES.
       01  ITEM-QTY                      PIC S9(9) COMP-5 VALUE 0.
       01  ITEM-PRICE                    USAGE COMP-2.

      *> Computed Totals & Metrics
       01  WS-RECORD-COUNT               PIC S9(9) COMP-5 VALUE 0.
       01  WS-TOTAL-QTY                  PIC S9(9) COMP-5 VALUE 0.
       01  WS-LINE-VALUE                 USAGE COMP-2 VALUE 0.0.
       01  WS-TOTAL-VALUATION            USAGE COMP-2 VALUE 0.0.

      *> Display Formatted Variables
       01  DISP-ID                       PIC ZZZ9.
       01  DISP-QTY                      PIC ZZZ,ZZ9.
       01  DISP-PRICE                    PIC $$$,$$9.99.
       01  DISP-LINE-VAL                 PIC $$$$,$$9.99.
       01  DISP-TOTAL-VAL                PIC $$$$,$$$,$$9.99.
       01  DISP-TOTAL-QTY                PIC ZZZ,ZZ9.
       01  DISP-COUNT                    PIC ZZZ9.

       PROCEDURE DIVISION.
       0000-MAIN.
           DISPLAY "================================================================"
           DISPLAY "      ENTERPRISE INVENTORY SYSTEM (COBOL + SQLITE3)             "
           DISPLAY "               CI/CD AUTOMATED BUILD TARGET                     "
           DISPLAY "================================================================"

           PERFORM 1000-OPEN-DB
           PERFORM 2000-INIT-SCHEMA
           PERFORM 3000-SEED-DATA
           PERFORM 4000-REPORT-INVENTORY
           PERFORM 5000-CLOSE-DB

      *> Verify that processing succeeded and records were handled
           IF WS-RECORD-COUNT < 3
               DISPLAY "[ASSERTION FAIL] Expected at least 3 records, got: " WS-RECORD-COUNT
               MOVE 2 TO RETURN-CODE
               STOP RUN
           END-IF

           DISPLAY "================================================================"
           DISPLAY " [STATUS: SUCCESS] Pipeline verification target passed."
           DISPLAY "================================================================"
           MOVE 0 TO RETURN-CODE
           STOP RUN.

       1000-OPEN-DB.
           DISPLAY "[INFO] Opening SQLite database: inventory.db"
           MOVE "inventory.db" TO SQL-STATEMENT
           CALL "cob_sqlite_open" USING
               BY REFERENCE SQL-STATEMENT
               BY REFERENCE DB-HANDLE
               BY REFERENCE SQLITE-STATUS
           END-CALL

           IF NOT SQL-OK
               DISPLAY "[FATAL] Failed to open database. Status: " SQLITE-STATUS
               MOVE 1 TO RETURN-CODE
               STOP RUN
           END-IF
           DISPLAY "[INFO] Database connection established successfully.".

       2000-INIT-SCHEMA.
           DISPLAY "[INFO] Initializing inventory schema..."
           MOVE "CREATE TABLE IF NOT EXISTS inventory (id INTEGER PRIMARY KEY, sku TEXT, name TEXT, quantity INTEGER, price REAL);"
               TO SQL-STATEMENT
           CALL "cob_sqlite_exec" USING
               BY REFERENCE DB-HANDLE
               BY REFERENCE SQL-STATEMENT
               BY REFERENCE SQLITE-STATUS
           END-CALL

           IF NOT SQL-OK
               DISPLAY "[FATAL] DDL table creation failed. Status: " SQLITE-STATUS
               PERFORM 5000-CLOSE-DB
               MOVE 1 TO RETURN-CODE
               STOP RUN
           END-IF

      *> Clean existing data for deterministic test runs
           MOVE "DELETE FROM inventory;" TO SQL-STATEMENT
           CALL "cob_sqlite_exec" USING
               BY REFERENCE DB-HANDLE
               BY REFERENCE SQL-STATEMENT
               BY REFERENCE SQLITE-STATUS
           END-CALL

           IF NOT SQL-OK
               DISPLAY "[FATAL] Table truncate failed. Status: " SQLITE-STATUS
               PERFORM 5000-CLOSE-DB
               MOVE 1 TO RETURN-CODE
               STOP RUN
           END-IF
           DISPLAY "[INFO] Schema initialized and purged.".

       3000-SEED-DATA.
           DISPLAY "[INFO] Seeding inventory records via transaction..."
           
           MOVE "BEGIN TRANSACTION;" TO SQL-STATEMENT
           CALL "cob_sqlite_exec" USING
               BY REFERENCE DB-HANDLE
               BY REFERENCE SQL-STATEMENT
               BY REFERENCE SQLITE-STATUS
           END-CALL
           IF NOT SQL-OK
               DISPLAY "[FATAL] Failed to begin transaction. Status: " SQLITE-STATUS
               PERFORM 5000-CLOSE-DB
               MOVE 1 TO RETURN-CODE
               STOP RUN
           END-IF

      *> Record 1
           MOVE "INSERT INTO inventory VALUES (101, 'SRV-DL380', 'Rack Server Gen10', 12, 2850.00);" 
               TO SQL-STATEMENT
           CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS END-CALL
           IF NOT SQL-OK GO TO 3900-SEED-ERROR END-IF

      *> Record 2
           MOVE "INSERT INTO inventory VALUES (102, 'SW-CAT9300', 'Gigabit Switch 48-Port', 8, 1450.50);" 
               TO SQL-STATEMENT
           CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS END-CALL
           IF NOT SQL-OK GO TO 3900-SEED-ERROR END-IF

      *> Record 3
           MOVE "INSERT INTO inventory VALUES (103, 'STOR-SAN8T', 'SAN Storage Array 8TB', 4, 5200.75);" 
               TO SQL-STATEMENT
           CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS END-CALL
           IF NOT SQL-OK GO TO 3900-SEED-ERROR END-IF

      *> Record 4
           MOVE "INSERT INTO inventory VALUES (104, 'PWR-UPS3000', 'Online UPS 3000VA', 15, 620.00);" 
               TO SQL-STATEMENT
           CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS END-CALL
           IF NOT SQL-OK GO TO 3900-SEED-ERROR END-IF

      *> Commit
           MOVE "COMMIT;" TO SQL-STATEMENT
           CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS END-CALL
           IF NOT SQL-OK
               DISPLAY "[FATAL] Commit failed. Status: " SQLITE-STATUS
               PERFORM 5000-CLOSE-DB
               MOVE 1 TO RETURN-CODE
               STOP RUN
           END-IF

           DISPLAY "[INFO] 4 inventory records seeded successfully."
           EXIT PARAGRAPH.

       3900-SEED-ERROR.
           DISPLAY "[FATAL] Seeding record failed. Rolling back..."
           MOVE "ROLLBACK;" TO SQL-STATEMENT
           CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS END-CALL
           PERFORM 5000-CLOSE-DB
           MOVE 1 TO RETURN-CODE
           STOP RUN.

       4000-REPORT-INVENTORY.
           DISPLAY " "
           DISPLAY "----------------------------------------------------------------"
           DISPLAY " ID   SKU          ITEM DESCRIPTION          QTY    UNIT PRICE   EXT VALUE"
           DISPLAY "----------------------------------------------------------------"

           MOVE "SELECT id, sku, name, quantity, price FROM inventory ORDER BY id ASC;"
               TO SQL-STATEMENT
           CALL "cob_sqlite_prepare" USING
               BY REFERENCE DB-HANDLE
               BY REFERENCE SQL-STATEMENT
               BY REFERENCE STMT-HANDLE
               BY REFERENCE SQLITE-STATUS
           END-CALL

           IF NOT SQL-OK
               DISPLAY "[FATAL] Cursor preparation failed. Status: " SQLITE-STATUS
               PERFORM 5000-CLOSE-DB
               MOVE 1 TO RETURN-CODE
               STOP RUN
           END-IF

           MOVE 0 TO WS-RECORD-COUNT
           MOVE 0 TO WS-TOTAL-QTY
           MOVE 0.0 TO WS-TOTAL-VALUATION

           PERFORM UNTIL 1 = 0
               CALL "cob_sqlite_step" USING
                   BY REFERENCE STMT-HANDLE
                   BY REFERENCE SQLITE-STATUS
               END-CALL

               IF SQL-ROW
                   ADD 1 TO WS-RECORD-COUNT

                   CALL "cob_sqlite_get_int" USING
                       BY REFERENCE STMT-HANDLE
                       BY VALUE 0
                       BY REFERENCE ITEM-ID
                   END-CALL

                   CALL "cob_sqlite_get_text" USING
                       BY REFERENCE STMT-HANDLE
                       BY VALUE 1
                       BY REFERENCE ITEM-SKU
                       BY VALUE 12
                   END-CALL

                   CALL "cob_sqlite_get_text" USING
                       BY REFERENCE STMT-HANDLE
                       BY VALUE 2
                       BY REFERENCE ITEM-NAME
                       BY VALUE 25
                   END-CALL

                   CALL "cob_sqlite_get_int" USING
                       BY REFERENCE STMT-HANDLE
                       BY VALUE 3
                       BY REFERENCE ITEM-QTY
                   END-CALL

                   CALL "cob_sqlite_get_double" USING
                       BY REFERENCE STMT-HANDLE
                       BY VALUE 4
                       BY REFERENCE ITEM-PRICE
                   END-CALL

      *> Compute line totals
                   COMPUTE WS-LINE-VALUE = ITEM-QTY * ITEM-PRICE
                   ADD ITEM-QTY TO WS-TOTAL-QTY
                   COMPUTE WS-TOTAL-VALUATION = WS-TOTAL-VALUATION + WS-LINE-VALUE

      *> Format for display
                   MOVE ITEM-ID TO DISP-ID
                   MOVE ITEM-QTY TO DISP-QTY
                   MOVE ITEM-PRICE TO DISP-PRICE
                   MOVE WS-LINE-VALUE TO DISP-LINE-VAL

                   DISPLAY DISP-ID "  " ITEM-SKU " " ITEM-NAME " " DISP-QTY " " DISP-PRICE " " DISP-LINE-VAL
               ELSE
                   EXIT PERFORM
               END-IF
           END-PERFORM

           CALL "cob_sqlite_finalize" USING
               BY REFERENCE STMT-HANDLE
               BY REFERENCE SQLITE-STATUS
           END-CALL

           DISPLAY "----------------------------------------------------------------"
           MOVE WS-RECORD-COUNT TO DISP-COUNT
           MOVE WS-TOTAL-QTY TO DISP-TOTAL-QTY
           MOVE WS-TOTAL-VALUATION TO DISP-TOTAL-VAL
           DISPLAY "TOTAL ITEMS: " DISP-COUNT " | TOTAL UNITS: " DISP-TOTAL-QTY 
                   " | TOTAL VALUE: " DISP-TOTAL-VAL
           DISPLAY "----------------------------------------------------------------"
           DISPLAY " ".

       5000-CLOSE-DB.
           IF DB-HANDLE NOT = NULL
               CALL "cob_sqlite_close" USING
                   BY REFERENCE DB-HANDLE
                   BY REFERENCE SQLITE-STATUS
               END-CALL
               SET DB-HANDLE TO NULL
           END-IF.

