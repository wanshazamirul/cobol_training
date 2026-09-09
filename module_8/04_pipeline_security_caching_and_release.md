# Chapter 4: Pipeline Security, Caching & Artifact Release

Once an enterprise CI pipeline reliably validates and tests code, the next operational milestone is **Continuous Delivery (CD)**: securely archiving compiled binaries, automating release distributions, and optimizing pipeline execution duration.

---

## 1. Archiving Build Artifacts with `actions/upload-artifact`

In cloud-native software delivery, compiling binaries directly on production servers is an anti-pattern. Instead, binaries should be compiled once inside the clean-room CI runner, verified by automated tests, and stored as an immutable **build artifact**.

### Workflow Implementation:
```yaml
      - name: Archive Compiled Binary Artifact
        uses: actions/upload-artifact@v4
        if: success()  # Only upload if all previous build and test steps passed
        with:
          name: inventory-app-linux-x64
          path: module_8/bin/inventory_app
          retention-days: 7
```

### How It Works:
1. **`if: success()`**: Ensures that if any test fails, the broken binary is discarded and never uploaded.
2. **`name: inventory-app-linux-x64`**: The name of the downloadable `.zip` package created on the GitHub Actions summary page.
3. **`path: module_8/bin/inventory_app`**: The location of the native ELF binary compiled by `cobc`.
4. **`retention-days: 7`**: Retains the artifact for 7 days (or up to 90 days), preventing unnecessary cloud storage consumption.

Once uploaded, developers and operations engineers can download the pre-compiled binary directly from the GitHub Actions web dashboard:

```text
GitHub Actions Run #142 -> Summary
└── Artifacts (1)
    └── inventory-app-linux-x64.zip (Contains 'inventory_app' ELF binary)
```

---

## 2. Release Packaging on Git Tags

For enterprise production deployments, binaries should be versioned alongside Git release tags (e.g. `v1.0.0`).

You can extend the pipeline to automatically publish a GitHub Release with an attached compressed tarball whenever a Git tag is pushed:

```yaml
  release:
    name: Publish GitHub Release
    needs: build-and-test
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Download Built Artifact
        uses: actions/download-artifact@v4
        with:
          name: inventory-app-linux-x64
          path: release-bin/

      - name: Package Release Tarball
        run: |
          chmod +x release-bin/inventory_app
          tar -czvf inventory-app-linux-x64.tar.gz -C release-bin inventory_app

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: inventory-app-linux-x64.tar.gz
          generate_release_notes: true
```

---

## 3. Optimizing Runner Speed with Caching

In a standard Ubuntu runner, executing `sudo apt-get update && sudo apt-get install -y gnucobol ...` downloads ~40MB of packages, taking 25 to 45 seconds on every workflow run.

To reduce workflow runtimes, you can cache the downloaded `.deb` archives using **`actions/cache`**:

```yaml
      - name: Cache APT Packages
        uses: actions/cache@v4
        with:
          path: /var/cache/apt/archives
          key: ${{ runner.os }}-apt-gnucobol-${{ hashFiles('module_8/Makefile') }}
          restore-keys: |
            ${{ runner.os }}-apt-gnucobol-
```

By caching package downloads, consecutive pipeline runs can shave 30+ seconds off total execution time.

---

## 4. Pipeline Security & Branch Protection

### A. Principle of Least Privilege
By default, GitHub Actions workflows should have restricted permissions to protect against supply chain tampering:

```yaml
permissions:
  contents: read   # Only allows read access to repository code
```

### B. Branch Protection Rules
In enterprise repositories, developers should never push code directly to the `main` or `production` branches. Instead, enforce **Branch Protection Rules**:

1. In GitHub, navigate to **Settings** -> **Branches** -> **Add branch protection rule**.
2. Set branch pattern to `main`.
3. Check **"Require a pull request before merging"**.
4. Check **"Require status checks to pass before merging"**.
5. Select **`Build, Lint & Test COBOL Application`** as the required check.

With this protection rule active, GitHub physically blocks anyone from merging a pull request if the COBOL compilation or SQLite test suite fails!

---

## 5. Summary & Next Steps

You now possess a complete architectural understanding of automated COBOL delivery:
- Compilation and static linting
- Automated testing and database assertions
- Immutable binary artifact uploading
- Release automation and branch protection

In the final chapter, [05. Hands-On Lab and Exercise Guide](file:///home/wesi/codes/cobol-training/module_8/05_hands_on_lab_and_exercise.md), you will perform practical exercises: running tests locally, activating the pipeline in your repository, intentionally breaking tests, and observing automated CI recovery.

