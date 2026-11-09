#
# OrangeFox build variables for davinci
#
FDEVICE="davinci"

fox_get_target_device() {
    local chkdev=$(echo "$BASH_SOURCE" | grep -w \"$FDEVICE\")
    if [ -n "$chkdev" ]; then
        FOX_BUILD_DEVICE="$FDEVICE"
    else
        chkdev=$(set | grep BASH_ARGV | grep -w \"$FDEVICE\")
        [ -n "$chkdev" ] && FOX_BUILD_DEVICE="$FDEVICE"
    fi
}

if [ -z "$1" -a -z "$FOX_BUILD_DEVICE" ]; then
    fox_get_target_device
fi

if [ "$1" = "$FDEVICE" -o "$FOX_BUILD_DEVICE" = "$FDEVICE" ]; then
    export TARGET_DEVICE_ALT="davinciin"
    export FOX_TARGET_DEVICES="davinci,davinciin"
    export OF_MAINTAINER="minatok20"
    export FOX_VARIANT="LOS23-24"

    # 非 A/B，有獨立 recovery 分區
    export FOX_RECOVERY_INSTALL_PARTITION="/dev/block/bootdevice/by-name/recovery"
    export FOX_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
    export FOX_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"

    export FOX_USE_BASH_SHELL=1
    export FOX_USE_NANO_EDITOR=1
    export FOX_USE_TAR_BINARY=1
    export FOX_USE_SED_BINARY=1
    export FOX_ENABLE_APP_MANAGER=1
    export FOX_DELETE_AROMAFM=1
    export OF_USE_GREEN_LED=0
    export OF_FLASHLIGHT_ENABLE=0
    export OF_ALLOW_DISABLE_NAVBAR=0
    export OF_NO_TREBLE_COMPATIBILITY_CHECK=1
    export OF_SKIP_MULTIUSER_FOLDERS_BACKUP=1
else
    if [ -z "$FOX_BUILD_DEVICE" -a -z "$BASH_SOURCE" ]; then
        echo "I: This script requires bash. Not processing the $FDEVICE $(basename $0)"
    fi
fi
