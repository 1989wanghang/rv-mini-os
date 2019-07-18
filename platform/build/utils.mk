# modified from buildroot/package/Makefile.in.

ifndef MAKE
MAKE := make
endif
ifndef HOSTMAKE
HOSTMAKE = $(MAKE)
endif
HOSTMAKE := $(shell which $(HOSTMAKE) || type -p $(HOSTMAKE) || echo make)

ifeq ($(RV_JLEVEL),0)
PARALLEL_JOBS := $(shell echo \
	$$((1 + `getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1`)))
else
PARALLEL_JOBS := $(RV_JLEVEL)
endif

# br jlevel keep consistent with rv
BR2_JLEVEL = $(RV_JLEVEL)
export BR2_JLEVEL

MAKE1 := $(HOSTMAKE) -j1
override MAKE = $(HOSTMAKE) \
	$(if $(findstring j,$(filter-out --%,$(MAKEFLAGS))),,-j$(PARALLEL_JOBS))

ifeq ($(BR2_TOOLCHAIN_BUILDROOT),y)
TARGET_VENDOR = $(call qstrip,$(BR2_TOOLCHAIN_BUILDROOT_VENDOR))
else
TARGET_VENDOR = buildroot
endif

# Sanity checks
ifeq ($(TARGET_VENDOR),)
$(error BR2_TOOLCHAIN_BUILDROOT_VENDOR is not allowed to be empty)
endif
ifeq ($(TARGET_VENDOR),unknown)
$(error BR2_TOOLCHAIN_BUILDROOT_VENDOR cannot be 'unknown'. \
	It might be confused with the native toolchain)
endif

# Compute GNU_TARGET_NAME
GNU_TARGET_NAME = $(ARCH)-$(TARGET_VENDOR)-$(TARGET_OS)-$(LIBC)$(ABI)

TARGET_OS = linux

ifeq ($(BR2_TOOLCHAIN_USES_UCLIBC),y)
LIBC = uclibc
else ifeq ($(BR2_TOOLCHAIN_USES_MUSL),y)
LIBC = musl
else
LIBC = gnu
endif

# The ABI suffix is a bit special on ARM, as it needs to be
# -uclibcgnueabi for uClibc EABI, and -gnueabi for glibc EABI.
# This means that the LIBC and ABI aren't strictly orthogonal,
# which explains why we need the test on LIBC below.
ifeq ($(BR2_arm)$(BR2_armeb),y)
ifeq ($(LIBC),uclibc)
ABI = gnueabi
else
ABI = eabi
endif

ifeq ($(BR2_ARM_EABIHF),y)
ABI := $(ABI)hf
endif
endif

ifeq ($(BR2_arc)$(BR2_ARC_ATOMIC_EXT),yy)
TARGET_ABI += -matomic
endif

STAGING_SUBDIR = $(GNU_TARGET_NAME)/sysroot
STAGING_DIR    = $(BR_HOST_DIR)/$(STAGING_SUBDIR)

ifeq ($(RV_OPTIMIZE_0),y)
TARGET_OPTIMIZATION = -O0
endif
ifeq ($(RV_OPTIMIZE_1),y)
TARGET_OPTIMIZATION = -O1
endif
ifeq ($(RV_OPTIMIZE_2),y)
TARGET_OPTIMIZATION = -O2
endif
ifeq ($(RV_OPTIMIZE_3),y)
TARGET_OPTIMIZATION = -O3
endif
ifeq ($(RV_OPTIMIZE_G),y)
TARGET_OPTIMIZATION = -Og
endif
ifeq ($(RV_OPTIMIZE_S),y)
TARGET_OPTIMIZATION = -Os
endif
ifeq ($(RV_OPTIMIZE_FAST),y)
TARGET_OPTIMIZATION = -Ofast
endif

TARGET_DEBUGGING = -DNDEBUG
ifeq ($(RV_DEBUG_1),y)
TARGET_DEBUGGING = -g1 -DDEBUG
endif
ifeq ($(RV_DEBUG_2),y)
TARGET_DEBUGGING = -g2 -DDEBUG
endif
ifeq ($(RV_DEBUG_3),y)
TARGET_DEBUGGING = -g3 -DDEBUG
endif

TARGET_CFLAGS_RELRO = -Wl,-z,relro
TARGET_CFLAGS_RELRO_FULL = -Wl,-z,now $(TARGET_CFLAGS_RELRO)

ifeq ($(RV_SSP_REGULAR),y)
TARGET_CPPFLAGS += -fstack-protector
else ifeq ($(RV_SSP_STRONG),y)
TARGET_CPPFLAGS += -fstack-protector-strong
else ifeq ($(RV_SSP_ALL),y)
TARGET_CPPFLAGS += -fstack-protector-all
endif

ifeq ($(RV_RELRO_PARTIAL),y)
TARGET_CPPFLAGS += $(TARGET_CFLAGS_RELRO)
TARGET_LDFLAGS += $(TARGET_CFLAGS_RELRO)
else ifeq ($(RV_RELRO_FULL),y)
TARGET_CPPFLAGS += -fPIE $(TARGET_CFLAGS_RELRO_FULL)
TARGET_LDFLAGS += -pie
endif

ifeq ($(RV_FORTIFY_SOURCE_1),y)
TARGET_CPPFLAGS += -D_FORTIFY_SOURCE=1
else ifeq ($(RV_FORTIFY_SOURCE_2),y)
TARGET_CPPFLAGS += -D_FORTIFY_SOURCE=2
endif

TARGET_GENERIC_CFLAGS = -I$(TARGET_DIR)/usr/include -I$(BR_STAGING_DIR)/usr/include \
	-fPIC -ffunction-sections -fdata-sections
TARGET_GENERIC_LDFLAGS = -L$(TARGET_DIR)/usr/lib -I$(BR_STAGING_DIR)/usr/lib \
	-Wl,--gc-sections

TARGET_CPPFLAGS += -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 $(TARGET_GENERIC_CFLAGS)
TARGET_CFLAGS = $(TARGET_CPPFLAGS) $(TARGET_ABI) $(TARGET_OPTIMIZATION) $(TARGET_DEBUGGING)
TARGET_CXXFLAGS = $(TARGET_CFLAGS)
TARGET_FCFLAGS = $(TARGET_ABI) $(TARGET_OPTIMIZATION) $(TARGET_DEBUGGING)
TARGET_LDFLAGS = $(TARGET_GENERIC_LDFLAGS)

ifeq ($(BR2_TOOLCHAIN_BUILDROOT),y)
TARGET_CROSS = $(BR_HOST_DIR)/bin/$(GNU_TARGET_NAME)-
else
TOOLCHAIN_EXTERNAL_PREFIX = $(call qstrip,$(BR2_TOOLCHAIN_EXTERNAL_PREFIX))
TARGET_CROSS = $(BR_HOST_DIR)/bin/$(TOOLCHAIN_EXTERNAL_PREFIX)-
endif

# Define TARGET_xx variables for all common binutils/gcc
TARGET_AR       = $(TARGET_CROSS)ar
TARGET_AS       = $(TARGET_CROSS)as
TARGET_CC       = $(TARGET_CROSS)gcc
TARGET_CPP      = $(TARGET_CROSS)cpp
TARGET_CXX      = $(TARGET_CROSS)g++
TARGET_FC       = $(TARGET_CROSS)gfortran
TARGET_LD       = $(TARGET_CROSS)ld
TARGET_NM       = $(TARGET_CROSS)nm
TARGET_RANLIB   = $(TARGET_CROSS)ranlib
TARGET_READELF  = $(TARGET_CROSS)readelf
TARGET_OBJCOPY  = $(TARGET_CROSS)objcopy
TARGET_OBJDUMP  = $(TARGET_CROSS)objdump

ifeq ($(RV_STRIP_strip),y)
STRIP_STRIP_DEBUG := --strip-debug
TARGET_STRIP = $(TARGET_CROSS)strip
STRIPCMD = $(TARGET_CROSS)strip --remove-section=.comment --remove-section=.note
else
TARGET_STRIP = /bin/true
STRIPCMD = $(TARGET_STRIP)
endif
INSTALL := $(shell which install || type -p install)
FLEX := $(shell which flex || type -p flex)
BISON := $(shell which bison || type -p bison)
UNZIP := $(shell which unzip || type -p unzip) -q

APPLY_PATCHES = PATH=$(BR_HOST_DIR)/bin:$$PATH $(BR_TOP_DIR)/support/scripts/apply-patches.sh $(if $(QUIET),-s)

HOST_CPPFLAGS  = -I$(BR_HOST_DIR)/include
HOST_CFLAGS   ?= -O2
HOST_CFLAGS   += $(HOST_CPPFLAGS)
HOST_CXXFLAGS += $(HOST_CFLAGS)
HOST_LDFLAGS  += -L$(HOST_DIR)/lib -Wl,-rpath,$(HOST_DIR)/lib

# The macros below are taken from linux 4.11 and adapted slightly.
# Copy more when needed.

# try-run
# Usage: option = $(call try-run, $(CC)...-o "$$TMP",option-ok,otherwise)
# Exit code chooses option. "$$TMP" is can be used as temporary file and
# is automatically cleaned up.
try-run = $(shell set -e;               \
	TMP="$$(tempfile)";             \
	if ($(1)) >/dev/null 2>&1;      \
	then echo "$(2)";               \
	else echo "$(3)";               \
	fi;                             \
	rm -f "$$TMP")

# host-cc-option
# Usage: HOST_FOO_CFLAGS += $(call host-cc-option,-no-pie,)
host-cc-option = $(call try-run,\
        $(HOSTCC) $(HOST_CFLAGS) $(1) -c -x c /dev/null -o "$$TMP",$(1),$(2))


# host-intltool should be executed with the system perl, so we save
# the path to the system perl, before a host-perl built by Buildroot
# might get installed into $(HOST_DIR)/bin and therefore appears
# in our PATH. This system perl will be used as INTLTOOL_PERL.
export PERL=$(shell which perl)

# host-intltool needs libxml-parser-perl, which Buildroot installs in
# $(HOST_DIR)/lib/perl, so we must make sure that the system perl
# finds this perl module by exporting the proper value for PERL5LIB.
export PERL5LIB=$(BR_HOST_DIR)/lib/perl

PKG_CONFIG_HOST_BINARY = $(BR_HOST_DIR)/bin/rv-pkg-config

TARGET_MAKE_ENV = PATH=$(BR_PATH)

TARGET_CONFIGURE_OPTS = \
	$(TARGET_MAKE_ENV) \
	AR="$(TARGET_AR)" \
	AS="$(TARGET_AS)" \
	LD="$(TARGET_LD)" \
	NM="$(TARGET_NM)" \
	CC="$(TARGET_CC)" \
	GCC="$(TARGET_CC)" \
	CPP="$(TARGET_CPP)" \
	CXX="$(TARGET_CXX)" \
	FC="$(TARGET_FC)" \
	F77="$(TARGET_FC)" \
	RANLIB="$(TARGET_RANLIB)" \
	READELF="$(TARGET_READELF)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)" \
	OBJDUMP="$(TARGET_OBJDUMP)" \
	AR_FOR_BUILD="$(HOSTAR)" \
	AS_FOR_BUILD="$(HOSTAS)" \
	CC_FOR_BUILD="$(HOSTCC)" \
	GCC_FOR_BUILD="$(HOSTCC)" \
	CXX_FOR_BUILD="$(HOSTCXX)" \
	LD_FOR_BUILD="$(HOSTLD)" \
	CPPFLAGS_FOR_BUILD="$(HOST_CPPFLAGS)" \
	CFLAGS_FOR_BUILD="$(HOST_CFLAGS)" \
	CXXFLAGS_FOR_BUILD="$(HOST_CXXFLAGS)" \
	LDFLAGS_FOR_BUILD="$(HOST_LDFLAGS)" \
	FCFLAGS_FOR_BUILD="$(HOST_FCFLAGS)" \
	DEFAULT_ASSEMBLER="$(TARGET_AS)" \
	DEFAULT_LINKER="$(TARGET_LD)" \
	CPPFLAGS="$(TARGET_CPPFLAGS)" \
	CFLAGS="$(TARGET_CFLAGS)" \
	CXXFLAGS="$(TARGET_CXXFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	FCFLAGS="$(TARGET_FCFLAGS)" \
	FFLAGS="$(TARGET_FCFLAGS)" \
	STAGING_DIR="$(STAGING_DIR)" \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)"
	INTLTOOL_PERL=$(PERL)


HOST_MAKE_ENV = \
	PATH=$(BR_PATH) \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG_SYSROOT_DIR="/" \
	PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1 \
	PKG_CONFIG_ALLOW_SYSTEM_LIBS=1 \
	PKG_CONFIG_LIBDIR="$(HOST_DIR)/lib/pkgconfig:$(HOST_DIR)/share/pkgconfig"

HOST_CONFIGURE_OPTS = \
	$(HOST_MAKE_ENV) \
	AR="$(HOSTAR)" \
	AS="$(HOSTAS)" \
	LD="$(HOSTLD)" \
	NM="$(HOSTNM)" \
	CC="$(HOSTCC)" \
	GCC="$(HOSTCC)" \
	CXX="$(HOSTCXX)" \
	CPP="$(HOSTCPP)" \
	OBJCOPY="$(HOSTOBJCOPY)" \
	RANLIB="$(HOSTRANLIB)" \
	CPPFLAGS="$(HOST_CPPFLAGS)" \
	CFLAGS="$(HOST_CFLAGS)" \
	CXXFLAGS="$(HOST_CXXFLAGS)" \
	LDFLAGS="$(HOST_LDFLAGS)" \
	INTLTOOL_PERL=$(PERL)

################################################################################
# settings we need to pass to configure

# does unaligned access trap?
BR2_AC_CV_TRAP_CHECK = ac_cv_lbl_unaligned_fail=yes
ifeq ($(BR2_i386),y)
BR2_AC_CV_TRAP_CHECK = ac_cv_lbl_unaligned_fail=no
endif
ifeq ($(BR2_x86_64),y)
BR2_AC_CV_TRAP_CHECK = ac_cv_lbl_unaligned_fail=no
endif
ifeq ($(BR2_m68k),y)
BR2_AC_CV_TRAP_CHECK = ac_cv_lbl_unaligned_fail=no
endif
ifeq ($(BR2_powerpc)$(BR2_powerpc64)$(BR2_powerpc64le),y)
BR2_AC_CV_TRAP_CHECK = ac_cv_lbl_unaligned_fail=no
endif

ifeq ($(BR2_ENDIAN),"BIG")
BR2_AC_CV_C_BIGENDIAN = ac_cv_c_bigendian=yes
else
BR2_AC_CV_C_BIGENDIAN = ac_cv_c_bigendian=no
endif

# AM_GNU_GETTEXT misdetects musl gettext support.
# musl currently implements api level 1 and 2 (basic + ngettext)
# http://www.openwall.com/lists/musl/2015/04/16/3
#
# These autoconf variables should only be pre-seeded when the minimal
# gettext implementation of musl is used. When the full blown
# implementation provided by gettext libintl is used, auto-detection
# works fine, and pre-seeding those values is actually wrong.
ifeq ($(BR2_TOOLCHAIN_USES_MUSL):$(BR2_PACKAGE_GETTEXT_PROVIDES_LIBINTL),y:)
BR2_GT_CV_FUNC_GNUGETTEXT_LIBC = \
	gt_cv_func_gnugettext1_libc=yes \
	gt_cv_func_gnugettext2_libc=yes
endif

TARGET_CONFIGURE_ARGS = \
	$(BR2_AC_CV_TRAP_CHECK) \
	ac_cv_func_mmap_fixed_mapped=yes \
	ac_cv_func_memcmp_working=yes \
	ac_cv_have_decl_malloc=yes \
	gl_cv_func_malloc_0_nonnull=yes \
	ac_cv_func_malloc_0_nonnull=yes \
	ac_cv_func_calloc_0_nonnull=yes \
	ac_cv_func_realloc_0_nonnull=yes \
	lt_cv_sys_lib_search_path_spec="" \
	$(BR2_AC_CV_C_BIGENDIAN) \
	$(BR2_GT_CV_FUNC_GNUGETTEXT_LIBC)

################################################################################

ifeq ($(BR2_SYSTEM_ENABLE_NLS),y)
NLS_OPTS = --enable-nls
TARGET_NLS_DEPENDENCIES = host-gettext
ifeq ($(BR2_PACKAGE_GETTEXT_PROVIDES_LIBINTL),y)
TARGET_NLS_DEPENDENCIES += gettext
TARGET_NLS_LIBS += -lintl
endif
else
NLS_OPTS = --disable-nls
endif

ifneq ($(BR2_INSTALL_LIBSTDCPP),y)
TARGET_CONFIGURE_OPTS += CXX=no
endif

ifeq ($(RV_STATIC_LIBS),y)
SHARED_STATIC_LIBS_OPTS = --enable-static --disable-shared
TARGET_CFLAGS += -static
TARGET_CXXFLAGS += -static
TARGET_FCFLAGS += -static
TARGET_LDFLAGS += -static
else ifeq ($(RV_SHARED_LIBS),y)
SHARED_STATIC_LIBS_OPTS = --disable-static --enable-shared
else ifeq ($(RV_SHARED_STATIC_LIBS),y)
SHARED_STATIC_LIBS_OPTS = --enable-static --enable-shared
endif

include $(BUILD_SCRIPT_DIR)/extra_utils.mk
include $(BUILD_SCRIPT_DIR)/pkg-autotools.mk
include $(BUILD_SCRIPT_DIR)/pkg-makefile.mk
include $(BUILD_SCRIPT_DIR)/pkg-cmake.mk
-include $(BUILD_SCRIPT_DIR)/pkg-cp.mk
include $(BUILD_SCRIPT_DIR)/pkg-generic.mk
include $(BUILD_SCRIPT_DIR)/pkg-kconfig.mk
