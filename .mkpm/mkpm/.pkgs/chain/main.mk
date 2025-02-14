# File: /main.mk
# Project: mkchain
# File Created: 26-09-2021 16:53:36
# Author: Clay Risser
# -----
# Last Modified: 16-03-2024 14:07:58
# Modified By: Clay Risser
# -----
# BitSpur (c) Copyright 2021
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# -----
#
# the magic of this makefile consists of functions and macros
# used to create complex cached dependency chains that track
# changes on individual files and works across unix environments
#
# for example, this can be used to format the code and run tests
# against only the files that updated
#
# this significantly increases the speed of builds and development in a
# language and ecosystem agnostic way without sacrificing enforcement of
# critical scripts and jobs

.NOTPARALLEL:

AWK ?= awk
CUT ?= cut
ECHO ?= echo
GREP ?= grep
MKDIR ?= mkdir
RM ?= rm
SED ?= sed
SORT ?= sort
TR ?= tr
UNIQ ?= uniq
HASHSUM ?= $(call ternary,$(WHICH) shasum,shasum,md5sum)

_CHAIN_CACHE ?= $(MKPM_TMP)/chain
_CHAIN_ACTIONS := $(_CHAIN_CACHE)/actions
_CHAIN_ID := $(shell $(ECHO) $(CURDIR) | $(HASHSUM) | $(CUT) -d' ' -f1)
_CHAIN_DONE := $(_CHAIN_CACHE)/done/$(_CHAIN_ID)
ACTION := $(_CHAIN_DONE)

export CHAIN_CLEAN := $(RM) -rf $(_CHAIN_CACHE) $(NOFAIL)

define _ACTION_TEMPLATE
.PHONY: {{ACTION}} +{{ACTION}} _{{ACTION}} ~{{ACTION}}
.DELETE_ON_ERROR: $$(ACTION)/{{ACTION}}
{{ACTION}}: _{{ACTION}} ~{{ACTION}}
~{{ACTION}}: | {{ACTION_DEPENDENCY}} $$({{ACTION_UPPER}}_TARGETS) $$(ACTION)/{{ACTION}}
+{{ACTION}}: | _{{ACTION}} $$({{ACTION_UPPER}}_TARGETS) $$(ACTION)/{{ACTION}}
_{{ACTION}}:
	@$$(RM) -rf $$(_CHAIN_DONE)/{{ACTION}}
endef
export _ACTION_TEMPLATE

.PHONY: $(_CHAIN_ACTIONS)/%
$(_CHAIN_ACTIONS)/%:
	@$(MKDIR) -p "$(@D)" "$(_CHAIN_DONE)"
	@ACTION=$$($(ECHO) $* | $(GREP) -oE "^[^~]+") && \
		ACTION_DEPENDENCY=$$($(ECHO) $* | $(GREP) -oE "~[^~]+$$" $(NOFAIL)) && \
		ACTION_UPPER=$$($(ECHO) $$ACTION | $(TR) '[:lower:]' '[:upper:]') && \
		$(ECHO) "$${_ACTION_TEMPLATE}" | $(SED) "s|{{ACTION}}|$${ACTION}|g" | \
		$(SED) "s|{{ACTION_DEPENDENCY}}|$${ACTION_DEPENDENCY}|g" | \
		$(SED) "s|{{ACTION_UPPER}}|$${ACTION_UPPER}|g" > $@

define chain
$(patsubst %,$(_CHAIN_ACTIONS)/%,$(ACTIONS))
endef

define done
$(MKDIR) -p $(dir $1) && $(TOUCH) -m $1
endef

ifeq (,$(wildcard Mkpmfile))
define reset
$(MAKE) -s _$1 && \
$(RM) -rf $(ACTION)/$1 $(NOFAIL)
endef
else
define reset
$(MKPM_MAKE) _$1 && \
$(RM) -rf $(ACTION)/$1 $(NOFAIL)
endef
endif

define git_deps
$(shell ($(GIT) ls-files && ($(GIT) lfs ls-files | $(CUT) -d' ' -f3)) | $(SORT) | $(UNIQ) -u | $(GREP) -E "$1" $(NOFAIL))
endef

HELP_PREFIX ?=
HELP_SPACING ?= 32
_chain_help:
	@$(call make) _mkpm_help $(NOFAIL)
	@$(CAT) $(CURDIR)/$(shell [ -f $(CURDIR)/Mkpmfile ] && $(ECHO) Mkpmfile || $(ECHO) Makefile) | \
		$(GREP) -E '^ACTIONS\s+\+=\s+[a-zA-Z0-9].*##' | \
		$(SED) 's|^ACTIONS\s\++=\s\+||g' | \
		$(SED) 's|~[^ 	]\+||' | \
		$(SORT) | \
		$(UNIQ) | \
		$(AWK) 'BEGIN {FS = "[ 	]+##[ 	]*"}; {printf "\033[36m%-$(HELP_SPACING)s  \033[0m%s\n", "$(HELP_PREFIX)"$$1, $$2}'

ifeq (_mkpm_help,$(HELP))
HELP = _chain_help
endif
ifeq (_mkpm_help,$(.DEFAULT_GOAL))
.DEFAULT_GOAL = _chain_help
endif
