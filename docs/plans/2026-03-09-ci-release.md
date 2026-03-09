# CI Release Pipeline — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically build and release a zellij Linux x86_64 binary to GitHub Releases when the pinned commit changes.

**Architecture:** A `ZELLIJ_REV` file in the repo root is the single source of truth for the upstream commit. GitHub Actions triggers on push to `main` when that file changes, builds via `cargo install --git`, extracts the upstream version from `Cargo.toml`, and creates a release tagged `v<version>-<short_hash>`.

**Tech Stack:** GitHub Actions, Rust/Cargo, protobuf, gh CLI

---

### Task 1: Create `ZELLIJ_REV` file

**Files:**
- Create: `ZELLIJ_REV`
- Modify: `Makefile:6`

**Step 1: Create the rev file**

Create `ZELLIJ_REV` with the current pinned hash (no trailing newline beyond one):

```
a8d99b64a3fe73284b0954da7daabf04da1c432d
```

**Step 2: Update Makefile to read from file**

In `Makefile`, replace line 6:

```makefile
ZELLIJ_REV ?= a8d99b64a3fe73284b0954da7daabf04da1c432d
```

with:

```makefile
ZELLIJ_REV ?= $(shell cat ZELLIJ_REV 2>/dev/null)
```

**Step 3: Verify Makefile still works**

Run: `make info`
Expected: `ZELLIJ_REV=a8d99b64a3fe73284b0954da7daabf04da1c432d` (same as before)

**Step 4: Commit**

```bash
git add ZELLIJ_REV Makefile
git commit -m "refactor: extract ZELLIJ_REV into dedicated file"
```

---

### Task 2: Create GitHub Actions release workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: Create workflow file**

```yaml
name: Release

on:
  push:
    branches: [main]
    paths: [ZELLIJ_REV]

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v4

      - name: Read ZELLIJ_REV
        id: rev
        run: |
          REV=$(cat ZELLIJ_REV | tr -d '[:space:]')
          SHORT=$(echo "$REV" | head -c 7)
          echo "rev=$REV" >> "$GITHUB_OUTPUT"
          echo "short=$SHORT" >> "$GITHUB_OUTPUT"

      - name: Get upstream version
        id: version
        run: |
          VERSION=$(curl -sL "https://raw.githubusercontent.com/zellij-org/zellij/${{ steps.rev.outputs.rev }}/Cargo.toml" \
            | sed -n '/\[workspace.package\]/,/\[/p' \
            | grep -m1 '^version' | sed 's/.*"\(.*\)"/\1/')
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          TAG="v${VERSION}-${{ steps.rev.outputs.short }}"
          echo "tag=$TAG" >> "$GITHUB_OUTPUT"

      - name: Check if release already exists
        id: check
        run: |
          TAG="${{ steps.version.outputs.tag }}"
          if gh release view "$TAG" >/dev/null 2>&1; then
            echo "exists=true" >> "$GITHUB_OUTPUT"
          else
            echo "exists=false" >> "$GITHUB_OUTPUT"
          fi
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Install protoc
        if: steps.check.outputs.exists == 'false'
        uses: arduino/setup-protoc@v3
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}

      - name: Install Rust toolchain
        if: steps.check.outputs.exists == 'false'
        uses: dtolnay/rust-toolchain@stable

      - name: Cargo cache
        if: steps.check.outputs.exists == 'false'
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
          key: cargo-${{ steps.rev.outputs.rev }}
          restore-keys: cargo-

      - name: Build zellij
        if: steps.check.outputs.exists == 'false'
        run: |
          cargo install --locked \
            --git https://github.com/zellij-org/zellij \
            --rev ${{ steps.rev.outputs.rev }} \
            --root ./dist \
            zellij

      - name: Create release
        if: steps.check.outputs.exists == 'false'
        run: |
          TAG="${{ steps.version.outputs.tag }}"
          REV="${{ steps.rev.outputs.rev }}"
          gh release create "$TAG" \
            ./dist/bin/zellij \
            --title "$TAG" \
            --notes "Built from [zellij-org/zellij@${REV:0:7}](https://github.com/zellij-org/zellij/commit/$REV)"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add GitHub Actions release workflow"
```

---

### Task 3: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add CI section to CLAUDE.md**

Add after the Architecture section:

```markdown
## CI / Releases

Pushing a change to `ZELLIJ_REV` on `main` triggers `.github/workflows/release.yml`:
builds the binary on `ubuntu-latest` and creates a GitHub Release tagged `v<version>-<short_hash>`.

To update the pinned commit: edit `ZELLIJ_REV`, commit, push.
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add CI release info to CLAUDE.md"
```

---

### Task 4: End-to-end verification

**Step 1: Push to main and verify workflow runs**

```bash
git push origin main
```

**Step 2: Check Actions tab**

Run: `gh run list --limit 1`
Expected: a workflow run triggered by the push, status "in_progress" or "completed".

**Step 3: After workflow completes, verify release**

Run: `gh release list --limit 1`
Expected: release tagged `v<version>-a8d99b6` with a `zellij` binary asset.
