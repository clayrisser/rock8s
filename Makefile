.POSIX:
export ROOTDIR ?= $(eval ROOTDIR := $(shell git rev-parse --show-toplevel))$(ROOTDIR)
include $(ROOTDIR)/make.mk

.DEFAULT_GOAL := build

PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/rock8s
LIBEXECDIR ?= $(PREFIX)/libexec/rock8s
MANDIR ?= $(PREFIX)/share/man
DOCDIR ?= $(PREFIX)/share/doc/rock8s
DESTDIR ?=

# Legacy mkpm-style scaffolding still drives manpage generation.
MAN_DIR = man
MAN1_DIR = $(MAN_DIR)/man1
BUILD_DIR = .build

# nfpm tree-copies these staging roots, so they must mirror the on-disk
# layout the installed `rock8s` binary expects (BINDIR/LIBDIR/LIBEXECDIR/...).
BUILD := $(ROOTDIR)/build
BUILD_BIN := $(BUILD)$(BINDIR)
BUILD_LIB := $(BUILD)$(LIBDIR)
BUILD_LIBEXEC := $(BUILD)$(LIBEXECDIR)
BUILD_MAN1 := $(BUILD)$(MANDIR)/man1
BUILD_DOC := $(BUILD)$(DOCDIR)

SHFMT_DIRS := rock8s.sh lib libexec manpages.sh providers addons

SHELL_SCRIPTS := rock8s.sh manpages.sh \
	$(wildcard lib/*.sh) \
	$(wildcard libexec/*.sh) \
	$(wildcard libexec/*/*.sh) \
	$(wildcard libexec/*/*/*.sh) \
	$(wildcard providers/*/*.sh) \
	$(wildcard addons/modules/*/init.sh)

.PHONY: sudo
sudo:
	@$(SUDO) true

.PHONY: prepare prepare/asdf
prepare:
	@command -v asdf >/dev/null 2>&1 || $(MAKE) prepare/asdf
	@awk '!/^#/ && NF {print $$1}' .tool-versions | \
		while read t; do asdf plugin add "$$t" 2>/dev/null || true; done
	@asdf install
prepare/asdf:
	@command -v brew >/dev/null 2>&1 && brew install asdf || { \
		o=$$(uname | tr A-Z a-z); a=$$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/'); \
		curl -fsSL "https://github.com/asdf-vm/asdf/releases/download/v0.18.0/asdf-v0.18.0-$$o-$$a.tar.gz" \
			| $(SUDO) tar -xz -C /usr/local/bin asdf; \
	}

.PHONY: configure
configure:
	@for cmd in $(GORELEASER); do \
		command -v $$cmd >/dev/null 2>&1 || { echo "$$cmd is missing, run 'make prepare'"; exit 1; }; \
	done

.PHONY: all
all: build

# Stage the entire rock8s tree under build/usr/{bin,lib/rock8s,libexec/rock8s,
# share/man/man1,share/doc/rock8s} so nfpm can tree-copy each subdir into the
# final package. rock8s.sh becomes /usr/bin/rock8s (no .sh suffix); sub-
# libraries land in /usr/lib/rock8s/ (lib + providers + addons) and sub-
# commands in /usr/libexec/rock8s/. The on-disk layout matches what
# rock8s.sh expects when ROCK8S_HOME defaults to /usr/lib/rock8s.
.PHONY: build
build: configure manpages
	@rm -rf $(BUILD)
	@mkdir -p $(BUILD_BIN) $(BUILD_LIB) $(BUILD_LIBEXEC) $(BUILD_MAN1) $(BUILD_DOC)
	@mkdir -p $(BUILD_LIB)/providers $(BUILD_LIB)/addons
	@install -m 0755 rock8s.sh $(BUILD_BIN)/rock8s
	@cp -R lib/. $(BUILD_LIB)/
	@cp -R libexec/. $(BUILD_LIBEXEC)/
	@cp -R providers/. $(BUILD_LIB)/providers/
	@cp -R addons/. $(BUILD_LIB)/addons/
	@find $(BUILD_LIB) $(BUILD_LIBEXEC) -type f -name '*.sh' -exec chmod 0755 {} +
	@install -m 0644 README.md $(BUILD_DOC)/README.md
	@install -m 0644 LICENSE $(BUILD_DOC)/LICENSE
	@if [ -d $(MAN1_DIR) ]; then \
		for m in $(MAN1_DIR)/*.1; do \
			[ -e "$$m" ] && install -m 0644 "$$m" $(BUILD_MAN1)/ || true; \
		done; \
	fi

.PHONY: manpages
manpages:
	@mkdir -p $(BUILD_DIR)
	@sh manpages.sh

# Local snapshot build via goreleaser — produces dist/*.deb, dist/*.rpm,
# dist/*.tar.gz. CI tag pushes use `goreleaser release --clean` instead
# (see .gitlab-ci.yml).
.PHONY: package
package: configure
	@$(GORELEASER) release --snapshot --clean --skip=announce,publish,validate

# SC1007: false positive on CDPATH= cd -- …
# SC1091: dynamic source paths (ROCK8S_LIB_PATH)
# SC2046: intentional word-splitting for command args / lists
.PHONY: lint
lint:
	@command -v $(SHELLCHECK) >/dev/null 2>&1 || { echo "shellcheck missing, run 'make prepare'"; exit 1; }
	$(SHELLCHECK) -s sh --severity=warning \
		--exclude=SC1007,SC1091,SC2046 \
		$(SHELL_SCRIPTS)

.PHONY: format
format:
	@command -v $(SHFMT) >/dev/null 2>&1 || { echo "shfmt missing, run 'make prepare'"; exit 1; }
	@$(SHFMT) -ln posix -i 4 -w $(SHFMT_DIRS)
	@command -v tofu >/dev/null 2>&1 && tofu fmt -recursive providers/ addons/ || true

.PHONY: clean
clean:
	@rm -rf $(MAN_DIR) $(BUILD_DIR) $(BUILD) $(ROOTDIR)/dist $(MAKEDIR)

.PHONY: purge
purge: clean
	@$(GIT) clean -fxd

# ---------- legacy source-install entrypoints (kept for `make install`) ----------

.PHONY: install
install: build
	@install -d $(DESTDIR)$(BINDIR)
	@install -d $(DESTDIR)$(LIBDIR)
	@install -d $(DESTDIR)$(LIBEXECDIR)
	@install -d $(DESTDIR)$(LIBDIR)/providers
	@install -d $(DESTDIR)$(LIBDIR)/addons
	@install -d $(DESTDIR)$(MANDIR)/man1
	@install -d $(DESTDIR)$(DOCDIR)
	@install -m 755 rock8s.sh $(DESTDIR)$(LIBDIR)/rock8s.sh
	@ln -sf $(LIBDIR)/rock8s.sh $(DESTDIR)$(BINDIR)/rock8s
	@cp -r lib/* $(DESTDIR)$(LIBDIR)/
	@chmod -R 755 $(DESTDIR)$(LIBDIR)
	@cp -r libexec/* $(DESTDIR)$(LIBEXECDIR)/
	@chmod -R 755 $(DESTDIR)$(LIBEXECDIR)
	@cp -r providers/* $(DESTDIR)$(LIBDIR)/providers/
	@chmod -R 755 $(DESTDIR)$(LIBDIR)/providers
	@cp -r addons/* $(DESTDIR)$(LIBDIR)/addons/
	@chmod -R 755 $(DESTDIR)$(LIBDIR)/addons
	@install -m 644 README.md $(DESTDIR)$(DOCDIR)/README.md
	@install -m 644 LICENSE $(DESTDIR)$(DOCDIR)/LICENSE
	@install -m 644 $(MAN1_DIR)/*.1 $(DESTDIR)$(MANDIR)/man1/

.PHONY: uninstall
uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/rock8s
	@rm -rf $(DESTDIR)$(LIBDIR)
	@rm -rf $(DESTDIR)$(LIBEXECDIR)
	@rm -rf $(DESTDIR)$(DOCDIR)
	@rm -f $(DESTDIR)$(MANDIR)/man1/rock8s*.1

.PHONY: reinstall
reinstall: uninstall install
