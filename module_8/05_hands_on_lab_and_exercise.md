# Chapter 5: Practical Hands-On Lab & Exercise Guide

This guide provides practical, step-by-step exercises to solidify your understanding of Continuous Integration and Continuous Delivery for GnuCOBOL applications.

You will:
1. **Lab 1**: Build, run, and test the COBOL & SQLite application locally.
2. **Lab 2**: Understand how to activate the GitHub Actions pipeline in your GitHub repository when you are ready.
3. **Lab 3**: Learn how to inspect workflow execution telemetry and download build artifacts.
4. **Lab 4**: Simulate a production regression bug, observe the CI pipeline fail (Red), debug the issue, and push a fix (Green).

---

## 🛠️ Lab 1: Local Build & Test Verification

Before pushing code to any remote CI runner, always verify that your application builds and passes all automated tests in your local development environment.

### Step 1: Navigate to the Module Directory
```bash
cd /home/wesi/codes/cobol-training/module_8
```

### Step 2: Perform Fast Syntax Linting
```bash
make check
```
*Expected Output:*
```text
[CI-STEP] Syntax checking COBOL source...
cobc -fsyntax-only -free -I src src/app.cob
[CI-STEP] Syntax check passed.
```

### Step 3: Build the Native Binary
```bash
make build
```
*Expected Output:*
```text
[CI-STEP] Building native binary bin/inventory_app...
cobc -x -free -I src -Wall src/app.cob src/cob_sqlite.c -lsqlite3 -o bin/inventory_app
[CI-STEP] Build successful: bin/inventory_app
```

### Step 4: Run the Automated Test Suite
```bash
make test
```
*Expected Output:*
```text
[CI-STEP] Running automated test suite...
======================================================
       MODULE 8 AUTOMATED REGRESSION & CI TEST        
======================================================
[TEST 1/3] Executing COBOL Inventory application...
================================================================
      ENTERPRISE INVENTORY SYSTEM (COBOL + SQLITE3)             
               CI/CD AUTOMATED BUILD TARGET                     
================================================================
[INFO] Opening SQLite database: inventory.db
[INFO] Database connection established successfully.
[INFO] Initializing inventory schema...
[INFO] Schema initialized and purged.
[INFO] Seeding inventory records via transaction...
[INFO] 4 inventory records seeded successfully.
 
----------------------------------------------------------------
 ID   SKU          ITEM DESCRIPTION          QTY    UNIT PRICE   EXT VALUE
----------------------------------------------------------------
 101  SRV-DL380    Rack Server Gen10          12    $2,850.00   $34,200.00
 102  SW-CAT9300   Gigabit Switch 48-Port      8    $1,450.50   $11,604.00
 103  STOR-SAN8T   SAN Storage Array 8TB       4    $5,200.75   $20,803.00
 104  PWR-UPS3000  Online UPS 3000VA          15      $620.00    $9,300.00
----------------------------------------------------------------
TOTAL ITEMS:    4 | TOTAL UNITS:      39 | TOTAL VALUE:   $75,907.00
----------------------------------------------------------------
 
================================================================
 [STATUS: SUCCESS] Pipeline verification target passed.
================================================================
[PASS] Execution completed with return code 0.
[TEST 2/3] Verifying SQLite database file creation...
[PASS] Database file '/home/wesi/codes/cobol-training/module_8/inventory.db' verified.
[TEST 3/3] Querying database directly to assert data integrity...
Direct SQLite inspection: 4 rows, 39 total units.
[PASS] Database data integrity verified successfully.
======================================================
   ALL MODULE 8 CI/CD TESTS PASSED SUCCESSFULLY!     
======================================================
```

### Step 5: Direct Inspection of Database
Verify the committed SQLite records directly using the SQLite3 command line:
```bash
sqlite3 inventory.db "SELECT id, sku, name, quantity, price FROM inventory;"
```

---

## 🚀 Lab 2: Activating the CI/CD Pipeline on GitHub (When Ready)

> [!NOTE]
> To prevent unwanted automated runs right now, the workflow file was intentionally placed in `module_8/templates/cobol-ci.yml`. When you are ready to enable CI/CD on your GitHub repository or fork, follow these activation steps.

### Step 1: Create the Workflows Directory
From the root of the repository:
```bash
cd /home/wesi/codes/cobol-training
mkdir -p .github/workflows
```

### Step 2: Copy the Workflow Template
```bash
cp module_8/templates/cobol-ci.yml .github/workflows/cobol-ci.yml
```

### Step 3: Commit and Push to GitHub
```bash
git add .github/workflows/cobol-ci.yml
git commit -m "ci: activate GitHub Actions CI/CD pipeline for COBOL & SQLite"
git push origin main
```

---

## 📊 Lab 3: Monitoring Workflow Telemetry & Artifacts

Once pushed to GitHub:

1. Open your repository on **GitHub.com**.
2. Click the **Actions** tab at the top of the repository.
3. You will see your workflow **`COBOL & SQLite CI/CD Pipeline`** running with an orange pulsing indicator.
4. Click on the active workflow run to view real-time logs:
   - Click on the job **`Build, Lint & Test COBOL Application`**.
   - Expand each step (`Checkout Repository`, `Install GnuCOBOL & SQLite3 Toolchain`, `Build Native Binary`, `Run Automated Test Harness`).
5. When the run finishes, notice the green checkmark (`Passed`).
6. Scroll down to the **Artifacts** section at the bottom of the Summary page.
7. Click **`inventory-app-linux-x64`** to download the compiled standalone binary.

---

## 💥 Lab 4: Failure Simulation & Red-to-Green Bug Recovery

To truly understand how CI protects production systems, simulate a developer introducing an arithmetic calculation bug.

### Step 1: Introduce a Logic Bug in `src/app.cob`
Edit [src/app.cob](file:///home/wesi/codes/cobol-training/module_8/src/app.cob#L182) and intentionally change the calculation of line value from multiplication (`*`) to addition (`+`):

```cobol
      *> Intentional Bug: changed * to +
      COMPUTE WS-LINE-VALUE = ITEM-QTY + ITEM-PRICE
```

### Step 2: Rebuild the Binary
```bash
make build
```

### Step 3: Run the Test Harness
```bash
make test
```
Notice that while the program might still run, if an assertion checks total valuation or database integrity, or if you modify the seed count:

Now let's simulate a database transaction bug:
In [src/app.cob](file:///home/wesi/codes/cobol-training/module_8/src/app.cob#L148), change:
```cobol
      *> Change COMMIT to ROLLBACK
      MOVE "ROLLBACK;" TO SQL-STATEMENT
```

Rebuild and re-test:
```bash
make build
make test
```
*Observe the failure:*
```text
Direct SQLite inspection: 0 rows,  total units.
[FAIL] Row count mismatch! Expected 4, got: 0
make: *** [Makefile:32: test] Error 1
```

### Step 4: The CI Protection Effect
If this change were pushed to GitHub, GitHub Actions would:
1. Detect that `make test` exited with code `2` (non-zero).
2. Immediately flag the workflow as **FAILED** (Red X).
3. Send an email alert to the committer.
4. Block the Pull Request from being merged into `main`.
5. Refuse to upload the broken binary artifact.

### Step 5: Restore and Verify (Green)
Revert the bug back to `COMMIT;`:
```cobol
MOVE "COMMIT;" TO SQL-STATEMENT
```

Re-run tests locally:
```bash
make test
```
Everything passes with exit code `0`!

---

## 📋 Self-Assessment Checklist

- [ ] Can you explain why `apt-get install gnucobol` is required in GitHub-hosted runners?
- [ ] Do you know how GnuCOBOL communicates process failure to GitHub Actions (`RETURN-CODE`)?
- [ ] Why is direct assertion via `sqlite3` CLI superior to relying solely on COBOL stdout?
- [ ] How does `actions/upload-artifact@v4` preserve compiled executables?
- [ ] How do branch protection rules prevent broken COBOL builds from reaching production?

