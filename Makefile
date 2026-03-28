PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/rock8s
LIBEXECDIR ?= $(PREFIX)/libexec/rock8s
MANDIR ?= $(PREFIX)/share/man
DOCDIR ?= $(PREFIX)/share/doc/rock8s
DESTDIR ?=
SHELL := /bin/bash
COMMANDS := rock8s
SUBCOMMANDS := init nodes cluster completion
SUB_SUBCOMMANDS_nodes := apply destroy ls pubkey ssh
SUB_SUBCOMMANDS_cluster := addons apply install login node reset rotate-certs scale upgrade
SUB_SUBCOMMANDS_completion := bash zsh
MAN_DIR = man
MAN1_DIR = $(MAN_DIR)/man1
BUILD_DIR = .build

.PHONY: all
all: build

.PHONY: build
build: manpages

.PHONY: manpages
manpages:
	@mkdir -p $(BUILD_DIR)
	@sh manpages.sh

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

.PHONY: format
format:
	@shfmt -ln posix -i 4 -w .
	@tofu fmt -recursive providers/
	@tofu fmt -recursive addons/

.PHONY: check-format
check-format:
	@shfmt -ln posix -i 4 -d .
	@tofu fmt -recursive -check providers/
	@tofu fmt -recursive -check addons/

.PHONY: clean
clean:
	@rm -rf $(MAN_DIR)
	@rm -rf $(BUILD_DIR)
