# Copyright 2018 Rockchip Electronics Co., Ltd. All Rights Reserved.
# author: hertz.wang, wangh@rock-chips.com
#
# SPDX-License-Identifier: Apache-2.0
#

# redefine MESSAGE Macro -- display a message in color bold type
MESSAGE = echo "$(TERM_BOLD_COLOR)>>> $($(PKG)_NAME) $($(PKG)_VERSION) $(call qstrip,$(1))$(TERM_RESET_ALL)"
TERM_BOLD_COLOR := $(shell tput setaf 6 2>/dev/null && tput smso 2>/dev/null)
TERM_RESET_ALL := $(shell tput sgr0 2>/dev/null)
# transform macro to dep file
trans_macro_to_depfile = $(wildcard $(addprefix $(2),$(join $(subst -,/,$(call LOWERCASE,$(1))),.h)))
trans_macros_to_depfile = $(foreach macro,$(1),$(call trans_macro_to_depfile,$(macro),$(2)))

remove-last-slash = $(shell echo $(1) | sed "s/\/$$//")

# Improve the pkgname as the name of rvmk, conveniently modify the pkgname for future,
# since the git folder name can not be changed optionally.
pkgname = $(basename $(notdir $(lastword $(MAKEFILE_LIST))))
PKGNAME = $(call UPPERCASE,$(pkgname))
rvmk_file = $(lastword $(MAKEFILE_LIST))

# these global flags which should make all target reconfigure and rebuild
GLOBAL_CONFIG_DEP = RV_ENABLE_DEBUG
ifeq ($(RV_ENABLE_DEBUG),y)
GLOBAL_CONFIG_DEP += RV_DEBUG_1 RV_DEBUG_2 RV_DEBUG_3
endif
GLOBAL_CONFIG_DEP += RV_OPTIMIZE_0 RV_OPTIMIZE_1 RV_OPTIMIZE_2 RV_OPTIMIZE_3 RV_OPTIMIZE_S
ifeq ($(BR2_TOOLCHAIN_HAS_SSP),y)
GLOBAL_CONFIG_DEP += RV_SSP_NONE RV_SSP_STRONG RV_SSP_ALL
endif

# err, should make clean manually after setting these values
# GLOBAL_CONFIG_DEP += RV_STATIC_LIBS RV_SHARED_LIBS

GLOBAL_CONFIG_DEP_FILE = $(call trans_macros_to_depfile,$(GLOBAL_CONFIG_DEP),$(HOST_CONFIG_DIR)/)

DISPABLECHARS = 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_
# $(1):PKG, $(2):pkgdir
define rv-generic-var-define
$(1)_VERSION := $(if $(wildcard $(RV_TOPDIR)/.git),NO_GIT_IN_SUBMODULE,\
	$(shell cd $(2) && git show --oneline --quiet HEAD | sed "s/[^$(DISPABLECHARS)]/_/g"))
#$$(info $$($(1)_VERSION))
$(1)_INSTALL_STAGING = NO
$(1)_SITE := $(2)
$(1)_SITE_METHOD = local

$(1)_BUILD_FROM_ORIGINAL_SOURCE = YES
$(1)_INSTALL_TARGET_OPTS ?=
# Some CMakeLists.txt in rv's libs take the CMAKE_INSTALL_PREFIX as the destination rather than
# $(DESTDIR)/$(INSTALL_PREFIX), so set DESTDIR empty.
$(1)_INSTALL_TARGET_OPTS += $(if $(QUIET),-s,) DESTDIR=
endef

# $(1): type; $(2): config parent dir; $(3): configs/<null>
define PRINT_BUILDIN_CONFIG
	$(Q)$(foreach external_dir, $(wildcard $(BOARD_DIR)/*/$(2)),\
	board_type=$(notdir $(subst /$(2),,$(external_dir)));\
	echo "$${board_type} Built-in $(1) configs:";\
	$(foreach b, $(sort $(notdir $(wildcard $(external_dir)/$(3)/*_defconfig))),\
	  printf "    %-35s - $(1) config for %s\\n" $(b) $${board_type};) \
	echo;\
	)
endef

# math assistant
dec2hex = $(shell echo "obase=16;$(1)" | bc)
dec2hex_per_section = $(shell echo "obase=16;$$[$(1)/512]" | bc)
sum = $(shell echo "$(subst $(space),+,$(1))" | bc)
align = $(shell echo "$$[($(1)+$(2)-1)&(~($(2)-1))]")
file_sizes = $(foreach file,$(1),$(shell stat -L -c "%s" $(file)))

#	$(1): part module name
#	$(2): pre part module name
#	$(3): names
define inner_generic_partsegment
ifndef $(1)_PREPART_OFFSET
$(1)_PREPART_OFFSET=$$($(2)_OFFSET)
endif
ifndef $(1)_PREPART_SIZE
$(1)_PREPART_SIZE=$$($(2)_SIZE)
endif
$(1)_OFFSET = $$(call sum,$$($(1)_PREPART_OFFSET) $$($(1)_PREPART_SIZE))
ifndef $(1)_SIZE
# align to 32k
$(1)_SIZE = $$(call align,$$(call sum,$$(call file_sizes,$(4))),32768)
else
ifneq ($$($(1)_SIZE),-)
$(1)_SIZE := $$(call align,$$($(1)_SIZE),32768)
endif
endif
$(3) += $(1)
endef

#	$(1): fstype
#	$(2): source dir
#	$(3): target img
#	$(4): target tmp name
#	$(5): label
define inner_gen_fs_img
@echo "(create $(notdir $(3)) with type $(1)..."
$(Q) rm -f $(3)

$(Q)$(if $(subst squashfs,,$(1)),,\
	PATH=$(BR_PATH) mksquashfs $(2) $(4) -nopad -noappend \
	-root-owned -comp gzip -b 256k > /dev/null && \
	dd if=$(4) of=$(3) bs=128k conv=sync && \
	rm -f $(4))

$(Q)$(if $(filter $(1),ext2 ext4),\
	PATH=$(BR_PATH);\
	mkfs.$(1) -d $(2) -r 1 -N 0 -m 5 -L "$(5)" \
	$(if $(subst aarch64,,$(ARCH)),,$(if $(subst ext2,,$(1)),-O 64bit,-O extents)) \
	$(3) 512M && resize2fs -M $(3) && fsck.$(1) -fy $(3))

@stat -c "%s %n" $(3)
@echo " ...done)"
endef
gen_fs_img = $(call inner_gen_fs_img,$(1),$(2),$(3),$(dir $(3))/.$(notdir $(3)).tmp,$(4))
