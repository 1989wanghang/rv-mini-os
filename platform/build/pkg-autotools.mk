# modified from buildroot/package/pkg-autotools.mk

################################################################################
# Autotools package infrastructure
#
# This file implements an infrastructure that eases development of
# package .mk files for autotools packages. It should be used for all
# packages that use the autotools as their build system.
#
# See the Buildroot documentation for details on the usage of this
# infrastructure
#
# In terms of implementation, this autotools infrastructure requires
# the .mk file to only specify metadata information about the
# package: name, version, download URL, etc.
#
# We still allow the package .mk file to override what the different
# steps are doing, if needed. For example, if <PKG>_BUILD_CMDS is
# already defined, it is used as the list of commands to perform to
# build the package, instead of the default autotools behaviour. The
# package can also define some post operation hooks.
#
################################################################################


# variables used by other packages
AUTOCONF = $(BR_HOST_DIR)/bin/autoconf
AUTOHEADER = $(BR_HOST_DIR)/bin/autoheader
AUTOMAKE = $(BR_HOST_DIR)/bin/automake
ACLOCAL_HOST_DIR = $(BR_HOST_DIR)/share/aclocal
ACLOCAL_DIR = $(BR_TOP_DIR)/output/staging/usr/share/aclocal
ACLOCAL = $(BR_HOST_DIR)/bin/aclocal -I $(ACLOCAL_DIR)

AUTORECONF = $(HOST_CONFIGURE_OPTS) ACLOCAL="$(ACLOCAL)" AUTOCONF="$(AUTOCONF)" \
	AUTOHEADER="$(AUTOHEADER)" AUTOMAKE="$(AUTOMAKE)" AUTOPOINT=/bin/true \
	$(BR_HOST_DIR)/bin/autoreconf -f -i -I "$(ACLOCAL_DIR)" -I "$(ACLOCAL_HOST_DIR)"

#
# Utility function to upgrade config.sub and config.guess files
#
# argument 1 : directory into which config.guess and config.sub need
# to be updated. Note that config.sub and config.guess are searched
# recursively in this directory.
#
define CONFIG_UPDATE
	for file in config.guess config.sub; do \
		for i in $$(find $(1) -name $$file); do \
			cp -a $(BR_TOP_DIR)/support/gnuconfig/$$file $$i; \
		done; \
	done
endef

# This function generates the ac_cv_file_<foo> value for a given
# filename. This is needed to convince configure script doing
# AC_CHECK_FILE() tests that the file actually exists, since such
# tests cannot be done in a cross-compilation context. This function
# takes as argument the path of the file. An example usage is:
#
#  FOOBAR_CONF_ENV = \
#	$(call AUTOCONF_AC_CHECK_FILE_VAL,/dev/random)=yes
AUTOCONF_AC_CHECK_FILE_VAL = ac_cv_file_$(subst -,_,$(subst /,_,$(subst .,_,$(1))))

#
# Hook to update config.sub and config.guess if needed
#
define UPDATE_CONFIG_HOOK
	@$(call MESSAGE,"Updating config.sub and config.guess")
	$(call CONFIG_UPDATE,$($(PKG)_PKGDIR))
endef

#
# Hook to patch libtool to make it work properly for cross-compilation
#
define LIBTOOL_PATCH_HOOK
	@$(call MESSAGE,"Patching libtool")
	$(Q)for i in `find $($(PKG)_PKGDIR) -name ltmain.sh`; do \
		ltmain_version=`sed -n '/^[ \t]*VERSION=/{s/^[ \t]*VERSION=//;p;q;}' $$i | \
		sed -e 's/\([0-9]*\.[0-9]*\).*/\1/' -e 's/\"//'`; \
		ltmain_patchlevel=`sed -n '/^[ \t]*VERSION=/{s/^[ \t]*VERSION=//;p;q;}' $$i | \
		sed -e 's/\([0-9]*\.[0-9]*\.*\)\([0-9]*\).*/\2/' -e 's/\"//'`; \
		if test $${ltmain_version} = '1.5'; then \
			patch -i $(BR_TOP_DIR)/support/libtool/buildroot-libtool-v1.5.patch $${i}; \
		elif test $${ltmain_version} = "2.2"; then\
			patch -i $(BR_TOP_DIR)/support/libtool/buildroot-libtool-v2.2.patch $${i}; \
		elif test $${ltmain_version} = "2.4"; then\
			if test $${ltmain_patchlevel:-0} -gt 2; then\
				patch -i $(BR_TOP_DIR)/support/libtool/buildroot-libtool-v2.4.4.patch $${i}; \
			else \
				patch -i $(BR_TOP_DIR)/support/libtool/buildroot-libtool-v2.4.patch $${i}; \
			fi \
		fi \
	done
endef

#
# Hook to gettextize the package if needed
#
define GETTEXTIZE_HOOK
	@$(call MESSAGE,"Gettextizing")
	$(Q)cd $($(PKG)_PKGDIR) && $(GETTEXTIZE) $($(PKG)_GETTEXTIZE_OPTS)
endef

#
# Hook to autoreconf the package if needed
#
define AUTORECONF_HOOK
	@$(call MESSAGE,"Autoreconfiguring")
	$(Q)cd $($(PKG)_PKGDIR) && \
	$($(PKG)_AUTORECONF_ENV) $(AUTORECONF) $($(PKG)_AUTORECONF_OPTS)
endef

################################################################################
# inner-rv-generic-autotools -- defines how the configuration, compilation and
# installation of an autotools package should be done, implements a
# few hooks to tune the build process for autotools specifities and
# calls the generic package infrastructure to generate the necessary
# make targets
#
#  argument 1 is the lowercase package name
#  argument 2 is the uppercase package name, including a HOST_ prefix
#             for host packages
################################################################################

define inner-rv-generic-autotools

ifndef $(2)_LIBTOOL_PATCH
  $(2)_LIBTOOL_PATCH ?= YES
endif

ifndef $(2)_MAKE
  $(2)_MAKE ?= $$(MAKE)
endif

ifndef $(2)_AUTORECONF
  $(2)_AUTORECONF ?= YES
endif

ifndef $(2)_GETTEXTIZE
  $(2)_GETTEXTIZE ?= NO
endif

$(2)_CONF_ENV			?=
$(2)_CONF_OPTS			?=
$(2)_MAKE_ENV			?=
$(2)_MAKE_OPTS			?=
$(2)_INSTALL_OPTS		?= install
$(2)_INSTALL_STAGING_OPTS	?= DESTDIR=$$(STAGING_DIR) install
$(2)_INSTALL_TARGET_OPTS	?= DESTDIR=$$(TARGET_DIR) install

#
# Configure step. Only define it if not already defined by the package
# .mk file. And take care of the differences between host and target
# packages.
#
ifndef $(2)_CONFIGURE_CMDS

# Configure package for target
define $(2)_CONFIGURE_CMDS
	$(Q)(cd $$($$(PKG)_PKGDIR) && rm -rf config.cache && \
	$$(TARGET_CONFIGURE_OPTS) \
	$$(TARGET_CONFIGURE_ARGS) \
	$$($$(PKG)_CONF_ENV) \
	CONFIG_SITE=/dev/null \
	./configure \
		--target=$$(GNU_TARGET_NAME) \
		--host=$$(GNU_TARGET_NAME) \
		--build=$$(GNU_HOST_NAME) \
		--prefix=/usr \
		--exec-prefix=/usr \
		--sysconfdir=/etc \
		--localstatedir=/var \
		--program-prefix="" \
		--disable-gtk-doc \
		--disable-gtk-doc-html \
		--disable-doc \
		--disable-docs \
		--disable-documentation \
		--with-xmlto=no \
		--with-fop=no \
		$$(if $$($$(PKG)_OVERRIDE_SRCDIR),,--disable-dependency-tracking) \
		--enable-ipv6 \
		$$(NLS_OPTS) \
		$$(SHARED_STATIC_LIBS_OPTS) \
		$$(QUIET) $$($$(PKG)_CONF_OPTS) \
	)
endef

endif

$(2)_PRE_CONFIGURE_HOOKS += UPDATE_CONFIG_HOOK

ifeq ($$($(2)_AUTORECONF),YES)

# This has to come before autoreconf
ifeq ($$($(2)_GETTEXTIZE),YES)
$(2)_PRE_CONFIGURE_HOOKS += GETTEXTIZE_HOOK
#$(2)_DEPENDENCIES += host-gettext
endif
$(2)_PRE_CONFIGURE_HOOKS += AUTORECONF_HOOK
# default values are not evaluated yet, so don't rely on this defaulting to YES
ifneq ($$($(2)_LIBTOOL_PATCH),NO)
$(2)_PRE_CONFIGURE_HOOKS += LIBTOOL_PATCH_HOOK
endif

else # ! AUTORECONF = YES

# default values are not evaluated yet, so don't rely on this defaulting to YES
ifneq ($$($(2)_LIBTOOL_PATCH),NO)
$(2)_PRE_CONFIGURE_HOOKS += LIBTOOL_PATCH_HOOK
endif

endif

#
# Build step. Only define it if not already defined by the package .mk
# file.
#
ifndef $(2)_BUILD_CMDS
define $(2)_BUILD_CMDS
	$(Q)$$(TARGET_MAKE_ENV) $$($$(PKG)_MAKE_ENV) $$($$(PKG)_MAKE) $$($$(PKG)_MAKE_OPTS) -C $$($$(PKG)_PKGDIR)
endef
endif

#
# Target installation step. Only define it if not already defined by
# the package .mk file.
#
ifndef $(2)_INSTALL_TARGET_CMDS
define $(2)_INSTALL_TARGET_CMDS
	$(Q)$$(TARGET_MAKE_ENV) $$($$(PKG)_MAKE_ENV) $$($$(PKG)_MAKE) $$($$(PKG)_INSTALL_TARGET_OPTS) -C $$($$(PKG)_PKGDIR)
endef
endif

ifndef $(2)_MAKECLEAN_CMDS
define $(2)_MAKECLEAN_CMDS
	$(Q)(cd $$($$(PKG)_PKGDIR) && \
		! test -f Makefile || \
		! $$(TARGET_MAKE_ENV) $$($$(PKG)_MAKE_ENV) $$($$(PKG)_MAKE) distclean $$(QUITE) || true\
	)
endef
endif

# Call the generic package infrastructure to generate the necessary
# make targets
$(call inner-generic-package,$(1),$(2),$(2),target)

$$($(2)_TARGET_CONFIGURE) : $$(wildcard $$($$(PKG)_PKGDIR)/configure.ac) \
	$$(wildcard $$($$(PKG)_PKGDIR)/Makefile.am)

endef

################################################################################
# autotools-package -- the target generator macro for autotools packages
################################################################################

rv-generic-autotools = $(call inner-rv-generic-autotools,$(pkgname),$(PKGNAME))
