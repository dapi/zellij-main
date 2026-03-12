# zellij-main

Small installer repo for running `zellij` from GitHub `main` side-by-side with a stable release.

It follows three safety rules:

1. installs into a separate prefix instead of replacing the system `zellij`;
2. exposes a separate wrapper command, `zellij-main`;
3. uses isolated `XDG_CACHE_HOME` and `XDG_DATA_HOME` so prerelease builds do not reuse the stable cache.

## Why

`zellij` upstream explicitly says installing from `main` is not recommended because it is prerelease code and may corrupt cache for future released versions.

This repo keeps that risk isolated while still making `main` easy to test on multiple machines.

## Why We Created This Repo

This repo exists for one practical reason: we want to test unreleased `zellij` features without replacing the stable `zellij` we use every day.

Right now this matters because the `main` branch already contains new tab APIs based on stable `tab_id` values. That is directly relevant to our work on tab status handling in:

- [`zellij-tab-status`](https://github.com/dapi/zellij-tab-status)
- [`zjstatus`](https://github.com/dapi/zjstatus)

Our current released version (`0.43.1`) still pushes us toward awkward workarounds around tab renaming and tab identity. Testing `main` side-by-side lets us validate the newer APIs before the next official release.

## What This Gives Us For Tab Status Work

In the stable release, tab-related automation is still constrained by the old split between:

- tab position in the UI
- internal persistent tab index used by some older actions

That mismatch is exactly why tab-status code tends to grow hacks around probing, remapping, and recovery after tab deletion or reordering.

The newer `main` branch already exposes better primitives for this area, including stable tab IDs and tab-aware CLI / plugin APIs. In practice, this repo gives us a safe way to evaluate whether we can:

1. reduce or remove probing logic in `zellij-tab-status`;
2. stop relying on fragile tab-position assumptions;
3. move toward status logic keyed by stable tab identity;
4. verify new behavior on several computers with the same pinned `zellij` commit.

So this repo is not the final status solution by itself. It is the reproducible test harness that lets us check whether unreleased `zellij` functionality is good enough to simplify our tab-status architecture.

## Install from Release

Download the prebuilt Linux x86_64 binary from GitHub Releases — no Rust toolchain needed.

### Quick install (no cache isolation)

The simplest option. Good enough if you don't have a stable `zellij` installed, or don't care about cache separation:

```bash
curl -sL "$(curl -s https://api.github.com/repos/dapi/zellij-main/releases/latest \
  | grep browser_download_url | cut -d '"' -f 4)" \
  -o ~/.local/bin/zellij-main
chmod +x ~/.local/bin/zellij-main
```

This puts the binary directly into `PATH` as `zellij-main`. It will share `XDG_CACHE_HOME` and `XDG_DATA_HOME` with your stable `zellij` (if any).

### Full install (with cache isolation)

Use this if you run a stable `zellij` release alongside and want to keep their caches completely separate. The wrapper script overrides `XDG_CACHE_HOME` and `XDG_DATA_HOME` so the prerelease build never touches stable cache files:

```bash
# Download the binary
curl -sL "$(curl -s https://api.github.com/repos/dapi/zellij-main/releases/latest \
  | grep browser_download_url | cut -d '"' -f 4)" \
  -o /tmp/zellij
install -Dm755 /tmp/zellij ~/.local/opt/zellij-main/bin/zellij

# Create the isolation wrapper
git clone git@github.com:dapi/zellij-main.git
cd zellij-main
make wrapper
```

The wrapper at `~/.local/bin/zellij-main` sets isolated paths before exec-ing the binary:
- Cache: `~/.cache/zellij-main`
- Data: `~/.local/share/zellij-main`

### Replace system zellij

If you want to use the pinned `main` build as your primary `zellij` (not side-by-side):

> **Note:** If zellij is installed via `apt`, `snap`, or `brew`, remove it first through the respective package manager.

```bash
git clone git@github.com:dapi/zellij-main.git
cd zellij-main
make install-replace
```

This downloads the prebuilt binary from GitHub Releases and installs it as `~/.local/bin/zellij`. No Rust toolchain required.

## Install from Source

Build from source if you need a custom configuration or want to build a different commit:

```bash
git clone git@github.com:dapi/zellij-main.git
cd zellij-main
make install
```

Requires `git`, `cargo`, `rustc`, `protoc`. Creates both the binary and the isolation wrapper.

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
