#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/xiaomi/davinci

PRODUCT_SHIPPING_API_LEVEL := 28
PRODUCT_TARGET_VNDK_VERSION := 30

# Dynamic partitions (retrofit)
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_RETROFIT_DYNAMIC_PARTITIONS := true
PRODUCT_PACKAGES += fastbootd
PRODUCT_PACKAGES += android.hardware.fastboot@1.1-impl-mock

# Qualcomm decryption (device/qcom/twrp-common)
PRODUCT_PACKAGES += \
    qcom_decrypt \
    qcom_decrypt_fbe

PRODUCT_SOONG_NAMESPACES += $(LOCAL_PATH)

PRODUCT_SYSTEM_PROPERTY_BLACKLIST += \
    ro.product.device \
    ro.product.name \
    ro.build.product \
    ro.bootimage.build.date.utc \
    ro.build.date.utc
