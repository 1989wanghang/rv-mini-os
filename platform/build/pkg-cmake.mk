# Copyright 2018 Rockchip Electronics Co., Ltd. All Rights Reserved.
# author: hertz.wang, wangh@rock-chips.com
# modified from buildroot/Makefile
#
# SPDX-License-Identifier: GPL-2.0-or-later
#


ifeq ($(BR2_ARM_CPU_ARMV4),y)
CMAKE_SYSTEM_PROCESSOR_ARM_VARIANT = armv4
else ifeq ($(BR2_ARM_CPU_ARMV5),y)
CMAKE_SYSTEM_PROCESSOR_ARM_VARIANT = armv5
else ifeq ($(BR2_ARM_CPU_ARMV6),y)
CMAKE_SYSTEM_PROCESSOR_ARM_VARIANT = armv6
else ifeq ($(BR2_ARM_CPU_ARMV7A),y)
CMAKE_SYSTEM_PROCESSOR_ARM_VARIANT = armv7
else ifeq ($(BR2_ARM_CPU_ARMV8A),y)
CMAKE_SYSTEM_PROCESSOR_ARM_VARIANT = armv8
endif

ifeq ($(BR2_arm),y)
CMAKE_SYSTEM_PROCESSOR = $(CMAKE_SYSTEM_PROCESSOR_ARM_VARIANT)l
else ifeq ($(BR2_armeb),y)
CMAKE_SYSTEM_PROCESSOR = $(CMAKE_SYSTEM_PROCESSOR_ARM_VARIANT)b
else
CMAKE_SYSTEM_PROCESSOR = $(BR2_ARCH)
endif

TOOLCHAINFILE_CMAKE = $(BUILD_DIR)/toolchainfile.cmake
$(TOOLCHAINFILE_CMAKE): $(BUILD_SCRIPT_DIR)/toolchainfile.cmake.in 
	$(Q)sed \
		-e 's#@@STAGING_DIR@@#$(call qstrip,$(BR_STAGING_DIR))#' \
		-e 's#@@TARGET_CFLAGS@@#$(call qstrip,$(TARGET_CFLAGS))#' \
		-e 's#@@TARGET_CXXFLAGS@@#$(call qstrip,$(TARGET_CXXFLAGS))#' \
		-e 's#@@TARGET_LDFLAGS@@#$(call qstrip,$(TARGET_LDFLAGS))#' \
		-e 's#@@TARGET_CC@@#$(subst $(BR_HOST_DIR)/bin/,,$(call qstrip,$(TARGET_CC)))#' \
		-e 's#@@TARGET_CXX@@#$(subst $(BR_HOST_DIR)/bin/,,$(call qstrip,$(TARGET_CXX)))#' \
		-e 's#@@CMAKE_SYSTEM_PROCESSOR@@#$(call qstrip,$(CMAKE_SYSTEM_PROCESSOR))#' \
		-e 's#@@CMAKE_BUILD_TYPE@@#$(if $(RV_ENABLE_DEBUG),Debug,Release)#' \
		$(<) \
		> $@

ifneq ($(QUIET),)
CMAKE_QUIET = -DCMAKE_RULE_MESSAGES=OFF
endif

CMAKE = cmake

# A generic same part cmake words for rv's libraries.
# $(1):pkg, $(2):PKG
define inner-rv-generic-cmake

$(2)_CONF_ENV			?=
$(2)_CONF_OPTS			?=
$(2)_MAKE			?= $$(MAKE)
$(2)_MAKE_ENV			?=
$(2)_MAKE_OPTS			?=
$(2)_INSTALL_OPTS		?= install
$(2)_INSTALL_STAGING_OPTS	?= DESTDIR=$$(STAGING_DIR) install/fast
$(2)_INSTALL_TARGET_OPTS	?= DESTDIR=$$(TARGET_DIR) install/fast

# destination: $(DESTDIR)/$(INSTALL_PREFIX)
ifndef $(2)_CONFIGURE_CMDS
define $(2)_CONFIGURE_CMDS
	$$($$(PKG)_MAKECLEAN_CMDS)
	$(Q)(mkdir -p $$($$(PKG)_BUILDDIR) && \
	cd $$($$(PKG)_BUILDDIR) && \
	rm -f CMakeCache.txt && \
	$$(TARGET_MAKE_ENV) \
	$$($$(PKG)_CONF_ENV) $$(CMAKE) $$(TOP_DIR)/$$($$(PKG)_PKGDIR) \
		-DCMAKE_TOOLCHAIN_FILE="$$(BUILD_DIR)/toolchainfile.cmake" \
		-DCMAKE_INSTALL_PREFIX="/usr" \
		-DCMAKE_COLOR_MAKEFILE=ON \
		-DCMAKE_INSTALL_MESSAGE=LAZY \
		-DBUILD_SHARED_LIBS=$$(if $$(RV_STATIC_LIBS),OFF,ON) \
		$$(CMAKE_QUIET) \
		$$($$(PKG)_CONF_OPTS) \
	)
endef
endif

ifndef $(2)_BUILD_CMDS
define $(2)_BUILD_CMDS
	$(Q)$$(TARGET_MAKE_ENV) $$($$(PKG)_MAKE_ENV) $$($$(PKG)_MAKE) $$($$(PKG)_MAKE_OPTS) -C $$($$(PKG)_BUILDDIR)
endef
endif

ifndef $(2)_INSTALL_TARGET_CMDS
define $(2)_INSTALL_TARGET_CMDS
	$(Q)$$(TARGET_MAKE_ENV) $$($$(PKG)_MAKE_ENV) $$($$(PKG)_MAKE) $$($$(PKG)_MAKE_OPTS) $$($$(PKG)_INSTALL_TARGET_OPTS) -C $$($$(PKG)_BUILDDIR)
endef
endif

ifndef $(2)_MAKECLEAN_CMDS
define $(2)_MAKECLEAN_CMDS
	$(Q)$$(if $$(wildcard $$($$(PKG)_BUILDDIR)install_manifest.txt),\
	cat $$($$(PKG)_BUILDDIR)install_manifest.txt | xargs rm -rf)
	$(Q)rm -rf $$($$(PKG)_BUILDDIR)
endef
endif

$(call inner-generic-package,$(1),$(2),$(2),target)

$$($(2)_TARGET_CONFIGURE): $(TOOLCHAINFILE_CMAKE) \
	$$($(PKGNAME)_PKGDIR)/CMakeLists.txt

endef

rv-generic-cmake = $(call inner-rv-generic-cmake,$(pkgname),$(PKGNAME))
