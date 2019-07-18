# Copyright 2018 Rockchip Electronics Co., Ltd. All Rights Reserved.
# author: hertz.wang, wangh@rock-chips.com
#
# SPDX-License-Identifier: Apache-2.0
#

.PHONY: partition_setting_ini

ifeq ($(RV_PACK_WITH_SETTING_INI),y)

SELFDEFINE_PARTITION_SETTING_INI := $(call qstrip,$(RV_SELFDEFINE_PARTITION_FILE))
ifneq ($(SELFDEFINE_PARTITION_SETTING_INI),)
RV_PARTITION_SETTING_INI := $(SELFDEFINE_PARTITION_SETTING_INI)
partition_setting_ini:$(RV_PARTITION_SETTING_INI)
	@$(call MESSAGE,"Use self assign partition setting ini: $(RV_PARTITION_SETTING_INI)")
else #ifneq ($(RV_SELFDEFINE_PARTITION_SETTING_INI),)
#	$(1): part module name
define partition_segment
	echo "[UserPart$($(1)_NUM)]" >> $(RV_PARTITION_SETTING_INI)
	echo "Name=$($(1)_NAME)" >> $(RV_PARTITION_SETTING_INI)
	echo "Type=$($(1)_TYPE)" >> $(RV_PARTITION_SETTING_INI)
	echo "#$($(1)_OFFSET)" >> $(RV_PARTITION_SETTING_INI)
	echo "PartOffset=0x$(call dec2hex_per_section,$($(1)_OFFSET))" >> $(RV_PARTITION_SETTING_INI)
	echo "#$($(1)_SIZE)" >> $(RV_PARTITION_SETTING_INI)
	echo "PartSize=0x$(call dec2hex_per_section,$($(1)_SIZE))" >> $(RV_PARTITION_SETTING_INI)
	echo "Flag=$($(1)_FLAG)" >> $(RV_PARTITION_SETTING_INI)
	echo "File=$(subst $(space),$(comma),$($(1)_FILE))" >> $(RV_PARTITION_SETTING_INI)
endef

RV_PARTITION_SETTING_INI := $(IMAGE_DIR)/setting.ini
DDR_BIN := $(call qstrip,$(BOARD_DIR)/$(RV_BOARD_TYPE)/$(RV_BOARD_TYPE)ddr.bin)
LOADER_BIN := $(call qstrip,$(BOARD_DIR)/$(RV_BOARD_TYPE)/$(RV_BOARD_TYPE)loader.bin)

part_num = 0
PART_NAMES =

PART_NAME := PARTITION_DDRLOADER
$(PART_NAME)_PREPART_OFFSET=0
# 0x40
$(PART_NAME)_PREPART_SIZE=32768
part_num += 1
$(PART_NAME)_NUM:=$(call sum,$(part_num))
$(PART_NAME)_NAME=IDBlock
$(PART_NAME)_TYPE=0x2
$(PART_NAME)_FLAG=0x0
$(PART_NAME)_FILE=$(DDR_BIN) $(LOADER_BIN)
# TODO...
$(PART_NAME)_SIZE=393216
$(eval $(call inner_generic_partsegment,$(PART_NAME),,PART_NAMES))

PREPART_NAME := $(PART_NAME)
PART_NAME := PARTITION_KERNEL
part_num += 1
$(PART_NAME)_NUM:=$(call sum,$(part_num))
$(PART_NAME)_NAME=kernel
$(PART_NAME)_TYPE=0x4
$(PART_NAME)_FLAG=0x0
$(PART_NAME)_FILE=$(IMAGE_DIR)/kernel.img
$(eval $(call inner_generic_partsegment,$(PART_NAME),$(PREPART_NAME),PART_NAMES))

ifeq ($(ROOTFS_INDIVIDUAL_PARTITION),y)
PREPART_NAME := $(PART_NAME)
PART_NAME := PARTITION_ROOTFS
part_num += 1
$(PART_NAME)_NUM:=$(call sum,$(part_num))
$(PART_NAME)_NAME=rootfs
$(PART_NAME)_TYPE=0x8
$(PART_NAME)_FLAG=0x0
$(PART_NAME)_FILE=$(IMAGE_DIR)/rootfs.img
$(eval $(call inner_generic_partsegment,$(PART_NAME),$(PREPART_NAME),PART_NAMES))
endif

ifeq ($(RV_SET_USERSELF_PARTITION_ONE),y)
PREPART_NAME := $(PART_NAME)
PART_NAME := PARTITION_USERONE
USERSELF_$(PART_NAME)_ROOTPATH = $(call qstrip,$(RV_USERSELF_PARTITION_ONE_ROOTPATH))
ifeq ($(wildcard $(USERSELF_$(PART_NAME)_ROOTPATH)),)
$(error $(USERSELF_$(PART_NAME)_ROOTPATH) is not exist!)
endif
part_num += 1
$(PART_NAME)_NUM:=$(call sum,$(part_num))
$(PART_NAME)_NAME=$(call qstrip,$(RV_USERSELF_PARTITION_ONE_NAME))
$(PART_NAME)_TYPE=0x$(subst 0x,,$(call qstrip,$(RV_USERSELF_PARTITION_ONE_TYPE)))
$(PART_NAME)_FLAG=0x$(subst 0x,,$(call qstrip,$(RV_USERSELF_PARTITION_ONE_FLAG)))
USERSELF_PARTITION_ONE_SIZE = $(call qstrip,$(RV_USERSELF_PARTITION_ONE_SIZE))
ifeq ($(subst 0,,$(USERSELF_PARTITION_ONE_SIZE)),)
$(PART_NAME)_SIZE=$(shell du -d 0 $(USERSELF_$(PART_NAME)_ROOTPATH) | awk '{print $$1}')
else
$(PART_NAME)_SIZE=$(USERSELF_PARTITION_ONE_SIZE)
endif
$(PART_NAME)_FILE=$(IMAGE_DIR)/user_part_one.img
$(PART_NAME)_FSTYPE=$(call qstrip,$(RV_USERSELF_PARTITION_ONE_FSTYPE))
$(eval $(call inner_generic_partsegment,$(PART_NAME),$(PREPART_NAME),PART_NAMES))

partition_setting_ini: $(PART_NAME)_FILE

$(PART_NAME)_FILE: part_module=$(PART_NAME)

$(PART_NAME)_FILE: $(USERSELF_PARTITION_ONE_ROOTPATH)
ifeq ($($(part_module)_FSTYPE),ext4)
	make_ext4fs -l $($(part_module)_SIZE) $($(part_module)_FILE) $(USERSELF_$(part_module)_ROOTPATH)
endif
ifeq ($($(part_module)_FSTYPE),jffs2)
	make.jffs2 -d $(USERSELF_$(part_module)_ROOTPATH) -o $($(part_module)_FILE) -e 0x10000 --pad=$($(part_module)_SIZE) -n
endif
endif # ifeq ($(RV_SET_USERSELF_PARTITION_ONE),y)

partition_setting_ini:
	@$(call MESSAGE,"Generate minimize partition setting ini")
	@echo "#Flag 1:skip flag, 2:reserved flag, 4:no partition size flag" > $(RV_PARTITION_SETTING_INI)
	@echo "#type 0x1:Vendor, 0x2:IDBlock, 0x4:Kernel, 0x8:boot, 0x80000000:data" >> $(RV_PARTITION_SETTING_INI)
	@echo "#PartSize and PartOffset unit by sector" >> $(RV_PARTITION_SETTING_INI)
	@echo "#Gpt_Enable 1:compact gpt, 0:normal gpt" >> $(RV_PARTITION_SETTING_INI)
	@echo "#Backup_Partition_Enable 0:no backup,1:backup" >> $(RV_PARTITION_SETTING_INI)
	@echo "#FILL_BYTE's value is used to fill blank" >> $(RV_PARTITION_SETTING_INI)
	@echo "[System]" >> $(RV_PARTITION_SETTING_INI)
	@echo "FwVersion=15.48.1" >> $(RV_PARTITION_SETTING_INI)
	@echo "Gpt_Enable=" >> $(RV_PARTITION_SETTING_INI)
	@echo "Backup_Partition_Enable=0" >> $(RV_PARTITION_SETTING_INI)
	@echo "Nano=" >> $(RV_PARTITION_SETTING_INI)
	@$(foreach part_module,$(PART_NAMES),$(call partition_segment,$(part_module))$(sep))
	@echo " ... [$(RV_PARTITION_SETTING_INI)] done)"
endif # ifneq ($(RV_SELFDEFINE_PARTITION_SETTING_INI),)

endif # ifeq ($(RV_PACK_WITH_SETTING_INI),y)
