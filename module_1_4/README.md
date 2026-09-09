# Module 1-4 Capstone: Enterprise Core Banking & Ledger Engine

Welcome to the **Module 1-4 Capstone Project**. This hands-on capstone synthesizes and consolidates the core competencies developed across the first four modules of the Modern COBOL & .NET Training Series into a single, cohesive, production-grade enterprise application.

---

## 🎯 Cross-Module Competency Matrix

This capstone integrates key concepts from Modules 1 through 4:

| Module | Core Concept | Implementation in Capstone |
| :--- | :--- | :--- |
| **Module 1** | Modern COBOL Foundations | Free-format COBOL (`>>SOURCE FORMAT FREE`), modular copybooks (`BANKING.CPY`, `SQLITE.CPY`), and edited financial masks (`$$$,$$$,$$9.99`). |
| **Module 2** | Modern Structural & Domain Modeling | Clean paragraph modularity, account classification business logic, and structured status transitions. |
| **Module 3** | Database Persistence & Transactions | SQLite3 integration via the type-safe C bridge (`cob_sqlite.c`), DDL table management, ACID atomic transactions (`BEGIN`, `COMMIT`, `ROLLBACK`), and cursor queries. |
| **Module 4** | Resilience, Profiling & Debugging | `ON SIZE ERROR` overflow recovery, high-performance native binary (`COMP-5`) and packed decimal (`COMP-3`), hardware table indexing (`INDEXED BY`), and conditional debugging (`>>D`). |

---

## 📂 Project Directory Structure

```text
module_1_4/
├── README.md                                    # Capstone Overview, Syllabus & Index
├── 01_capstone_project_guide.md                 # Detailed Lab Specs, Requirements & Scenarios
│
└── exercises/
    └── capstone_banking_engine/
        ├── starter/                             # Student Starter Code with TODO Guides
        │   ├── BANKING.CPY                      # Domain copybook (Accounts, Transactions & Tables)
        │   ├── SQLITE.CPY                       # SQLite C-bridge copybook
        │   ├── cob_sqlite.c                     # Safe C-bridge to SQLite3
        │   └── BankingApp.cob                   # Starter implementation
        │
        └── solution/                            # 100% Complete Production Solution
            ├── BANKING.CPY                      # Domain copybook
            ├── SQLITE.CPY                       # SQLite C-bridge copybook
            ├── cob_sqlite.c                     # Safe C-bridge to SQLite3
            └── BankingApp.cob                   # Verified solution implementation
```

---

## ⚡ Quick-Start Build & Run Reference

### Running the Solution
```bash
cd /home/wesi/codes/cobol-training/module_1_4/exercises/capstone_banking_engine/solution

# 1. Standard compilation with all warnings enabled
cobc -Wall -Wextra -x -free BankingApp.cob cob_sqlite.c -lsqlite3 -o BankingApp

# 2. Run the application
./BankingApp

# 3. Compile and run with conditional debugging traces enabled (>>D)
cobc -x -free -debug BankingApp.cob cob_sqlite.c -lsqlite3 -o BankingApp_Debug
./BankingApp_Debug
```

### Working on the Starter Exercise
```bash
cd /home/wesi/codes/cobol-training/module_1_4/exercises/capstone_banking_engine/starter

# Follow instructions in 01_capstone_project_guide.md to complete TODOs 1 through 4
cobc -Wall -Wextra -x -free BankingApp.cob cob_sqlite.c -lsqlite3 -o BankingApp
./BankingApp
```

---

## 🧭 Learning Progression

1. **Review the Specifications**: Read [01. Capstone Project Guide](file:///home/wesi/codes/cobol-training/module_1_4/01_capstone_project_guide.md) for full system requirements, data dictionary, and test cases.
2. **Inspect the Starter Project**: Open `exercises/capstone_banking_engine/starter/BankingApp.cob` and locate the four `TODO` challenge blocks.
3. **Implement & Debug**: Complete each challenge, verifying resilience against overdrafts and numerical overflow.
4. **Compare with Solution**: Validate your implementation against the reference solution in `exercises/capstone_banking_engine/solution/`.

