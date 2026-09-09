       *>==================================================================*
       *> BANKING.CPY - Data Structures for Core Banking & Ledger Engine    *
       *>==================================================================*

      *> Account Record Layout
        01  ACCOUNT-RECORD.
            05  ACC-ID                    PIC S9(9) COMP-5.
            05  ACC-HOLDER-NAME           PIC X(25).
            05  ACC-TYPE                  PIC X(12).
            05  ACC-BALANCE               PIC S9(9)V99 COMP-3.
            05  ACC-STATUS                PIC X(10).

      *> Transaction Movement Record
        01  TRANSACTION-RECORD.
            05  TXN-ID                    PIC S9(9) COMP-5.
            05  TXN-ACC-ID                PIC S9(9) COMP-5.
            05  TXN-TYPE                  PIC X(10).
            05  TXN-AMOUNT                PIC 9(7)V99 COMP-3.
            05  TXN-TIMESTAMP             PIC X(20).

      *> In-Memory Batch Transaction Table (Hardware Indexed - Module 4)
        01  BATCH-TRANSACTION-TABLE.
            05  BATCH-TXN-ITEM            OCCURS 5 TIMES
                                          INDEXED BY TXN-IDX.
                10  B-TXN-ID              PIC S9(9) COMP-5.
                10  B-ACC-ID              PIC S9(9) COMP-5.
                10  B-TYPE                PIC X(10).
                10  B-AMOUNT              PIC 9(7)V99 COMP-3.
                10  B-TIMESTAMP           PIC X(20).

      *> Display & Reporting Formats (Edited Masks - Module 1)
        01  DISP-ACC-ID                   PIC ZZZZZZZZ9.
        01  DISP-AMOUNT                   PIC $$$,$$$,$$9.99.
        01  DISP-BALANCE                  PIC $$$$,$$$,$$9.99.
        01  DISP-TOTAL-ASSETS             PIC $$$,$$$,$$$,$$9.99.

