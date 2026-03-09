# zellij-main

Small installer repo for running `zellij` from GitHub `main` side-by-side with a stable release.

It follows three safety rules:

1. installs into a separate prefix instead of replacing the system `zellij`;
2. exposes a separate wrapper command, `zellij-main`;
3. uses isolated `XDG_CACHE_HOME` and `XDG_DATA_HOME` so prerelease builds do not reuse the stable cache.

## Why

`zellij` upstream explicitly says installing from `main` is not recommended because it is prerelease code and may corrupt cache for future released versions.

This repo keeps that risk isolated while still making `main` easy to test on multiple machines.

## Requirements

- `git`
- `cargo`
- `rustc`
- `protoc`

If you want to build the exact commit pinned here, use the Rust toolchain expected by upstream for that revision.

## Install

```bash
git clone git@github.com:dapi/zellij-main.git
cd zellij-main
make install
```

This installs the binary to:

```text
~/.local/opt/zellij-main/bin/zellij
```

and creates the wrapper:

```text
~/.local/bin/zellij-main
```

## Usage

```bash
zellij-main
zellij-main --session experimental
```

Keep your normal released `zellij` command unchanged.

## Pin a Different Commit

```bash
make install ZELLIJ_REV=<commit>
```

The default is a pinned `main` commit, not a floating branch.

## Optional Separate Config

If you also want a separate config directory:

```bash
make install CONFIG_DIR=$$HOME/.config/zellij-main
```

The wrapper will then always run:

```bash
zellij --config-dir ~/.config/zellij-main
```

## Other Targets

```bash
make help
make info
make reinstall
make uninstall
make purge
```
