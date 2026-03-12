SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
export PATH := $(HOME)/.local/share/mise/shims:$(PATH)

ZELLIJ_REPO ?= https://github.com/zellij-org/zellij
ZELLIJ_REV ?= $(shell cat ZELLIJ_REV 2>/dev/null)
INSTALL_ROOT ?= $(HOME)/.local/opt/zellij-main
BIN_DIR ?= $(HOME)/.local/bin
WRAPPER_NAME ?= zellij-main
WRAPPER_PATH ?= $(BIN_DIR)/$(WRAPPER_NAME)
CACHE_HOME ?= $(HOME)/.cache/zellij-main
DATA_HOME ?= $(HOME)/.local/share/zellij-main
CONFIG_DIR ?=
CARGO ?= cargo
REPLACE_ROOT ?= $(HOME)/.local

.DEFAULT_GOAL := install

.PHONY: help deps check install wrapper uninstall purge reinstall install-replace remove-old-zellij info

help:
	@printf '%s\n' \
	  'Targets:' \
	  '  make              Build and install (default)' \
	  '  make deps         Install build dependencies via mise' \
	  '  make install      Build and install pinned zellij main side-by-side' \
	  '  make wrapper      Recreate the zellij-main wrapper only' \
	  '  make uninstall    Remove the wrapper and installed binary' \
	  '  make purge        uninstall + remove isolated cache/data dirs' \
	  '  make reinstall    Reinstall from scratch' \
	  '  make info              Print effective configuration' \
	  '  make install-replace   Remove old zellij and install pinned main as zellij' \
	  '  make remove-old-zellij Detect and remove system-installed zellij' \
	  '' \
	  'Overrides:' \
	  '  ZELLIJ_REV=<commit>    Pin a different commit' \
	  '  INSTALL_ROOT=<path>    Installation root for cargo --root' \
	  '  WRAPPER_NAME=<name>    Wrapper command name (default: zellij-main)' \
	  '  CONFIG_DIR=<path>      Optional zellij --config-dir for the wrapper' \
	  '  REPLACE_ROOT=<path>    Install root for install-replace (default: ~/.local)'

deps:
	@command -v mise >/dev/null || { printf 'mise not found. Install from https://mise.jdx.dev\n'; exit 1; }
	mise install
	@printf 'Dependencies installed via mise\n'

check:
	@command -v git >/dev/null
	@command -v $(CARGO) >/dev/null
	@command -v rustc >/dev/null
	@command -v protoc >/dev/null
	@printf 'git:    %s\n' "$$(git --version)"
	@printf 'cargo:  %s\n' "$$($(CARGO) --version)"
	@printf 'rustc:  %s\n' "$$(rustc --version)"
	@printf 'protoc: %s\n' "$$(protoc --version)"

install: deps check
	@mkdir -p "$(INSTALL_ROOT)" "$(BIN_DIR)" "$(CACHE_HOME)" "$(DATA_HOME)"
	$(CARGO) install --locked \
	  --git "$(ZELLIJ_REPO)" \
	  --rev "$(ZELLIJ_REV)" \
	  --root "$(INSTALL_ROOT)" \
	  zellij
	@$(MAKE) wrapper
	@printf 'Installed zellij main at %s\n' "$(INSTALL_ROOT)/bin/zellij"

wrapper:
	@mkdir -p "$(BIN_DIR)" "$(CACHE_HOME)" "$(DATA_HOME)"
	@{ \
	  printf '%s\n' '#!/usr/bin/env bash'; \
	  printf '%s\n' 'set -euo pipefail'; \
	  printf 'export XDG_CACHE_HOME=%q\n' "$(CACHE_HOME)"; \
	  printf 'export XDG_DATA_HOME=%q\n' "$(DATA_HOME)"; \
	  if [[ -n "$(CONFIG_DIR)" ]]; then \
	    printf 'exec %q --config-dir %q "$$@"\n' "$(INSTALL_ROOT)/bin/zellij" "$(CONFIG_DIR)"; \
	  else \
	    printf 'exec %q "$$@"\n' "$(INSTALL_ROOT)/bin/zellij"; \
	  fi; \
	} > "$(WRAPPER_PATH)"
	@chmod +x "$(WRAPPER_PATH)"
	@printf 'Wrapper written to %s\n' "$(WRAPPER_PATH)"

uninstall:
	@rm -f "$(WRAPPER_PATH)"
	@rm -rf "$(INSTALL_ROOT)"
	@printf 'Removed %s and %s\n' "$(WRAPPER_PATH)" "$(INSTALL_ROOT)"
	@printf 'Kept cache/data: %s %s\n' "$(CACHE_HOME)" "$(DATA_HOME)"

purge: uninstall
	@rm -rf "$(CACHE_HOME)" "$(DATA_HOME)"
	@printf 'Removed cache/data: %s %s\n' "$(CACHE_HOME)" "$(DATA_HOME)"

reinstall: uninstall install

remove-old-zellij:
	@found=0; \
	replace_bin="$(REPLACE_ROOT)/bin/zellij"; \
	for p in $$(type -aP zellij 2>/dev/null | sort -u); do \
	  [ "$$p" = "$$replace_bin" ] && continue; \
	  found=1; \
	  printf 'Found zellij at: %s\n' "$$p"; \
	  removed=0; \
	  if pkg=$$(dpkg -S "$$p" 2>/dev/null); then \
	    pkg_name=$${pkg%%:*}; \
	    printf 'Installed via apt (package: %s). Removing...\n' "$$pkg_name"; \
	    sudo apt-get remove -y "$$pkg_name"; \
	    removed=1; \
	  fi; \
	  if [ "$$removed" -eq 0 ] && snap list zellij >/dev/null 2>&1; then \
	    printf 'Installed via snap. Removing...\n'; \
	    sudo snap remove zellij; \
	    removed=1; \
	  fi; \
	  if [ "$$removed" -eq 0 ] && command -v brew >/dev/null 2>&1 && brew list zellij >/dev/null 2>&1; then \
	    printf 'Installed via brew. Removing...\n'; \
	    brew uninstall zellij; \
	    removed=1; \
	  fi; \
	  if [ "$$removed" -eq 0 ] && [[ "$$p" == */.cargo/bin/zellij ]]; then \
	    printf 'Installed via cargo. Removing...\n'; \
	    cargo uninstall zellij; \
	    removed=1; \
	  fi; \
	  if [ "$$removed" -eq 0 ]; then \
	    printf 'Unknown install method. Removing binary directly...\n'; \
	    rm -f "$$p" 2>/dev/null || sudo rm -f "$$p"; \
	    removed=1; \
	  fi; \
	  [ "$$removed" -eq 1 ] && printf 'Removed: %s\n' "$$p"; \
	done; \
	if [ "$$found" -eq 0 ]; then \
	  printf 'No existing zellij installation found.\n'; \
	fi

install-replace: remove-old-zellij
	@mkdir -p "$(REPLACE_ROOT)/bin"
	@printf 'Downloading zellij from latest GitHub Release...\n'
	@curl -fSL "$$(curl -fSs https://api.github.com/repos/dapi/zellij-main/releases/latest \
	  | grep browser_download_url | cut -d '"' -f 4)" \
	  -o "$(REPLACE_ROOT)/bin/zellij"
	@chmod +x "$(REPLACE_ROOT)/bin/zellij"
	@printf 'Installed zellij at %s/bin/zellij\n' "$(REPLACE_ROOT)"

info:
	@printf '%s\n' \
	  "ZELLIJ_REPO=$(ZELLIJ_REPO)" \
	  "ZELLIJ_REV=$(ZELLIJ_REV)" \
	  "INSTALL_ROOT=$(INSTALL_ROOT)" \
	  "WRAPPER_PATH=$(WRAPPER_PATH)" \
	  "CACHE_HOME=$(CACHE_HOME)" \
	  "DATA_HOME=$(DATA_HOME)" \
	  "CONFIG_DIR=$(CONFIG_DIR)" \
	  "REPLACE_ROOT=$(REPLACE_ROOT)"
