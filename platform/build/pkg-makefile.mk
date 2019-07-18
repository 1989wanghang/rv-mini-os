# Copyright 2018 Rockchip Electronics Co., Ltd. All Rights Reserved.
# author: hertz.wang, wangh@rock-chips.com
# modified from buildroot/Makefile
#
# SPDX-License-Identifier: GPL-2.0-or-later
#

# A generic same words for rv's libraries which be built by makefile.
# $(1):pkg, $(2):PKG
define inner-rv-generic-makefile

$(2)_CONF_ENV			?=
$(2)_CONF_OPTS			?=
$(2)_MAKE_ENV			?=
$(2)_MAKE_OPTS			+= $$(QUIET)
$(2)_INSTALL_TARGET_OPTS	?= DESTDIR=$$(TARGET_DIR) install
$(2)_INSTALL_TARGET_OPTS	+= $$(QUIET)

$(2)_CLEAN_OPTS			?= clean
$(2)_CLEAN_OPTS			+= $$(QUITE)

ifndef $(2)_BUILD_CMDS
define $(2)_BUILD_CMDS
	$(Q)cd $$($$(PKG)_PKGDIR) && \
	$$(TARGET_MAKE_ENV) $$($$(PKG)_MAKE_ENV) $$(MAKE) $$($$(PKG)_MAKE_OPTS)
endef
endif

ifndef $(2)_INSTALL_TARGET_CMDS
define $(2)_INSTALL_TARGET_CMDS
	$(Q)cd $$($$(PKG)_PKGDIR) && \
	$$(TARGET_MAKE_ENV) $$($$(PKG)_MAKE_ENV) $$(MAKE) $$($$(PKG)_INSTALL_TARGET_OPTS)
endef
endif

ifndef $(2)_MAKECLEAN_CMDS
define $(2)_MAKECLEAN_CMDS
	$(Q)(cd $$($$(PKG)_PKGDIR) && \
		! test -f Makefile || \
		! $$(TARGET_MAKE_ENV) $$($$(PKG)_MAKE_ENV) $$(MAKE) $$($$(PKG)_MAKE_OPTS) $$($$(PKG)_CLEAN_OPTS) || true\
	)
endef
endif

$(call inner-generic-package,$(1),$(2),$(2),target)

endef

# A generic same words for rv's libraries which be built by Makefile.
# $(1):pkg, $(2):PKG
define inner-rv-generic-Makefile

$(2)_MAKE_OPTS		+= $$(TARGET_CONFIGURE_OPTS)

$(call inner-rv-generic-makefile,$(1),$(2))

ifneq ($(wildcard $($(PKGNAME)_PKGDIR)/Makefile),)
$$($(2)_TARGET_CONFIGURE): $($(PKGNAME)_PKGDIR)/Makefile
endif

endef

# A generic same words for rv's libraries which be built by auto-configure.
# $(1):pkg, $(2):PKG
define inner-rv-generic-configure

$(2)_CLEAN_OPTS ?= distclean

define REMOVE_TARGET_CONFIGURE
	$(Q)rm -f $$($$(PKG)_TARGET_CONFIGURE)
	$(Q)rm -f $$($$(PKG)_TARGET_INSTALL_TARGET)
endef

ifeq ($$($(2)_CLEAN_OPTS), distclean)
$(2)_POST_MAKECLEAN_TARGET_HOOKS += REMOVE_TARGET_CONFIGURE
endif

ifndef $(2)_CONFIGURE_CMDS
define $(2)_CONFIGURE_CMDS
	$(Q)cd $$($$(PKG)_PKGDIR) && rm -rf config.cache && \
		$$(TARGET_CONFIGURE_OPTS) \
		$$(TARGET_CONFIGURE_ARGS) \
		$$($$(PKG)_CONF_ENV) \
		./configure $$($$(PKG)_CONF_OPTS)
endef
endif

$(call inner-rv-generic-makefile,$(1),$(2))

define MAKECLEAN_AFTER_CONFIGURE_CMDS
	$(Q)(cd $$($$(PKG)_PKGDIR) && \
		! test -f Makefile || \
		! $$(TARGET_CONFIGURE_OPTS) $$($$(PKG)_MAKE_ENV) $$(MAKE) clean $$(QUITE) || true\
	)
endef

$(2)_POST_CONFIGURE_HOOKS += MAKECLEAN_AFTER_CONFIGURE_CMDS

ifneq ($(wildcard $($(PKGNAME)_PKGDIR)/Configure),)
$$($(2)_TARGET_CONFIGURE): $($(PKGNAME)_PKGDIR)/Configure
endif

$$($(2)_TARGET_CONFIGURE): $(PKG_CONFIG_HOST_BINARY)

endef

rv-generic-makefile = $(call inner-rv-generic-Makefile,$(pkgname),$(PKGNAME))
rv-generic-configure = $(call inner-rv-generic-configure,$(pkgname),$(PKGNAME))

RV_PKG_MAKE_EXTRA_ENV = \
	PKG_CONFIG_LIBDIR="$(TARGET_DIR)/usr/lib/pkgconfig:$(TARGET_DIR)/share/pkgconfig"

$(PKG_CONFIG_HOST_BINARY):
	cat $(@D)/pkg-config > $(@)
	sed -i '/^PKG_CONFIG_LIBDIR=/d' $(@)
	sed -i '2a\$(RV_PKG_MAKE_EXTRA_ENV)' $(@)
	sed -i '3a\PKG_CONFIG_SYSROOT_DIR=$(TARGET_DIR)' $(@)
	echo 'PKG_CONFIG_LIBDIR=$${PKG_CONFIG_LIBDIR}:$${DEFAULT_PKG_CONFIG_LIBDIR} PKG_CONFIG_SYSROOT_DIR=$${DEFAULT_PKG_CONFIG_SYSROOT_DIR} exec $${PKGCONFDIR}/pkgconf "$$@"' >> $(@)
	chmod a+x $(@)
