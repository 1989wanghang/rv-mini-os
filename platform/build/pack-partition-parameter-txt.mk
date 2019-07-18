# Copyright 2018 Rockchip Electronics Co., Ltd. All Rights Reserved.
# author: hertz.wang, wangh@rock-chips.com
#
# SPDX-License-Identifier: Apache-2.0
#

.PHONY: partition_parameter_txt

ifeq ($(RV_PACK_WITH_PARAMETER_TXT),y)

SELFDEFINE_PARTITION_PARAMETER_TXT := $(call qstrip,$(RV_SELFDEFINE_PARTITION_FILE))
ifneq ($(SELFDEFINE_PARTITION_PARAMETER_TXT),)
RV_PARTITION_PARAMETER_TXT := $(SELFDEFINE_PARTITION_PARAMETER_TXT)
partition_parameter_txt: $(RV_PARTITION_PARAMETER_TXT) $(TARGET_IMGS)
	@$(call MESSAGE,"Use self assign partition parameter txt: $(RV_PARTITION_PARAMETER_TXT)")
else
RV_FIRMWARE_VER = 8.1
RV_MACHINE_MODEL = $(call UPPERCASE,$(RV_BOARD_TYPE))
RV_MACHINE_ID = 007
RV_MANUFACTURER = RockChip
RV_MAGIC = 0x5041524B
RV_ATAG = 0x00200800
RV_MACHINE = $(subst RK,,$(RV_MACHINE_MODEL))
RV_CHECK_MASK = 0x80
RV_PWR_HLD = 0,0,A,0,1
RV_UUID = rootfs=614e0000-0000-4b53-8000-1d28000054a9

RV_PARTITION_START_OFFSET := $(call qstrip,$(RV_PARTITION_START_OFFSET))
ifeq ($(RV_PARTITION_START_OFFSET),)
$(error partition start offset should not be empty)
endif

RV_PART_NAMES =
RV_PART_MODULES =
RV_CURRENT_PARTITION_MODULE =

#	$(1): part module name
#	$(2): pre part module name
#	$(3): write name
#	$(4): file path
define DECLARE_PAITION_VARIABLES
ifeq ($(2),)
$(1)_PREPART_OFFSET=0
$(1)_PREPART_SIZE=$(RV_PARTITION_START_OFFSET)
endif

$(1)_NAME = $(3)
$(1)_FILE = $(4)

$(1)_SIZE := $$(call qstrip,$$($(1)_SIZE))

ifeq ($$(subst 0,,$$($(1)_SIZE)),)
ifneq ($$(wildcard $(4)),)
$(1)_SIZE = $$(call align,$$(call sum,$$(call file_sizes,$(4))),2097152)
endif
endif

$(call inner_generic_partsegment,$(1),$(2),RV_PART_MODULES)
RV_CURRENT_PARTITION_MODULE = $(1)
$(1)_ENABLE ?= y
RV_PART_NAMES += $$(call rk-part,$(3))
endef

rk-part = $(firstword $(subst :,$(space),$(1)))
rk-part-module = RV_$(call UPPERCASE,$(call rk-part,$(1)))_PARTITION
rk-declare-partition-vars = $(call DECLARE_PAITION_VARIABLES,$(call rk-part-module,$(1)),$(RV_CURRENT_PARTITION_MODULE),$(1),$(2))

$(eval $(call rk-declare-partition-vars,uboot,$(UBOOT_TARGET_IMG)))
$(eval $(call rk-declare-partition-vars,trust,$(TRUST_TARGET_IMG)))
$(eval $(call rk-declare-partition-vars,misc,$(MISC_TARGET_IMG)))
$(eval $(call rk-declare-partition-vars,boot,$(KERNEL_TARGET_IMG)))

ifeq ($(RV_SET_RECOVERY_PARTITION),y)
$(eval $(call rk-declare-partition-vars,recovery,$(RECOVERY_TARGET_IMG)))
endif

ifeq ($(RV_SET_BACKUP_PARTITION),y)
$(eval $(call rk-declare-partition-vars,backup,$(BACKUP_TARGET_IMG)))
endif

$(eval $(call rk-declare-partition-vars,rootfs,$(ROOTFS_TARGET_IMG)))
$(eval $(call rk-declare-partition-vars,oem,$(OEM_TARGET_IMG)))
$(eval $(call rk-declare-partition-vars,userdata:grow,$(USERDATA_TARGET_IMG)))

RV_PARTITION_PARAMETER_TXT := $(IMAGE_DIR)/parameter.txt

define GEN_PARTITION_SEGMENT
if [ ! $${first} ]; then printf , >> $(RV_PARTITION_PARAMETER_TXT); \
else first=; fi; \
if [ "$($(1)_SIZE)" = "-" ]; then \
printf - >> $(RV_PARTITION_PARAMETER_TXT); \
else \
printf "0x%08x" $(if $(shell echo $($(1)_SIZE) | sed 's/[0-9]//g'),\
0,$$[$($(1)_SIZE)/512]) >> $(RV_PARTITION_PARAMETER_TXT); \
fi; \
printf "@0x%08x(%s)" $(if $($(1)_OFFSET),$$[$($(1)_OFFSET)/512],0) $($(1)_NAME) >> $(RV_PARTITION_PARAMETER_TXT);
endef

partition_parameter_txt: $(TARGET_IMGS)
	@$(call MESSAGE,"Generate minimize partition parameter txt")
	@echo "FIRMWARE_VER: $(RV_FIRMWARE_VER)" > $(RV_PARTITION_PARAMETER_TXT)
	@echo "MACHINE_MODEL: $(RV_MACHINE_MODEL)" >> $(RV_PARTITION_PARAMETER_TXT)
	@echo "MACHINE_ID: $(RV_MACHINE_ID)" >> $(RV_PARTITION_PARAMETER_TXT)
	@echo "MANUFACTURER: $(RV_MANUFACTURER)" >> $(RV_PARTITION_PARAMETER_TXT)
	@echo "MAGIC: $(RV_MAGIC)" >> $(RV_PARTITION_PARAMETER_TXT)
	@echo "ATAG: $(RV_ATAG)" >> $(RV_PARTITION_PARAMETER_TXT)
	@echo "MACHINE: $(RV_MACHINE)" >> $(RV_PARTITION_PARAMETER_TXT)
	@echo "CHECK_MASK: $(RV_CHECK_MASK)" >> $(RV_PARTITION_PARAMETER_TXT)
	@echo "PWR_HLD: $(RV_PWR_HLD)">> $(RV_PARTITION_PARAMETER_TXT)
	@echo "TYPE: GPT">> $(RV_PARTITION_PARAMETER_TXT)
	@printf "CMDLINE: mtdparts=rk29xxnand:">> $(RV_PARTITION_PARAMETER_TXT)
	$(Q)first=1;\
	$(foreach part_module,$(RV_PART_MODULES),$(call GEN_PARTITION_SEGMENT,$(part_module)))
	@printf "\\nuuid:%s\\n" $(RV_UUID) >> $(RV_PARTITION_PARAMETER_TXT)
	@echo " ... [$(RV_PARTITION_PARAMETER_TXT)] done)"

endif # ifneq ($(RV_SELFDEFINE_PARTITION_PARAMETER_TXT),)

endif # ifeq ($(RV_PACK_WITH_PARAMETER_TXT),y)
