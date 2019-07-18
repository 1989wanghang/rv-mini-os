# modified from buildroot/package/pkg-generic.mk
# remove download target, which should not do in compiling in my opinion

################################################################################
# Generic package infrastructure
#
# This file implements an infrastructure that eases development of
# package .mk files. It should be used for packages that do not rely
# on a well-known build system for which Buildroot has a dedicated
# infrastructure (so far, Buildroot has special support for
# autotools-based and CMake-based packages).
#
# See the Buildroot documentation for details on the usage of this
# infrastructure
#
# In terms of implementation, this generic infrastructure requires the
# .mk file to specify:
#
#   1. Metadata information about the package: name, version,
#      download URL, etc.
#
#   2. Description of the commands to be executed to configure, build
#      and install the package
################################################################################

################################################################################
# Helper functions to catch start/end of each step
################################################################################

# Those two functions are called by each step below.
# They are responsible for calling all hooks defined in
# $(GLOBAL_INSTRUMENTATION_HOOKS) and pass each of them
# three arguments:
#   $1: either 'start' or 'end'
#   $2: the name of the step
#   $3: the name of the package

# Start step
# $1: step name
define step_start
	$(foreach hook,$(GLOBAL_INSTRUMENTATION_HOOKS),$(call $(hook),start,$(1),$($(PKG)_NAME))$(sep))
endef

# End step
# $1: step name
define step_end
	$(foreach hook,$(GLOBAL_INSTRUMENTATION_HOOKS),$(call $(hook),end,$(1),$($(PKG)_NAME))$(sep))
endef

#######################################
# Actual steps hooks

# Time steps
define step_time
	printf "%s:%-5.5s:%-20.20s: %s\n"           \
	       "$$(date +%s)" "$(1)" "$(2)" "$(3)"  \
	       >>"$(BUILD_DIR)/build-time.log"
endef
GLOBAL_INSTRUMENTATION_HOOKS += step_time

################################################################################
# Implicit targets -- produce a stamp file for each step of a package build
################################################################################

# Configure
$(BUILD_DIR)/%/.stamp_configured:
	@$(call step_start,configure)
	@$(call MESSAGE,"Configuring")
	$(foreach hook,$($(PKG)_PRE_CONFIGURE_HOOKS),$(call $(hook))$(sep))
	$(Q)mkdir -p $($(PKG)_BUILDDIR)
	$($(PKG)_CONFIGURE_CMDS)
	$(foreach hook,$($(PKG)_POST_CONFIGURE_HOOKS),$(call $(hook))$(sep))
	@$(call step_end,configure)
	$(Q)touch $@

# Build
$(BUILD_DIR)/%/.stamp_built::
	@$(call step_start,build)
	@$(call MESSAGE,"Building")
	$(foreach hook,$($(PKG)_PRE_BUILD_HOOKS),$(call $(hook))$(sep))
	+$($(PKG)_BUILD_CMDS)
	$(foreach hook,$($(PKG)_POST_BUILD_HOOKS),$(call $(hook))$(sep))
	@$(call step_end,build)

# Install to target dir
$(BUILD_DIR)/%/.stamp_target_installed:
	@$(call step_start,install-target)
	@$(call MESSAGE,"Installing to target")
	$(foreach hook,$($(PKG)_PRE_INSTALL_TARGET_HOOKS),$(call $(hook))$(sep))
	+$($(PKG)_INSTALL_TARGET_CMDS)
	$(if $(BR2_INIT_SYSTEMD),\
		$($(PKG)_INSTALL_INIT_SYSTEMD))
	$(if $(BR2_INIT_SYSV)$(BR2_INIT_BUSYBOX),\
		$($(PKG)_INSTALL_INIT_SYSV))
	$(foreach hook,$($(PKG)_POST_INSTALL_TARGET_HOOKS),$(call $(hook))$(sep))
	$(Q)if test -n "$($(PKG)_CONFIG_SCRIPTS)" ; then \
		$(RM) -f $(addprefix $(TARGET_DIR)/usr/bin/,$($(PKG)_CONFIG_SCRIPTS)) ; \
	fi
	@$(call step_end,install-target)
	$(Q)touch $@

# Remove package sources
$(BUILD_DIR)/%/.stamp_dircleaned:
	$(Q)rm -Rf $(@D)
	
$(BUILD_DIR)/%/.stamp_makeclean:
	@$(call MESSAGE,"MAKECLEANING")
	$(foreach hook,$($(PKG)_PRE_MAKECLEAN_TARGET_HOOKS),$(call $(hook))$(sep))
	$($(PKG)_MAKECLEAN_CMDS)
	$(foreach hook,$($(PKG)_POST_MAKECLEAN_TARGET_HOOKS),$(call $(hook))$(sep))

################################################################################
# inner-generic-package -- generates the make targets needed to build a
# generic package
#
#  argument 1 is the lowercase package name
#  argument 2 is the uppercase package name, including a HOST_ prefix
#             for host packages
#  argument 3 is the uppercase package name, without the HOST_ prefix
#             for host packages
#  argument 4 is the type (target or host)
#
# Note about variable and function references: inside all blocks that are
# evaluated with $(eval), which includes all 'inner-xxx-package' blocks,
# specific rules apply with respect to variable and function references.
# - Numbered variables (parameters to the block) can be referenced with a single
#   dollar sign: $(1), $(2), $(3), etc.
# - pkgdir and pkgname should be referenced with a single dollar sign too. These
#   functions rely on 'the most recently parsed makefile' which is supposed to
#   be the package .mk file. If we defer the evaluation of these functions using
#   double dollar signs, then they may be evaluated too late, when other
#   makefiles have already been parsed. One specific case is when $$(pkgdir) is
#   assigned to a variable using deferred evaluation with '=' and this variable
#   is used in a target rule outside the eval'ed inner block. In this case, the
#   pkgdir will be that of the last makefile parsed by buildroot, which is not
#   the expected value. This mechanism is for example used for the TARGET_PATCH
#   rule.
# - All other variables should be referenced with a double dollar sign:
#   $$(TARGET_DIR), $$($(2)_VERSION), etc. Also all make functions should be
#   referenced with a double dollar sign: $$(subst), $$(call), $$(filter-out),
#   etc. This rule ensures that these variables and functions are only expanded
#   during the $(eval) step, and not earlier. Otherwise, unintuitive and
#   undesired behavior occurs with respect to these variables and functions.
#
################################################################################

define inner-generic-package

# override the $(PKGNAME)_SITE
# override the $(pkgdir)
ifneq ($$(wildcard $(pkgdir)dl.ini),)
ifeq ($$(wildcard $(pkgdir).dl),)
$$(error '$(pkgname)' have not download? try ./dl.py $$(subst $(TOP_DIR)/,,$$(call remove-last-slash,$(pkgdir))))
endif
endif
ifneq ($$(wildcard $(pkgdir).dl),)
$(2)_SITE := $(pkgdir)$$(shell cat $(pkgdir).dl)
else
$(2)_SITE := $$(call remove-last-slash,$(pkgdir))
endif

$(2)_SITE_METHOD = local

# Ensure the package is only declared once, i.e. do not accept that a
# package be re-defined by a br2-external tree
ifneq ($(call strip,$(filter $(1),$(PACKAGES_ALL))),)
$$(error Package '$(1)' defined a second time in '$(pkgdir)'; \
	previous definition was in '$$($(2)_PKGDIR)')
endif
PACKAGES_ALL += $(1)

# Define default values for various package-related variables, if not
# already defined. For some variables (version, source, site and
# subdir), if they are undefined, we try to see if a variable without
# the HOST_ prefix is defined. If so, we use such a variable, so that
# this information has only to be specified once, for both the
# target and host packages of a given .mk file.

$(2)_TYPE                       =  $(4)
$(2)_NAME			=  $(1)
$(2)_RAWNAME			=  $$(patsubst host-%,%,$(1))
$(2)_PKGDIR			=  $$($(2)_SITE)

# Keep the package version that may contain forward slashes in the _DL_VERSION
# variable, then replace all forward slashes ('/') by underscores ('_') to
# sanitize the package version that is used in paths, directory and file names.
# Forward slashes may appear in the package's version when pointing to a
# version control system branch or tag, for example remotes/origin/1_10_stable.
# Similar for spaces and colons (:) that may appear in date-based revisions for
# CVS.
ifndef $(2)_VERSION
 ifdef $(3)_DL_VERSION
  $(2)_DL_VERSION := $$($(3)_DL_VERSION)
 else ifdef $(3)_VERSION
  $(2)_DL_VERSION := $$($(3)_VERSION)
 endif
else
 $(2)_DL_VERSION := $$(strip $$($(2)_VERSION))
endif
$(2)_VERSION := $$(call sanitize,$$($(2)_DL_VERSION))

ifdef $(3)_OVERRIDE_SRCDIR
  $(2)_OVERRIDE_SRCDIR ?= $$($(3)_OVERRIDE_SRCDIR)
endif

$(2)_BASENAME	= $$(if $$($(2)_VERSION),$(1)-$$($(2)_VERSION),$(1))
$(2)_BASENAME_RAW = $$(if $$($(2)_VERSION),$$($(2)_RAWNAME)-$$($(2)_VERSION),$$($(2)_RAWNAME))
$(2)_DL_DIR	=  $$(DL_DIR)
$(2)_DIR	=  $$(BUILD_DIR)/$$($(2)_BASENAME)

ifndef $(2)_SUBDIR
 ifdef $(3)_SUBDIR
  $(2)_SUBDIR = $$($(3)_SUBDIR)
 else
  $(2)_SUBDIR ?=
 endif
endif

ifndef $(2)_STRIP_COMPONENTS
 ifdef $(3)_STRIP_COMPONENTS
  $(2)_STRIP_COMPONENTS = $$($(3)_STRIP_COMPONENTS)
 else
  $(2)_STRIP_COMPONENTS ?= 1
 endif
endif

$(2)_SRCDIR		       = $$($(2)_DIR)/$$($(2)_SUBDIR)
$(2)_BUILDDIR		       ?= $$($(2)_SRCDIR)

ifneq ($$($(2)_OVERRIDE_SRCDIR),)
$(2)_VERSION = custom
endif

ifndef $(2)_SITE
 ifdef $(3)_SITE
  $(2)_SITE = $$($(3)_SITE)
 endif
endif

ifndef $(2)_SITE_METHOD
 ifdef $(3)_SITE_METHOD
  $(2)_SITE_METHOD = $$($(3)_SITE_METHOD)
 else
	# Try automatic detection using the scheme part of the URI
	$(2)_SITE_METHOD = $$(call geturischeme,$$($(2)_SITE))
 endif
endif

ifeq ($$($(2)_SITE_METHOD),local)
ifeq ($$($(2)_OVERRIDE_SRCDIR),)
$(2)_OVERRIDE_SRCDIR = $$($(2)_SITE)
endif
endif

# When a target package is a toolchain dependency set this variable to
# 'NO' so the 'toolchain' dependency is not added to prevent a circular
# dependency.
# Similarly for the skeleton.
$(2)_ADD_TOOLCHAIN_DEPENDENCY	?= YES

ifeq ($(4),target)
ifeq ($$($(2)_ADD_TOOLCHAIN_DEPENDENCY),YES)
$(2)_DEPENDENCIES += buildroot
endif
endif

# Eliminate duplicates in dependencies
$(2)_FINAL_DEPENDENCIES = $$(sort $$($(2)_DEPENDENCIES))
$(2)_FINAL_ALL_DEPENDENCIES = $$(sort $$($(2)_FINAL_DEPENDENCIES))

$(2)_INSTALL_TARGET		?= YES

# define sub-target stamps
$(2)_TARGET_INSTALL_TARGET =	$$($(2)_DIR)/.stamp_target_installed
$(2)_TARGET_BUILD =		$$($(2)_DIR)/.stamp_built
$(2)_TARGET_CONFIGURE =		$$($(2)_DIR)/.stamp_configured

# for rebuild
$(2)_TARGET_MAKECLEAN =		$$($(2)_DIR)/.stamp_makeclean

# pre/post-steps hooks
$(2)_PRE_CONFIGURE_HOOKS        ?=
$(2)_POST_CONFIGURE_HOOKS       ?=
$(2)_PRE_BUILD_HOOKS            ?=
$(2)_POST_BUILD_HOOKS           ?=
$(2)_PRE_INSTALL_TARGET_HOOKS   ?=
$(2)_POST_INSTALL_TARGET_HOOKS  ?=
$(2)_TARGET_FINALIZE_HOOKS      ?=

$(2)_PRE_MAKECLEAN_TARGET_HOOKS   ?=
$(2)_POST_MAKECLEAN_TARGET_HOOKS  ?=


$(2)_TARGET_FILES ?=
$(2)_CONFIGURE_DEP_CONFIGS ?=
$(2)_CONFIGURE_DEP_FILES ?=
$(2)_AUTOCONFIGS ?=

$(1): $(1)-install-target

ifeq ($$($(2)_INSTALL_TARGET),YES)
$(1)-install-target:		$$($(2)_TARGET_INSTALL_TARGET)

ifneq ($$(strip $$($(2)_TARGET_FILES)),)
# if havenot a command, INSTALL_TARGET and TARGET_FILES seems compare their
# timestamp by minute, not the whole timestamp.
# If someones knows why, please tell me.
$$($(2)_TARGET_FILES):	$$($(2)_TARGET_BUILD)
	$(Q)echo TODO >/dev/null
	$$(if $(Q),,$$(info $$(@)))
$$($(2)_TARGET_INSTALL_TARGET):	$$($(2)_TARGET_FILES)
else
$$($(2)_TARGET_INSTALL_TARGET):	$$($(2)_TARGET_BUILD)
endif

else
$(1)-install-target:
endif

$(1)-build:		$$($(2)_TARGET_BUILD)
$$($(2)_TARGET_BUILD):	$$($(2)_TARGET_CONFIGURE)

ifneq ($$($(2)_AUTOCONFIGS),)
$$($(2)_TARGET_BUILD):	$(AUTOCONF_HDR_DIR)/$(1)_autoconf.h
$(AUTOCONF_HDR_DIR)/$(1)_autoconf.h : $$(call trans_macros_to_depfile,$$($(2)_AUTOCONFIGS),$(HOST_CONFIG_DIR)/)
		$(Q)echo '/* Automatically generated file; DO NOT EDIT. */' > $$(@)
		$(Q)$$(foreach config,$$($(2)_AUTOCONFIGS),sed -n '/$$(config)/ { s/RV_TARGET_//p }' $$(HOST_CONFIG_DIR)/autoconf.h >> $$(@);)
endif

# Since $(2)_FINAL_DEPENDENCIES are phony targets, they are always "newer"
# than $(2)_TARGET_CONFIGURE. This would force the configure step (and
# therefore the other steps as well) to be re-executed with every
# invocation of make.  Therefore, make $(2)_FINAL_DEPENDENCIES an order-only
# dependency by using |.

$(1)-configure:			$$($(2)_TARGET_CONFIGURE)
$$($(2)_TARGET_CONFIGURE):	| $$($(2)_FINAL_DEPENDENCIES)

# buildroot and kernel do not reconfigure if userspace_clean
ifeq ($$(filter $(1),$(SPECAIL_NOT_USERSPACE_MODULE)),)
$$($(2)_TARGET_CONFIGURE) : $(HOST_CONFIG_DIR)/userspace_clean
endif

ifneq ($$($(2)_CONFIG_KCONFIG),y)
ifneq ($$($(2)_CONFIGURE_DEP_CONFIGS),)
$$($(2)_TARGET_CONFIGURE):	$$(call trans_macros_to_depfile,$$($(2)_CONFIGURE_DEP_CONFIGS),$(HOST_CONFIG_DIR)/)
endif
$$($(2)_TARGET_CONFIGURE): $(rvmk_file)

ifneq ($$($(2)_CONFIGURE_DEP_FILES),)
$$($(2)_TARGET_CONFIGURE): $$($(2)_CONFIGURE_DEP_FILES)
endif
endif

# In the package override case, the sequence of steps
#  source, by rsyncing
#  depends
#  configure

# Use an order-only dependency so the "<pkg>-clean-for-rebuild" rule
# can remove the stamp file without triggering the configure step.
$$($(2)_TARGET_CONFIGURE): | dirs prepare

$(1)-depends:		$$($(2)_FINAL_DEPENDENCIES)

$(1)-external-deps:
	@echo "file://$$($(2)_OVERRIDE_SRCDIR)"

$(1)-show-version:
			@echo $$($(2)_VERSION)

$(1)-show-depends:
			@echo $$($(2)_FINAL_ALL_DEPENDENCIES)

$(1)-show-rdepends:
			@echo $$($(2)_RDEPENDENCIES)

$(1)-show-build-order: $$(patsubst %,%-show-build-order,$$($(2)_FINAL_ALL_DEPENDENCIES))
	$$(info $(1))

$(1)-all-external-deps:	$(1)-external-deps
$(1)-all-external-deps:	$$(foreach p,$$($(2)_FINAL_ALL_DEPENDENCIES),$$(p)-all-external-deps)

$(1)-buildclean:	$$($(2)_TARGET_MAKECLEAN)

$(1)-clean-for-reinstall:
			rm -f $$($(2)_TARGET_INSTALL_TARGET)

$(1)-reinstall:		$(1)-clean-for-reinstall $(1)

$(1)-clean-for-rebuild: $(1)-buildclean $(1)-clean-for-reinstall
			rm -f $$($(2)_TARGET_BUILD)

$(1)-rebuild:		$(1)-clean-for-rebuild $(1)

$(1)-clean-for-reconfigure: $(1)-clean-for-rebuild
			rm -f $$($(2)_TARGET_CONFIGURE)

$(1)-reconfigure:	$(1)-clean-for-reconfigure $(1)

# define the PKG variable for all targets, containing the
# uppercase package variable prefix
$$($(2)_TARGET_INSTALL_TARGET):		PKG=$(2)
$$($(2)_TARGET_BUILD):			PKG=$(2)
$$($(2)_TARGET_CONFIGURE):		PKG=$(2)
$$($(2)_TARGET_MAKECLEAN):		PKG=$(2)

$(2)_KCONFIG_VAR = RV_TARGET_$(2)

# add package to the general list of targets if requested by the buildroot
# configuration
ifeq ($$($$($(2)_KCONFIG_VAR)),y)

# Ensure the calling package is the declared provider for all the virtual
# packages it claims to be an implementation of.
ifneq ($$($(2)_PROVIDES),)
$$(foreach pkg,$$($(2)_PROVIDES),\
	$$(eval $$(call virt-provides-single,$$(pkg),$$(call UPPERCASE,$$(pkg)),$(1))$$(sep)))
endif

# Register package as a reverse-dependencies of all its dependencies
$$(eval $$(foreach p,$$($(2)_FINAL_ALL_DEPENDENCIES),\
	$$(call UPPERCASE,$$(p))_RDEPENDENCIES += $(1)$$(sep)))

# Ensure unified variable name conventions between all packages Some
# of the variables are used by more than one infrastructure; so,
# rather than duplicating the checks in each infrastructure, we check
# all variables here in pkg-generic, even though pkg-generic should
# have no knowledge of infra-specific variables.
$(eval $(call check-deprecated-variable,$(2)_MAKE_OPT,$(2)_MAKE_OPTS))
$(eval $(call check-deprecated-variable,$(2)_INSTALL_OPT,$(2)_INSTALL_OPTS))
$(eval $(call check-deprecated-variable,$(2)_INSTALL_TARGET_OPT,$(2)_INSTALL_TARGET_OPTS))
$(eval $(call check-deprecated-variable,$(2)_INSTALL_STAGING_OPT,$(2)_INSTALL_STAGING_OPTS))
$(eval $(call check-deprecated-variable,$(2)_INSTALL_HOST_OPT,$(2)_INSTALL_HOST_OPTS))
$(eval $(call check-deprecated-variable,$(2)_AUTORECONF_OPT,$(2)_AUTORECONF_OPTS))
$(eval $(call check-deprecated-variable,$(2)_CONF_OPT,$(2)_CONF_OPTS))
$(eval $(call check-deprecated-variable,$(2)_BUILD_OPT,$(2)_BUILD_OPTS))
$(eval $(call check-deprecated-variable,$(2)_GETTEXTIZE_OPT,$(2)_GETTEXTIZE_OPTS))
$(eval $(call check-deprecated-variable,$(2)_KCONFIG_OPT,$(2)_KCONFIG_OPTS))

PACKAGES += $(1)

TARGET_FINALIZE_HOOKS += $$($(2)_TARGET_FINALIZE_HOOKS)

# Ensure all virtual targets are PHONY. Listed alphabetically.
.PHONY:	$(1) \
	$(1)-build \
	$(1)-buildclean \
	$(1)-clean-for-rebuild \
	$(1)-clean-for-reconfigure \
	$(1)-clean-for-reinstall \
	$(1)-configure \
	$(1)-depends \
	$(1)-dirclean \
	$(1)-external-deps \
	$(1)-install \
	$(1)-install-target \
	$(1)-rebuild \
	$(1)-reconfigure \
	$(1)-reinstall \
	$(1)-show-depends \
	$(1)-show-version

ifeq ($$(patsubst %/,ERROR,$$($(2)_SITE)),ERROR)
$$(error $(2)_SITE ($$($(2)_SITE)) cannot have a trailing slash)
endif

ifneq ($$($(2)_HELP_CMDS),)
HELP_PACKAGES += $(2)
endif

endif # $(2)_KCONFIG_VAR
endef # inner-generic-package

################################################################################
# generic-package -- the target generator macro for generic packages
################################################################################

# In the case of target packages, keep the package name "pkg"
generic-package = $(call inner-generic-package,$(pkgname),$(call UPPERCASE,$(pkgname)),$(call UPPERCASE,$(pkgname)),target)
# In the case of host packages, turn the package name "pkg" into "host-pkg"
host-generic-package = $(call inner-generic-package,host-$(pkgname),$(call UPPERCASE,host-$(pkgname)),$(call UPPERCASE,$(pkgname)),host)

# :mode=makefile:
