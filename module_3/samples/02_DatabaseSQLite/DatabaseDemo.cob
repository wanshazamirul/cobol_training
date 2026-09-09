        >>SOURCE FORMAT FREE
        IDENTIFICATION DIVISION.
        PROGRAM-ID. DatabaseDemo.
       *> Author: COBOL Modernization Series

       *>==================================================================*
       *> Demonstrates SQLite3 relational database integration             *
       *> with GnuCOBOL using a type-safe C bridge.                        *
       *> Covers:                                                          *
       *> 1. Connecting to SQLite file                                     *
       *> 2. DDL Table Creation                                            *
       *> 3. Parameterized / Transactional INSERT statements               *
       *> 4. SELECT Cursor Step traversal                                  *
       *> 5. Aggregation and Data Formatting                               *
       *> 6. Finalization and Connection Cleanup                           *
       *>                                                                  *
       *> Command: cobc -x -free DatabaseDemo.cob cob_sqlite.c -lsqlite3   *
       *>==================================================================*

        DATA DIVISION.
        WORKING-STORAGE SECTION.
        COPY "SQLITE.CPY".

       *> Record Variables (01-level items for type-safe C-bridge linkage)
        01  EMP-ID                    PIC S9(9) COMP-5.
        01  EMP-NAME                  PIC X(20).
        01  EMP-DEPT                  PIC X(15).
        01  EMP-SALARY-DBL            USAGE COMP-2 SYNC.
        01  EMP-SALARY-DEC            PIC 9(7)V99 COMP-3.

       *> Statistics & Display
        01  WS-TOTAL-SALARY           PIC 9(9)V99 VALUE 0.
        01  WS-EMP-COUNT              PIC 9(4) VALUE 0.
        01  WS-AVG-SALARY             PIC 9(7)V99 VALUE 0.

        01  DISP-EMP-ID               PIC ZZZZZZZZ9.
        01  DISP-SALARY               PIC $$$,$$$,$$9.99.
        01  DISP-TOTAL                PIC $$$$,$$$,$$9.99.
        01  DISP-AVG                  PIC $$$,$$$,$$9.99.

        PROCEDURE DIVISION.
        0000-MAIN.
            DISPLAY "==================================================" END-DISPLAY
            DISPLAY "     SQLITE3 RELATIONAL DATABASE CONNECTIVITY     " END-DISPLAY
            DISPLAY "==================================================" END-DISPLAY

            PERFORM 1000-CONNECT-DB
            PERFORM 2000-SETUP-SCHEMA
            PERFORM 3000-INSERT-EMPLOYEES
            PERFORM 4000-QUERY-EMPLOYEES
            PERFORM 5000-CLEANUP

            DISPLAY "==================================================" END-DISPLAY
            DISPLAY "Database operations completed successfully." END-DISPLAY
            MOVE 0 TO RETURN-CODE
            STOP RUN.

        1000-CONNECT-DB.
            DISPLAY "[INFO] Connecting to SQLite database 'company.db'..." END-DISPLAY
            MOVE "company.db" TO SQL-STATEMENT
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

        2000-SETUP-SCHEMA.
            DISPLAY "[INFO] Initializing schema..." END-DISPLAY
            MOVE "CREATE TABLE IF NOT EXISTS employees (id INT PRIMARY KEY, name TEXT, dept TEXT, salary REAL);"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL

            IF NOT SQL-OK
                DISPLAY "[ERROR] Table creation failed: " SQLITE-STATUS END-DISPLAY
                PERFORM 5000-CLEANUP
                MOVE 1 TO RETURN-CODE
                STOP RUN
            END-IF

            MOVE "DELETE FROM employees;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL

            IF NOT SQL-OK
                DISPLAY "[ERROR] Table truncation failed: " SQLITE-STATUS END-DISPLAY
                PERFORM 5000-CLEANUP
                MOVE 1 TO RETURN-CODE
                STOP RUN
            END-IF

            DISPLAY "[INFO] Schema ready and cleared." END-DISPLAY
            DISPLAY " " END-DISPLAY.

        3000-INSERT-EMPLOYEES.
            DISPLAY "[INFO] Inserting employee records in atomic transaction..." END-DISPLAY

            MOVE "BEGIN TRANSACTION;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                DISPLAY "[ERROR] Failed to start transaction: " SQLITE-STATUS END-DISPLAY
                PERFORM 5000-CLEANUP
                MOVE 1 TO RETURN-CODE
                STOP RUN
            END-IF

            MOVE "INSERT INTO employees VALUES (101, 'Alice Jenkins', 'Engineering', 95000.00);"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                PERFORM 3500-ROLLBACK-AND-ABORT
            END-IF

            MOVE "INSERT INTO employees VALUES (102, 'Bob Rodriguez', 'Finance', 82500.50);"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                PERFORM 3500-ROLLBACK-AND-ABORT
            END-IF

            MOVE "INSERT INTO employees VALUES (103, 'Carol Smith', 'Operations', 71200.00);"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                PERFORM 3500-ROLLBACK-AND-ABORT
            END-IF

            MOVE "INSERT INTO employees VALUES (104, 'David Kim', 'Engineering', 110000.00);"
                TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                PERFORM 3500-ROLLBACK-AND-ABORT
            END-IF

            MOVE "COMMIT;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE SQLITE-STATUS
            END-CALL
            IF NOT SQL-OK
                PERFORM 3500-ROLLBACK-AND-ABORT
            END-IF

            DISPLAY "[INFO] 4 employee records inserted." END-DISPLAY
            DISPLAY " " END-DISPLAY.

        3500-ROLLBACK-AND-ABORT.
            DISPLAY "[ERROR] Insert failed with status: " SQLITE-STATUS END-DISPLAY
            MOVE "ROLLBACK;" TO SQL-STATEMENT
            CALL "cob_sqlite_exec" USING BY REFERENCE DB-HANDLE BY REFERENCE SQL-STATEMENT BY REFERENCE SQLITE-STATUS
            END-CALL
            PERFORM 5000-CLEANUP
            MOVE 1 TO RETURN-CODE
            STOP RUN.

        4000-QUERY-EMPLOYEES.
            DISPLAY "[INFO] Executing query: SELECT ordered by salary DESC..." END-DISPLAY
            DISPLAY "---------------------------------------------------------------------" END-DISPLAY
            DISPLAY "ID        | NAME                 | DEPARTMENT      | SALARY          " END-DISPLAY
            DISPLAY "---------------------------------------------------------------------" END-DISPLAY

            MOVE "SELECT id, name, dept, salary FROM employees ORDER BY salary DESC;"
                TO SQL-STATEMENT
            CALL "cob_sqlite_prepare" USING
                BY REFERENCE DB-HANDLE
                BY REFERENCE SQL-STATEMENT
                BY REFERENCE STMT-HANDLE
                BY REFERENCE SQLITE-STATUS
            END-CALL

            IF NOT SQL-OK
                DISPLAY "[ERROR] Query preparation failed: " SQLITE-STATUS END-DISPLAY
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
                    *> Extract Column 0: id (Integer)
                    CALL "cob_sqlite_get_int" USING
                        BY REFERENCE STMT-HANDLE
                        BY VALUE 0
                        BY REFERENCE EMP-ID
                    END-CALL

                    *> Extract Column 1: name (Text)
                    CALL "cob_sqlite_get_text" USING
                        BY REFERENCE STMT-HANDLE
                        BY VALUE 1
                        BY REFERENCE EMP-NAME
                        BY VALUE 20
                    END-CALL

                    *> Extract Column 2: dept (Text)
                    CALL "cob_sqlite_get_text" USING
                        BY REFERENCE STMT-HANDLE
                        BY VALUE 2
                        BY REFERENCE EMP-DEPT
                        BY VALUE 15
                    END-CALL

                    *> Extract Column 3: salary (Double)
                    CALL "cob_sqlite_get_double" USING
                        BY REFERENCE STMT-HANDLE
                        BY VALUE 3
                        BY REFERENCE EMP-SALARY-DBL
                    END-CALL

                    COMPUTE EMP-SALARY-DEC ROUNDED = EMP-SALARY-DBL
                    END-COMPUTE
                    ADD 1 TO WS-EMP-COUNT
                    END-ADD
                    ADD EMP-SALARY-DEC TO WS-TOTAL-SALARY
                    END-ADD

                    MOVE EMP-ID TO DISP-EMP-ID
                    MOVE EMP-SALARY-DEC TO DISP-SALARY
                    DISPLAY DISP-EMP-ID " | " EMP-NAME " | " EMP-DEPT " | " DISP-SALARY
                    END-DISPLAY
                ELSE
                    IF NOT SQL-DONE
                        DISPLAY "[ERROR] Cursor step error occurred: " SQLITE-STATUS END-DISPLAY
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

            IF WS-EMP-COUNT > 0
                COMPUTE WS-AVG-SALARY = WS-TOTAL-SALARY / WS-EMP-COUNT
                END-COMPUTE
            END-IF

            MOVE WS-TOTAL-SALARY TO DISP-TOTAL
            MOVE WS-AVG-SALARY TO DISP-AVG
            DISPLAY "---------------------------------------------------------------------" END-DISPLAY
            DISPLAY "Total Employees : " WS-EMP-COUNT END-DISPLAY
            DISPLAY "Total Payroll   : " DISP-TOTAL END-DISPLAY
            DISPLAY "Average Salary  : " DISP-AVG END-DISPLAY
            DISPLAY " " END-DISPLAY.

        5000-CLEANUP.
            IF DB-HANDLE NOT = NULL
                DISPLAY "[INFO] Closing SQLite database..." END-DISPLAY
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
