#Android makefile to build kernel as a part of Android Build
ifeq ($(TARGET_PREBUILT_KERNEL),)

INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel
KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/arm/boot/zImage
KERNEL_HEADERS_INSTALL := $(KERNEL_OUT)/usr
KERNEL_MODULES_INSTALL := system
KERNEL_MODULES_OUT := $(TARGET_OUT)/lib/modules
KERNEL_IMG=$(KERNEL_OUT)/arch/arm/boot/Image
# relative path from KERNEL_OUT to kernel source directory
KERNEL_SOURCE_RELATIVE_PATH := ../../../../../../kernel

ifeq ($(TARGET_USES_UNCOMPRESSED_KERNEL),true)
$(info Using uncompressed kernel)
TARGET_PREBUILT_KERNEL := $(KERNEL_OUT)/piggy
else
TARGET_PREBUILT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)
endif

define mv-modules
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.order`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`;\
ko=`find $$mpath/kernel -type f -name *.ko`;\
for i in $$ko; do mv $$i $(KERNEL_MODULES_OUT)/; done;\
fi
endef

define clean-module-folder
mdpath=`find $(KERNEL_MODULES_OUT) -type f -name modules.order`;\
if [ "$$mdpath" != "" ];then\
mpath=`dirname $$mdpath`; rm -rf $$mpath;\
fi
endef

include kernel/defconfig.mk

define do-kernel-config
	( cp $(3) $(2) && $(7) -C $(4) O=$(1) ARCH=$(5) CROSS_COMPILE=$(6) defoldconfig ) || ( rm -f $(2) && false )
endef

$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)

$(KERNEL_CONFIG): $(KERNEL_OUT) $(TARGET_DEFCONFIG)
	$(call do-kernel-config,../$(KERNEL_OUT),$@,$(TARGET_DEFCONFIG),kernel,arm,arm-eabi-,$(MAKE))

$(KERNEL_OUT)/piggy : $(TARGET_PREBUILT_INT_KERNEL)
	$(hide) gunzip -c $(KERNEL_OUT)/arch/arm/boot/compressed/piggy.gzip > $(KERNEL_OUT)/piggy

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_OUT) $(KERNEL_CONFIG) $(KERNEL_HEADERS_INSTALL)
	$(MAKE) -C kernel KBUILD_RELSRC=$(KERNEL_SOURCE_RELATIVE_PATH) O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi-
	$(MAKE) -C kernel KBUILD_RELSRC=$(KERNEL_SOURCE_RELATIVE_PATH) O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- dtbs
	$(MAKE) -C kernel KBUILD_RELSRC=$(KERNEL_SOURCE_RELATIVE_PATH) O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- modules
	$(MAKE) -C kernel KBUILD_RELSRC=$(KERNEL_SOURCE_RELATIVE_PATH) O=../$(KERNEL_OUT) INSTALL_MOD_PATH=../../$(KERNEL_MODULES_INSTALL) INSTALL_MOD_STRIP="--strip-debug --remove-section=.note.gnu.build-id" ARCH=arm CROSS_COMPILE=arm-eabi- modules_install
	$(mv-modules)
	$(clean-module-folder)

$(KERNEL_HEADERS_INSTALL): $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- headers_install

kerneltags: $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- tags

kernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- menuconfig
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C kernel O=../$(KERNEL_OUT) ARCH=arm CROSS_COMPILE=arm-eabi- savedefconfig
	cp $(KERNEL_OUT)/defconfig kernel/arch/arm/configs/$(KERNEL_DEFCONFIG)

endif
