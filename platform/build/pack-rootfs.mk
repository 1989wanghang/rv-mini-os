# Copyright 2018 Rockchip Electronics Co., Ltd. All Rights Reserved.
# author: hertz.wang, wangh@rock-chips.com
#
# SPDX-License-Identifier: Apache-2.0
#

RSYNC_VCS_EXCLUSIONS = \
	--exclude .svn --exclude .git --exclude .hg --exclude .bzr \
	--exclude CVS

IMAGE_SYMBOL_DIR := $(IMAGE_DIR)/symbol
IMAGE_ROOTFS_DIR := $(IMAGE_DIR)/rootfs
ROOTFS_TARGET_IMG := $(IMAGE_DIR)/rootfs.img

STRIP_FIND_CMD = find $(1)
STRIP_FIND_CMD += -type f \( -perm /111 -o -name '*.so*' \)
# file exclusions:
# - libpthread.so: a non-stripped libpthread shared library is needed for
#   proper debugging of pthread programs using gdb.
# - ld.so: a non-stripped dynamic linker library is needed for valgrind
# - kernel modules (*.ko): do not function properly when stripped like normal
#   applications and libraries. Normally kernel modules are already excluded
#   by the executable permission check above, so the explicit exclusion is only
#   done for kernel modules with incorrect permissions.
STRIP_FIND_CMD += -not \( $(call findfileclauses,libpthread*.so* ld-*.so* *.ko) \) -print0

RV_FINAL_BINS ?=
RV_FINAL_LIBS ?=
RV_FINAL_ETCS ?=
RV_FINAL_SHARES ?=

strip_files_under = $(STRIP_FIND_CMD) | xargs -0 $(STRIPCMD) $(STRIP_STRIP_ALL) $(if $(Q),2>/dev/null) || true
rm_files_under = find $(1) -type f -name $(2) | xargs -r rm -f

define search_iq
	temp=`grep "cif_isp0" -A 6 $(1) | sed ':a;N;$$!ba;s/\n/ /g' | cut -d '{' -f2 | cut -d '}' -f1`; \
	iq_name=; \
	[[ $$temp =~ "okay" ]] && \
		camera=`echo "$$temp" | grep "rockchip,camera-modules-attached" | cut -d '<' -f2|cut -d '>' -f1 | sed "s/&camera/camera/g"`; \
		cam_dts=; \
		for i in $$camera; do \
			temp=`grep "$$i:" -A 35 $(1) | sed ':a;N;$$!ba;s/\n/ /g' | cut -d '{' -f2 | cut -d '}' -f1`; \
			if [ -z "$$temp" ]; then \
				[[ -z "$$cam_dts" ]] && cam_dts=`grep "&i2c1" -A 10 $(1) | grep "^#include" | cut -d '"' -f2|cut -d '"' -f1`; \
				temp=`grep "$$i:" -A 35 $(KERNEL_DTS_DIR)/$$cam_dts | sed ':a;N;$$!ba;s/\n/ /g' | cut -d '{' -f2 | cut -d '}' -f1`; \
				[[ $$temp =~ "okay" ]] && iq_name="$$iq_name `echo "$$temp" | awk -F 'rockchip,camera-module-name' '{print $$2}' | cut -d '"' -f2|cut -d '"' -f1`"; \
			else \
				[[ $$temp =~ "okay" ]] && iq_name="$$iq_name `echo "$$temp" | awk -F 'rockchip,camera-module-name' '{print $$2}' | cut -d '"' -f2|cut -d '"' -f1`"; \
			fi; \
		done; \
	temp=`ls $(2)`; \
	[[ -z "$$iq_name" ]] && iq_name="cam_default"; \
	echo "camera module name:$$iq_name"; \
	for i in $$iq_name; do \
		for j in $$temp; do [[ $$j =~ $$i ]] && temp=`echo "$$temp" | sed 's/'"$$j"'//g'`; done; \
	done; \
	cd $(2) && rm -f `echo "$$temp"`;
endef

.PHONY: pack-rootfs
pack-rootfs:
	@$(call MESSAGE,"Package rootfs.img")
	$(Q)rm -rf $(IMAGE_SYMBOL_DIR)
	$(Q)mkdir -p $(IMAGE_SYMBOL_DIR)
	$(Q)cp -aR $(BR_TARGET_DIR)/* $(IMAGE_SYMBOL_DIR)
	$(if $(RV_FINAL_ETCS),$(Q)cd $(TARGET_DIR)/etc && cp -rf $(RV_FINAL_ETCS) $(IMAGE_SYMBOL_DIR)/etc/)
	$(if $(RV_FINAL_BINS),$(Q)cd $(TARGET_DIR)/usr/bin && cp -af $(RV_FINAL_BINS) /home/wangh/temp/test.mp4 $(IMAGE_SYMBOL_DIR)/usr/bin/)
	$(if $(RV_FINAL_LIBS),$(Q)cd $(TARGET_DIR)/usr/lib && cp -af $(RV_FINAL_LIBS) $(IMAGE_SYMBOL_DIR)/usr/lib/)
	$(Q)cp -af $(TARGET_DIR)/usr/share $(IMAGE_SYMBOL_DIR)/usr/ || true
	$(Q)$(if $(wildcard $(ROOTFS_OVERLAY_DIR)/*),cp -aR $(ROOTFS_OVERLAY_DIR)/* $(IMAGE_SYMBOL_DIR)/)
ifeq ($(RV_TARGET_LIBCAMERAHAL),y)
	$(Q)($(call search_iq,\
		$(call qstrip,$(KERNEL_DTS_DIR)/$(STRIPED_KERNEL_DTS_NAME).dts),\
		$(IMAGE_SYMBOL_DIR)/etc/cam_iq)) || true
endif
	$(Q)rm -rf $(IMAGE_SYMBOL_DIR)/usr/include $(IMAGE_SYMBOL_DIR)/usr/share/aclocal \
		$(IMAGE_SYMBOL_DIR)/usr/lib/pkgconfig $(IMAGE_SYMBOL_DIR)/usr/share/pkgconfig \
		$(IMAGE_SYMBOL_DIR)/usr/lib/cmake $(IMAGE_SYMBOL_DIR)/usr/share/cmake
	$(Q)$(call rm_files_under,$(IMAGE_SYMBOL_DIR)/usr/lib,"*.cmake")
	$(Q)$(call rm_files_under,$(IMAGE_SYMBOL_DIR),".*")
	$(Q)find $(IMAGE_SYMBOL_DIR)/lib/ $(IMAGE_SYMBOL_DIR)/usr/lib/ $(IMAGE_SYMBOL_DIR)/usr/libexec/ \
		\( -name '*.a' -o -name '*.la' \) -print0 | xargs -0 rm -f
	$(Q)rm $(IMAGE_SYMBOL_DIR)/THIS_IS_NOT_YOUR_ROOT_FILESYSTEM
	$(Q)rm $(IMAGE_SYMBOL_DIR)/etc/os-release
	$(Q)rm $(IMAGE_SYMBOL_DIR)/usr/lib/os-release
ifneq ($(RV_TARGET_NETWORK),y)
	$(Q)rm -rf $(IMAGE_SYMBOL_DIR)/usr/share/udhcpc
endif
ifneq ($(ENABLE_TIMEZONE),y)
	$(Q)rm -f $(IMAGE_SYMBOL_DIR)/etc/TZ
	$(Q)rm -rf $(IMAGE_SYMBOL_DIR)/usr/share/zoneinfo
endif
	$(Q)rm -rf $(TARGET_DIR)/usr/man $(TARGET_DIR)/usr/share/man
	$(Q)rm -rf $(TARGET_DIR)/usr/info $(TARGET_DIR)/usr/share/info
	$(Q)rm -rf $(TARGET_DIR)/usr/doc $(TARGET_DIR)/usr/share/doc
	$(Q)rm -rf $(TARGET_DIR)/usr/share/gtk-doc
	$(Q)rmdir $(TARGET_DIR)/usr/share 2>/dev/null || true
	@$(foreach s, $(call qstrip,$(RV_ROOTFS_POST_PACK_SCRIPT)), \
		$(call MESSAGE,"Executing post-pack script $(value $(s))"); \
		$(s))
	$(Q)rm -rf $(IMAGE_ROOTFS_DIR)
	$(Q)mkdir -p $(IMAGE_ROOTFS_DIR)
	$(Q)cp -aR $(IMAGE_SYMBOL_DIR)/* $(IMAGE_ROOTFS_DIR)
# strip bin and libs
ifneq ($(STRIPCMD),)
	$(Q)$(call strip_files_under,$(IMAGE_ROOTFS_DIR)/bin/)
	$(Q)$(call strip_files_under,$(IMAGE_ROOTFS_DIR)/sbin/)
	$(Q)$(call strip_files_under,$(IMAGE_ROOTFS_DIR)/lib/)
	$(Q)$(call strip_files_under,$(IMAGE_ROOTFS_DIR)/usr/bin/)
	$(Q)$(call strip_files_under,$(IMAGE_ROOTFS_DIR)/usr/lib/)
endif
ifeq ($(RV_ENABLE_DEBUG),y)
	$(Q)cp $(call qstrip,$(BOARD_DIR)/$(RV_BOARD_TYPE))/init.d/S00debug.sh $(IMAGE_ROOTFS_DIR)/etc/init.d/
endif
# boot init script
	$(Q)cp $(call qstrip,$(BOARD_DIR)/$(RV_BOARD_TYPE)/init.d/S00$(RV_BOARD_TYPE))_init.sh $(IMAGE_ROOTFS_DIR)/etc/init.d/
	$(Q)sed -i "/\/dev\/pts/d" $(IMAGE_ROOTFS_DIR)/etc/fstab
	$(Q)sed -i "/\/dev\/shm/d" $(IMAGE_ROOTFS_DIR)/etc/fstab
	$(Q)sed -i "/ext2	rw/d" $(IMAGE_ROOTFS_DIR)/etc/fstab
	$(Q)sed -i "/proc proc/d" $(IMAGE_ROOTFS_DIR)/etc/inittab
	$(Q)sed -i "/\/dev\/pts/d" $(IMAGE_ROOTFS_DIR)/etc/inittab
	$(Q)sed -i "/\/dev\/shm/d" $(IMAGE_ROOTFS_DIR)/etc/inittab
	$(Q)echo 'udev		/dev		devtmpfs	size=4k	 0	0' >> $(IMAGE_ROOTFS_DIR)/etc/fstab
# enable console
	$(Q)sed -i "/init.d\/rcS/a\console::respawn:-/bin/sh" $(IMAGE_ROOTFS_DIR)/etc/inittab
ifeq ($(RV_PACK_WITH_SETTING_INI)$(RV_SET_USERSELF_PARTITION_ONE),yy)
	$(Q)mkdir $(IMAGE_ROOTFS_DIR)/mnt/udisk1
	$(Q)echo "mount –t $(PARTITION_USERONE_FSTYPE) /dev/$(PARTITION_USERONE_NAME) /mnt/udisk1" >>\
		$(IMAGE_ROOTFS_DIR)/etc/init.d/S00$(call qstrip,$(RV_BOARD_TYPE))_init.sh
endif
	$(call gen_fs_img,$(call qstrip,$(RV_ROOTFS_PARTITION_FSTYPE)),$(IMAGE_ROOTFS_DIR),$(ROOTFS_TARGET_IMG),$(RV_ROOTFS_PARTITION_NAME))
