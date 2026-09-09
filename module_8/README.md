# Module 8: Continuous Integration & Continuous Deployment (CI/CD) with GitHub Actions

Welcome to **Module 8** of the Modern COBOL Training Series. In modern mission-critical software engineering, delivering reliable, bug-free applications requires automated pipelines. 

In traditional enterprise mainframe shops, COBOL code was migrated manually through staging libraries (SYSLIB, Endevor, Changeman) by system administrators running scheduled batch jobs. In modern cloud-native, containerized, and Linux architectures, COBOL projects adopt **DevOps and Git-centric CI/CD pipelines** powered by platforms such as **GitHub Actions**.

This module teaches you how to construct automated, resilient, and enterprise-ready CI/CD pipelines that compile modern GnuCOBOL applications, link embedded relational databases (**SQLite3**), execute regression test suites, assert database state, and package release artifacts on every `git push` and `pull request`.

---

## 🎯 Learning Objectives

By completing this module, you will be able to:
1. **Bridge Mainframe Release Engineering to GitOps**: Contrast traditional mainframe release tooling (Changeman, Endevor, JCL promotion decks) with modern Git branching, pull requests, automated runners, and immutable build artifacts.
2. **Master GitHub Actions for Native Compilers**: Understand the architecture of GitHub Actions runners (`ubuntu-latest`), workflow triggers (`push`, `pull_request`, `workflow_dispatch`), jobs, and action steps.
3. **Provision Linux Toolchains in Automated Runners**: Automate the headless installation of `gnucobol`, `libcob4-dev`, `gcc`, `make`, `sqlite3`, and `libsqlite3-dev` inside clean cloud ephemeral runners.
4. **Implement Multi-Stage Pipeline Workflows**:
   - **Linting / Static Analysis**: Early syntax verification using `cobc -fsyntax-only`.
   - **Automated Compilation**: Building native Linux executables linked with C-ABI libraries (`-lsqlite3`).
   - **Automated Regression Testing**: Running test suites that assert process exit codes (`RETURN-CODE`) and inspect runtime database modifications.
5. **Publish and Archive Immutable Build Artifacts**: Use `actions/upload-artifact` to archive compiled COBOL binaries for deployment, audit logs, and release tagging.
6. **Diagnose and Recover from Broken Builds**: Read runner console telemetry, trace test failure exit codes, reproduce pipeline failures locally, and implement bug fixes with rapid turnaround.

---

## 📂 Module Directory Layout

```text
module_8/
├── README.md                                         # Module Syllabus, Architecture & Index
├── 01_introduction_to_cobol_cicd.md                  # Guide 1: DevOps for COBOL (Mainframe vs Modern GitOps)
├── 02_github_actions_fundamentals_for_cobol.md       # Guide 2: Runners, Workflow Syntax & Toolchain Provisioning
├── 03_building_and_testing_cobol_sqlite_pipeline.md  # Guide 3: Step-by-Step CI: Lint, Build, Test & Assert
├── 04_pipeline_security_caching_and_release.md       # Guide 4: Artifact Upload, Release Automation & Caching
├── 05_hands_on_lab_and_exercise.md                   # Guide 5: Practical Hands-on Labs & Failure Recovery
│
├── Makefile                                          # Build automation (make check, make build, make test, make clean)
│
├── src/                                              # Application Source Code
│   ├── app.cob                                       # Enterprise Inventory System (COBOL + SQLite3)
│   ├── cob_sqlite.c                                  # C-ABI bridge between GnuCOBOL and libsqlite3
│   └── SQLITE.CPY                                    # Copybook for SQLite handles, return codes & queries
│
├── tests/                                            # Automated Verification Suite
│   └── test_app.sh                                   # Test harness asserting binary execution & DB integrity
│
└── templates/                                        # CI/CD Workflow Templates (Ready for Activation)
    └── cobol-ci.yml                                  # GitHub Actions workflow template for copy-paste activation
```

> [!IMPORTANT]
> **Active Workflow Guardrail**: In accordance with the training syllabus, no workflow file has been placed directly into `.github/workflows/` of the repository root. This ensures that your personal GitHub quota and actions remain inactive until you are ready to activate the pipeline during the hands-on lab in [05_hands_on_lab_and_exercise.md](file:///home/wesi/codes/cobol-training/module_8/05_hands_on_lab_and_exercise.md).

---

## 🧭 Learning & Lab Progression

1. **Step 1: Read the Guides**:
   - [01. Introduction to COBOL CI/CD](file:///home/wesi/codes/cobol-training/module_8/01_introduction_to_cobol_cicd.md)
   - [02. GitHub Actions Fundamentals for COBOL](file:///home/wesi/codes/cobol-training/module_8/02_github_actions_fundamentals_for_cobol.md)
   - [03. Building & Testing COBOL & SQLite Pipelines](file:///home/wesi/codes/cobol-training/module_8/03_building_and_testing_cobol_sqlite_pipeline.md)
   - [04. Pipeline Security, Caching & Artifact Release](file:///home/wesi/codes/cobol-training/module_8/04_pipeline_security_caching_and_release.md)

2. **Step 2: Inspect and Run the Application Locally**:
   - Build the COBOL SQLite application using `make build`.
   - Execute the test suite using `make test`.
   - Inspect the SQLite database using `sqlite3 inventory.db "SELECT * FROM inventory;"`.

3. **Step 3: Complete the Hands-on Labs**:
   - Follow [05. Hands-on Lab and Exercise Guide](file:///home/wesi/codes/cobol-training/module_8/05_hands_on_lab_and_exercise.md).
   - Activate the pipeline in your repository fork.
   - Intentionally introduce a bug in `app.cob`, observe the failed CI run on GitHub, and push a fix to achieve a green checkmark!

---

## ⚡ Quick Compilation & Execution Reference

All commands can be run directly from the `module_8/` directory:

### Syntax Check (Linting)
```bash
cd /home/wesi/codes/cobol-training/module_8
make check
```

### Build Binary
```bash
make build
# Produces bin/inventory_app
```

### Run Automated Tests
```bash
make test
```

### Run Executable Manually
```bash
./bin/inventory_app
```

### Clean Build & Test Artifacts
```bash
make clean
```

