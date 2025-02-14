# File: /main.mk
# Project: mkpm-dotenv
# File Created: 06-01-2022 03:18:08
# Author: Clay Risser
# -----
# Last Modified: 01-09-2024 09:01:36
# Modified By: Clay Risser
# -----
# Risser Labs LLC (c) Copyright 2021 - 2022
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

DOTENV ?= .env
_DOTENV_SUBPATH := dotenv$(subst $(PROJECT_ROOT),,$(CURDIR))
_DOTENV_PATH := $(patsubst %/,%,$(dir $(abspath $(DOTENV))))

ifneq (,$(wildcard $(_DOTENV_PATH)/.env.default))
DEFAULT_ENV ?= $(_DOTENV_PATH)/.env.default
endif
ifneq (,$(wildcard $(_DOTENV_PATH)/.env.example))
DEFAULT_ENV ?= $(_DOTENV_PATH)/.env.example
endif
ifneq (,$(wildcard $(_DOTENV_PATH)/default.env))
DEFAULT_ENV ?= $(_DOTENV_PATH)/default.env
endif
ifneq (,$(wildcard $(_DOTENV_PATH)/example.env))
DEFAULT_ENV ?= $(_DOTENV_PATH)/example.env
endif
ifneq (,$(wildcard $(_DOTENV_PATH)/env.default))
DEFAULT_ENV ?= $(_DOTENV_PATH)/env.default
endif
ifneq (,$(wildcard $(_DOTENV_PATH)/env.example))
DEFAULT_ENV ?= $(_DOTENV_PATH)/env.example
endif

ifneq (dotenv,$(_DOTENV_SUBPATH))
ifeq (,$(wildcard $(DEFAULT_ENV)))
ifeq (,$(wildcard $(DOTENV)))
ifeq ($(filter /%,$(DOTENV)),)
DOTENV := $(PROJECT_ROOT)/$(DOTENV)
endif
ifneq (,$(wildcard $(PROJECT_ROOT)/.env.default))
DEFAULT_ENV ?= $(PROJECT_ROOT)/.env.default
endif
ifneq (,$(wildcard $(PROJECT_ROOT)/.env.example))
DEFAULT_ENV ?= $(PROJECT_ROOT)/.env.example
endif
ifneq (,$(wildcard $(PROJECT_ROOT)/default.env))
DEFAULT_ENV ?= $(PROJECT_ROOT)/default.env
endif
ifneq (,$(wildcard $(PROJECT_ROOT)/example.env))
DEFAULT_ENV ?= $(PROJECT_ROOT)/example.env
endif
ifneq (,$(wildcard $(PROJECT_ROOT)/env.default))
DEFAULT_ENV ?= $(PROJECT_ROOT)/env.default
endif
ifneq (,$(wildcard $(PROJECT_ROOT)/env.example))
DEFAULT_ENV ?= $(PROJECT_ROOT)/env.example
endif
_DOTENV_SUBPATH := dotenv
endif
endif
endif

$(MKPM_TMP)/$(_DOTENV_SUBPATH)/env: $(DOTENV)
	@$(MKDIR) -p $(@D)
	@$(AWK) -F= ' \
		BEGIN { inMultiline=0; quoteType="" } \
		/^[[:space:]]*#/ || /^[[:space:]]*$$/ { print; next } \
		inMultiline && $$0 ~ quoteType "$$" { print; inMultiline=0; next } \
		inMultiline { print; next } \
		($$2 ~ /^"[^"]*$$/) || ($$2 ~ /^'\''[^'\'']*$$/) { \
			print "export " $$0; \
			inMultiline=1; \
			quoteType = substr($$2, 1, 1); \
			next \
		} \
		{ print "export " $$0 }' $< > $@

$(MKPM_TMP)/$(_DOTENV_SUBPATH)/mkenv: $(MKPM_TMP)/$(_DOTENV_SUBPATH)/env
	@$(MKDIR) -p $(@D)
	@$(RM) $@
	@. $< && \
		for e in $$($(CAT) $< | $(GREP) -oE '^export +[^=]+' | $(SED) 's|^export \+||g'); do \
			$(ECHO) "ifndef $$e" && \
			$(ECHO) "define $$e" && \
			eval "echo \"\$$$$e\"" && \
			$(ECHO) "endef" && \
			$(ECHO) "export $$e" && \
			$(ECHO) "endif" && \
			$(ECHO); \
		done > $@

ifneq (,$(wildcard $(DEFAULT_ENV)))
$(DOTENV): $(DEFAULT_ENV)
	@if [ ! -f "$@" ] || [ "$<" -nt "$@" ]; then \
		$(CP) $< $@; \
	fi
else
$(DOTENV):
	@$(TOUCH) -m $@
endif

-include $(MKPM_TMP)/$(_DOTENV_SUBPATH)/mkenv

MKPM_CLEANUP +=; $(RM) -rf $(MKPM_TMP)/dotenv
