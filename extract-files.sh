#!/bin/bash
#
# 從 LineageOS 抓取 recovery 解密需要的檔案與核心
#
# 用法:
#   ./extract-files.sh                       # 預設 lineage-23.2 + 最新官方 build
#   ./extract-files.sh lineage-24.0          # 換成 LOS 24 的 vendor 檔案
#   ./extract-files.sh lineage-24.0 /path/recovery.img   # 用指定的 LOS recovery.img 取核心
#
# 會更新:
#   recovery/root/system/bin/   keymaster / gatekeeper / qseecomd
#   recovery/root/vendor/lib64/ 它們需要的 vendor 函式庫
#   prebuilt/                   Image.gz, dtb/davinci.dtb, dtbo.img (全部取自 LOS 官方 recovery.img)
#
set -euo pipefail

BRANCH="${1:-lineage-23.2}"
RECOVERY_IMG="${2:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/recovery/root"
RAW="https://raw.githubusercontent.com/TheMuppets/proprietary_vendor_xiaomi_sm6150-common/$BRANCH/proprietary"

# 解密需要的 vendor 執行檔 (放到 /system/bin，qcom twrp-common 的服務路徑)
BINS=(
    vendor/bin/hw/android.hardware.keymaster@4.1-service-qti
    vendor/bin/hw/android.hardware.gatekeeper@1.0-service-qti
    vendor/bin/qseecomd
)

# 依賴 (由 readelf 遞迴解析 + qseecomd 動態載入的 listener)
LIBS=(
    vendor/lib64/hw/android.hardware.gatekeeper@1.0-impl-qti.so
    vendor/lib64/libGPreqcancel.so
    vendor/lib64/libGPreqcancel_svc.so
    vendor/lib64/libQSEEComAPI.so
    vendor/lib64/libdiag.so
    vendor/lib64/libdrmfs.so
    vendor/lib64/libdrmtime.so
    vendor/lib64/libkeymasterdeviceutils.so
    vendor/lib64/libkeymasterutils.so
    vendor/lib64/libqcbor.so
    vendor/lib64/libqisl.so
    vendor/lib64/libqtikeymaster4.so
    vendor/lib64/librpmb.so
    vendor/lib64/libssd.so
    vendor/lib64/libtime_genoff.so
)

fetch() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    curl -sfL "$RAW/$src" -o "$dst" || { echo "抓取失敗: $src ($BRANCH)"; exit 1; }
    echo "  $src"
}

echo "== vendor 檔案來源: TheMuppets $BRANCH"
for b in "${BINS[@]}"; do
    fetch "$b" "$ROOT/system/bin/$(basename "$b")"
    chmod 0755 "$ROOT/system/bin/$(basename "$b")"
done
for l in "${LIBS[@]}"; do
    fetch "$l" "$ROOT/$l"
done

# ---- 核心 ----
VER="${BRANCH#lineage-}"
if [ -z "$RECOVERY_IMG" ]; then
    echo "== 從 LOS 官方伺服器找 davinci $VER 最新 recovery.img"
    URL=$(curl -sf https://download.lineageos.org/api/v2/devices/davinci/builds | python3 -c "
import json,sys
for b in json.load(sys.stdin):
    if b['version']=='$VER':
        print([f['url'] for f in b['files'] if f['filename']=='recovery.img'][0]); break
" || true)
    if [ -z "$URL" ]; then
        echo "LOS $VER 還沒有官方 build，核心保持不變 (可用第二個參數指定 recovery.img)"
        exit 0
    fi
    RECOVERY_IMG="$(mktemp)"
    curl -sfL "$URL" -o "$RECOVERY_IMG"
    echo "  $URL"
fi

python3 -I - "$RECOVERY_IMG" "$HERE/prebuilt" <<'EOF'
import struct, sys, os
img, out = sys.argv[1], sys.argv[2]
d = open(img, 'rb').read()
assert d[:8] == b'ANDROID!', 'not a boot image'
ks, _, rs, _, ss, _, _, ps, hv, _ = struct.unpack_from('<10I', d, 8)
assert hv == 2, f'expected header v2, got {hv}'
rdo_size, = struct.unpack_from('<I', d, 1632)
dtb_size, = struct.unpack_from('<I', d, 1648)
pg = lambda n: (n + ps - 1) // ps * ps
off = ps
kernel = d[off:off + ks]; off += pg(ks) + pg(rs) + pg(ss)
# recovery_dtbo: 用 recovery.img 裡的版本 (約 0.7MB)
# 不要用 dtbo 分區的 dtbo.img，它補零到 32MB，會讓 recovery.img 超過 64MB 分區
rdtbo = d[off:off + rdo_size]; off += pg(rdo_size)
dtb = d[off:off + dtb_size]
open(os.path.join(out, 'dtbo.img'), 'wb').write(rdtbo)
os.makedirs(out, exist_ok=True)
open(os.path.join(out, 'Image.gz'), 'wb').write(kernel)
os.makedirs(os.path.join(out, 'dtb'), exist_ok=True)
open(os.path.join(out, 'dtb', 'davinci.dtb'), 'wb').write(dtb)
print(f'  kernel {ks} bytes, recovery_dtbo {rdo_size} bytes, dtb {dtb_size} bytes')
EOF

zcat "$HERE/prebuilt/Image.gz" | strings | grep -m1 "Linux version" || true
echo "== 完成"
