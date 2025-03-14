PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib/rock8s
MANDIR ?= $(PREFIX)/share/man
DOCDIR ?= $(PREFIX)/share/doc/rock8s
DESTDIR ?=
SHELL := /bin/bash
COMMANDS := rock8s
SUBCOMMANDS := nodes cluster pfsense completion
SUB_SUBCOMMANDS_nodes := ls create destroy ssh pubkey apply
SUB_SUBCOMMANDS_cluster := configure setup bootstrap login reset use apply install upgrade node scale
SUB_SUBCOMMANDS_pfsense := configure list apply destroy publish
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
	@install -d $(DESTDIR)$(LIBDIR)/libexec
	@install -d $(DESTDIR)$(MANDIR)/man1
	@install -d $(DESTDIR)$(DOCDIR)
	@install -m 755 rock8s.sh $(DESTDIR)$(LIBDIR)/rock8s.sh
	@ln -sf $(LIBDIR)/rock8s.sh $(DESTDIR)$(BINDIR)/rock8s
	@cp -r libexec/* $(DESTDIR)$(LIBDIR)/libexec/
	@chmod -R 755 $(DESTDIR)$(LIBDIR)/libexec
	@install -m 644 README.md $(DESTDIR)$(DOCDIR)/README.md
	@install -m 644 LICENSE $(DESTDIR)$(DOCDIR)/LICENSE
	@install -m 644 $(MAN1_DIR)/*.1 $(DESTDIR)$(MANDIR)/man1/

.PHONY: uninstall
uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/rock8s
	@rm -rf $(DESTDIR)$(LIBDIR)
	@rm -rf $(DESTDIR)$(DOCDIR)
	@rm -f $(DESTDIR)$(MANDIR)/man1/rock8s*.1

.PHONY: reinstall
reinstall: uninstall install

.PHONY: clean
clean:
	@rm -rf $(MAN_DIR)
	@rm -rf $(BUILD_DIR)
