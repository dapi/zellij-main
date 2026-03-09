# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A side-by-side installer for `zellij` from GitHub `main`. It builds a pinned commit of upstream zellij and installs it as `zellij-main` with isolated cache/data directories, so it never interferes with the stable release.

## Key Commands

```bash
make install              # Build and install (default target); runs deps + check first
make install ZELLIJ_REV=<commit>  # Pin a different upstream commit
make wrapper              # Recreate the wrapper script only (no rebuild)
make uninstall            # Remove wrapper and binary (keeps cache/data)
make purge                # uninstall + remove cache/data dirs
make reinstall            # uninstall then install
make info                 # Print effective configuration variables
make deps                 # Install build deps via mise (currently just protoc)
make check                # Verify git, cargo, rustc, protoc are available
```

## Build Requirements

`git`, `cargo`, `rustc`, `protoc` (protoc managed via `mise.toml`).

## Architecture

Single `Makefile` — no Rust/JS/Python source code in this repo. The Makefile:

1. Clones upstream `zellij-org/zellij` at a pinned rev via `cargo install --git --rev`.
2. Installs binary to `~/.local/opt/zellij-main/bin/zellij`.
3. Generates a bash wrapper at `~/.local/bin/zellij-main` that sets `XDG_CACHE_HOME` and `XDG_DATA_HOME` to isolated paths before exec-ing the binary.

All paths are configurable via Make variables (`INSTALL_ROOT`, `BIN_DIR`, `WRAPPER_NAME`, `CACHE_HOME`, `DATA_HOME`, `CONFIG_DIR`).

The pinned commit lives in the `ZELLIJ_REV` file (root). Makefile reads it via `$(shell cat ZELLIJ_REV)`.

## CI / Releases

Pushing a change to `ZELLIJ_REV` on `main` triggers `.github/workflows/release.yml`:
builds the binary on `ubuntu-latest` and creates a GitHub Release tagged `v<version>-<short_hash>`.

To update the pinned commit: edit `ZELLIJ_REV`, commit, push.
