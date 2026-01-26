#
# Copyright (C) 2017 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

### INHERIT FROM YOSHINO-COMMON
include device/sony/yoshino-common/BoardConfigPlatform.mk
include vendor/sony/lilac/BoardConfigVendor.mk

DEVICE_PATH := device/sony/lilac

PRODUCT_PLATFORM := yoshino

### ANDROID VERIFIED BOOT
BOARD_AVB_ENABLE := true
BOARD_AVB_ALGORITHM := SHA256_RSA4096
BOARD_AVB_KEY_PATH := build/target/product/security/avb.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_KEY_PATH := build/target/product/security/avb.pem
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

### BOOTLOADER
TARGET_BOOTLOADER_BOARD_NAME := G8441

### KERNEL
ifeq ($(TARGET_PRODUCT),lineage_lilac_dcm)
TARGET_KERNEL_CONFIG := lineage-msm8998-yoshino-lilac_dcm_defconfig
else
TARGET_KERNEL_CONFIG := lineage-msm8998-yoshino-lilac_defconfig
endif

BOARD_KERNEL_CMDLINE += androidboot.hardware=lilac

### PARTITIONS
# See also /proc/partitions on the device
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 5242880000
BOARD_USERDATAIMAGE_PARTITION_SIZE := 23753875456
BOARD_VENDORIMAGE_PARTITION_SIZE := 1610612736

### DISPLAY
TARGET_SCREEN_DENSITY := 300

### PROPS
# Add device-specific ones
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop
