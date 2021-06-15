NAME := kernel
SPECFILE := kernel.spec

WORKDIR := $(shell pwd)
BRANCH ?= master

ifndef NAME
$(error "You can not run this Makefile without having NAME defined")
endif
ifndef VERSION
VERSION := $(shell cat version)
endif
ifndef RELEASE
RELEASE := $(shell cat rel)
endif

ifneq ($(VERSION),$(subst -rc,,$(VERSION)))
DOWNLOAD_FROM_GIT=1
VERIFICATION := hash
else
VERIFICATION := signature
endif

all: help

MIRROR := cdn.kernel.org
ifeq (,$(DISTFILES_MIRROR))
SRC_BASEURL := https://${MIRROR}/pub/linux/kernel/v$(shell echo $(VERSION) | sed 's/^\(2\.[0-9]*\).*/\1/;s/^3\..*/3.x/;s/^4\..*/4.x/')
else
SRC_BASEURL := $(DISTFILES_MIRROR)
endif

ifeq ($(VERIFICATION),signature)
SRC_FILE := linux-${VERSION}.tar.xz
SIGN_FILE := linux-${VERSION}.tar.sign
else
SRC_FILE := linux-${VERSION}.tar.gz
HASH_FILE := $(SRC_FILE).sha512
endif

URL := $(SRC_BASEURL)/$(SRC_FILE)
URL_SIGN := $(SRC_BASEURL)/$(SIGN_FILE)

get-sources: $(SRC_FILE) $(SIGN_FILE)

verrel:
	@echo $(NAME)-$(VERSION)-$(RELEASE)

ifeq ($(FETCH_CMD),)
$(error "You can not run this Makefile without having FETCH_CMD defined")
endif

$(SRC_FILE):
	@$(FETCH_CMD) $(SRC_FILE) -- $(URL)

$(SIGN_FILE):
	@$(FETCH_CMD) $(SIGN_FILE) -- $(URL_SIGN)

import-keys:
	@if [ -n "$$GNUPGHOME" ]; then rm -f "$$GNUPGHOME/linux-kernel-trustedkeys.gpg"; fi
	@gpg --no-auto-check-trustdb --no-default-keyring --keyring linux-kernel-trustedkeys.gpg -q --import *-key.asc

verify-sources: import-keys
ifeq ($(VERIFICATION),signature)
	@xzcat $(SRC_FILE) | gpgv --keyring linux-kernel-trustedkeys.gpg $(SIGN_FILE) - 2>/dev/null
else
	# there are no signatures for rc tarballs
	# verify locally based on a signed git tag and commit hash file
	sha512sum --quiet -c $(HASH_FILE)
endif

.PHONY: clean-sources
clean-sources:
ifneq ($(SRC_FILE), None)
	-rm $(SRC_FILE) $(SIGN_FILE)
endif

.PHONY: update-sources
update-sources:
	@$(WORKDIR)/update-sources $(BRANCH)

help:
	@echo "Usage: make <target>"
	@echo
	@echo "get-sources      Download kernel sources from kernel.org"
	@echo "verify-sources"
	@echo
	@echo "verrel"          Echo version release"
