# Copyright 2018 Rockchip Electronics Co., Ltd. All Rights Reserved.
# author: hertz.wang, wangh@rock-chips.com
#
# SPDX-License-Identifier: Apache-2.0
#

MISC_SOURCE_IMG := $(BOARD_DIR)/common/wipe_all-misc.img
MISC_TARGET_IMG := $(IMAGE_DIR)/misc.img
$(MISC_TARGET_IMG): $(MISC_SOURCE_IMG)
	$(Q)install -C $(^) $(@)

# TODO
RECOVERY_TARGET_IMG := $(IMAGE_DIR)/recovery.img
BACKUP_TARGET_IMG := $(IMAGE_DIR)/backup.img

OEM_TARGET_IMG := $(IMAGE_DIR)/oem.img
$(OEM_TARGET_IMG): $(OEM_DIR)
	$(call gen_fs_img,$(call qstrip,$(RV_OEM_PARTITION_FSTYPE)),$(<),$(@),$(RV_OEM_PARTITION_NAME))

USERDATA_TARGET_IMG := $(IMAGE_DIR)/userdata.img
$(USERDATA_TARGET_IMG): $(USERDATA_DIR)
	$(call gen_fs_img,$(call qstrip,$(RV_USERDATA_PARTITION_FSTYPE)),$(<),$(@),$(RV_USERDATA_PARTITION_NAME))

include $(BUILD_SCRIPT_DIR)/pack-rootfs.mk

TARGET_IMGS = $(UBOOT_TARGET_IMG) $(TRUST_TARGET_IMG) \
		$(MISC_TARGET_IMG) $(KERNEL_TARGET_IMG) \
		$(if $(RV_SET_RECOVERY_PARTITION),$(RECOVERY_TARGET_IMG)) \
		$(if $(RV_SET_BACKUP_PARTITION),$(BACKUP_TARGET_IMG)) \
		$(ROOTFS_TARGET_IMG) $(OEM_TARGET_IMG) $(USERDATA_TARGET_IMG)

include $(BUILD_SCRIPT_DIR)/pack-partition-setting-ini.mk
include $(BUILD_SCRIPT_DIR)/pack-partition-parameter-txt.mk

.PHONY: fw
fw: pack-rootfs $(if $(RV_PACK_WITH_SETTING_INI),partition_setting_ini) \
	$(if $(RV_PACK_WITH_PARAMETER_TXT), $(TARGET_IMGS))
ifeq ($(RV_PACK_WITH_SETTING_INI),y)
	@$(call MESSAGE,"Package Firmware.img")
	$(Q)$(TOP_DIR)/vendor_tool/pack/firmwareMerger \
		-p $(RV_PARTITION_SETTING_INI) $(IMAGE_DIR)/
	$(Q)ls -sh $(IMAGE_DIR)/Firmware.img
else
	@make partition_parameter_txt
endif

linux_upgrade_tool := \
	$(TOP_DIR)/vendor_tool/rockchip/tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool

ifeq ($(RV_BOARD_110X),y)
BOOT_BIN_FILE = $(call qstrip,$(BOARD_DIR)/$(RV_BOARD_TYPE)/$(RV_BOARD_TYPE)_usb_boot.bin)
dl:
	@sudo $(linux_upgrade_tool) db $(BOOT_BIN_FILE)
	@sleep 1
	@sudo $(linux_upgrade_tool) wl 0 $(IMAGE_DIR)/Firmware.img
	@sudo $(linux_upgrade_tool) rd
else
BOOT_BIN_FILE ?= $(IMAGE_DIR)/MiniLoaderAll.bin

define wait_rk_device
	while ! sudo lsusb -d 2207:330d && ! sudo lsusb -d 2207:330e ; do sleep 1; echo "wait device"; done
endef

# rockchip linux_upgrade_tool will output many temp bin after download firware,
# so change a tmp path to do dl
TEMP_UPGRADE_DIR = $(IMAGE_DIR)/temp_upgrade
$(TEMP_UPGRADE_DIR):
	mkdir -p $(@)

dl: $(TEMP_UPGRADE_DIR)
	@$(call MESSAGE,"download images: $(if $(PARTITIONS),$(filter $(PARTITIONS),$(RV_PART_NAMES)),$(RV_PART_NAMES))")
	@$(call wait_rk_device)
	$(Q)cd $(TEMP_UPGRADE_DIR) && sudo $(linux_upgrade_tool) ul $(BOOT_BIN_FILE)
	$(Q)cd $(TEMP_UPGRADE_DIR) && sudo $(linux_upgrade_tool) di -p $(RV_PARTITION_PARAMETER_TXT) || true
	$(Q)cd $(TEMP_UPGRADE_DIR);\
		$(foreach part,$(if $(PARTITIONS),$(filter $(PARTITIONS),$(RV_PART_NAMES)),$(RV_PART_NAMES)),\
		sudo $(linux_upgrade_tool) di -$(part) $($(call rk-part-module,$(part))_FILE) || true;)
	@sleep 1
	$(Q)sudo $(linux_upgrade_tool) rd

.PHONY: dl-earse
dl-earse:
	@$(call wait_rk_device)
	$(Q)sudo $(linux_upgrade_tool) ef $(BOOT_BIN_FILE)

.PHONY: dl-%
dl-%: $(TEMP_UPGRADE_DIR)
	@$(call MESSAGE,"download image: $(word 2,$(subst -,$(space),$(@)))")
	@$(call wait_rk_device)
	$(Q)cd $(TEMP_UPGRADE_DIR) && sudo $(linux_upgrade_tool) ul $(BOOT_BIN_FILE)
	$(Q)cd $(TEMP_UPGRADE_DIR) && sudo $(linux_upgrade_tool) di -p $(RV_PARTITION_PARAMETER_TXT) || true
	$(Q)cd $(TEMP_UPGRADE_DIR);\
		$(foreach part,$(word 2,$(subst -,$(space),$(@))),$(if $(filter $(part),$(RV_PART_NAMES)),\
		sudo $(linux_upgrade_tool) di -$(part) $($(call rk-part-module,$(part))_FILE) || true;\
		sudo $(linux_upgrade_tool) rd,echo "\"$(part)\" partition is not enable!"; exit 1))
endif

$(TOP_DIR)/doc/.doc : $(TOP_DIR)/README.md \
	$(TOP_DIR)/internal_doc \
	$(call rwildcard,$(TOP_DIR)/internal_doc,*) \
	$(TOP_DIR)/doc/media \
	$(call rwildcard,$(TOP_DIR)/doc/media,*) \
	$(TOP_DIR)/doc/template.css
	@sh ./internal_doc/md2html.bash
	@echo release the document under directory \'doc\'
	@touch $@

doc: $(TOP_DIR)/doc/.doc

.PHONY: prepare-gdb
prepare-gdb:
	$(Q)$(foreach DIR, $(if $(SYMBOL_DIR),\
		$(realpath $(call remove-last-slash,$(SYMBOL_DIR))),\
		$(IMAGE_DIR)/symbol),\
	echo "add-auto-load-safe-path $(TOP_DIR)/gdbdebug" > ~/.gdbinit;\
	mkdir -p gdbdebug;\
	echo "set sysroot $(DIR)" > gdbdebug/.gdbinit;\
	echo "set solib-absolute-prefix $(DIR)" >> gdbdebug/.gdbinit;\
	echo "set solib-search-path $(DIR)" >> gdbdebug/.gdbinit;\
	echo "define enter_non_stop" >> gdbdebug/.gdbinit;\
	echo "	set pagination off" >> gdbdebug/.gdbinit;\
	echo "	set target-async on" >> gdbdebug/.gdbinit;\
	echo "	set non-stop on" >> gdbdebug/.gdbinit;\
	echo "end" >> gdbdebug/.gdbinit;\
	echo "#!/bin/bash" > gdbdebug/rv_gdb.bash;\
	echo "#--core=./corefile" >> gdbdebug/rv_gdb.bash;\
	echo "$(TARGET_CROSS)gdb --init-command=$(RV_TOPDIR)/gdbdebug/.gdbinit \$$*" >> gdbdebug/rv_gdb.bash;\
	chmod +x gdbdebug/rv_gdb.bash;\
	)
	@echo 'gdbdebug created; usage: cd gdbdebug && ./rv_gdb.bash'
