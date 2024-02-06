#
# Copyright (C) 2016 The CyanogenMod Project
#               2017-2019 The LineageOS Project
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
#

ifeq ($(TARGET_SCREEN_WIDTH),)
    $(warning TARGET_SCREEN_WIDTH is not set, using default value: 1080)
    TARGET_SCREEN_WIDTH := 720
endif
ifeq ($(TARGET_SCREEN_HEIGHT),)
    $(warning TARGET_SCREEN_HEIGHT is not set, using default value: 1920)
    TARGET_SCREEN_HEIGHT := 1280
endif

TARGET_GENERATED_BOOTANIMATION := $(TARGET_OUT_INTERMEDIATES)/BOOTANIMATION/bootanimation.zip
$(TARGET_GENERATED_BOOTANIMATION): INTERMEDIATES := $(TARGET_OUT_INTERMEDIATES)/BOOTANIMATION
$(TARGET_GENERATED_BOOTANIMATION): $(SOONG_ZIP)
	@echo "Building bootanimation.zip"
	@rm -rf $(dir $@)
	@mkdir -p $(dir $@)
	$(hide) tar xfp vendor/lineage/bootanimation/bootanimation.tar -C $(INTERMEDIATES)
	IMAGEWIDTH:=720; \
	IMAGEHEIGHT:=1280; \
	RESOLUTION="$$IMAGEWIDTH"x"$$IMAGEHEIGHT"; \
	for part_cnt in 0 1 2 3 4; do \
	    mkdir -p $(INTERMEDIATES)/part$$part_cnt; \
	done; \
	prebuilts/tools-lineage/${HOST_OS}-x86/bin/mogrify -resize $$RESOLUTION $(INTERMEDIATES)/*/*.png; \
	echo "$$IMAGESCALEWIDTH $$IMAGESCALEHEIGHT 20" > $(INTERMEDIATES)/desc.txt; \
	cat vendor/lineage/bootanimation/desc.txt >> $(INTERMEDIATES)/desc.txt
	$(hide) $(SOONG_ZIP) -L 0 -o $(TARGET_GENERATED_BOOTANIMATION) -C $(INTERMEDIATES) -D $(INTERMEDIATES)

ifeq ($(TARGET_BOOTANIMATION),)
    TARGET_BOOTANIMATION := $(TARGET_GENERATED_BOOTANIMATION)
endif

include $(CLEAR_VARS)
LOCAL_MODULE := bootanimation.zip
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT)/media

include $(BUILD_SYSTEM)/base_rules.mk

$(LOCAL_BUILT_MODULE): $(TARGET_BOOTANIMATION)
	@cp $(TARGET_BOOTANIMATION) $@