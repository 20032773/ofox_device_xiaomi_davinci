# OrangeFox Recovery R12 — Xiaomi Mi 9T / Redmi K20 (davinci)

> [!NOTE]
> **2026-11-10 — Format Data fixed.** The first release (`R12.0-davinci-20261109`, now withdrawn)
> could not format data, because the metadata-encryption dm device was still holding the userdata
> partition. Fixed by enabling `OF_USE_DMCTL`, and verified: format → LOS sets up fresh encryption
> → OrangeFox decrypts it.
> Flashing other recoveries afterwards works; the earlier report turned out to be a false alarm.
>
> **2026-11-10 — 格式化 data 已修正。** 第一版 Release（已下架）無法格式化 data，
> 原因是 metadata 加密的 dm 裝置還佔用著 userdata 分區。打開 `OF_USE_DMCTL` 後已修正，並實測完整流程：
> 格式化 → LOS 重新建立加密 → OrangeFox 成功解密。刷入其他 recovery 也確認正常，之前的回報是誤判。

OrangeFox Recovery **R12.0** (`fox_16.0`, Android 16 base) device tree for davinci / davinciin.
It **fully decrypts LineageOS 23.2** (Android 16), which earlier OrangeFox/TWRP builds could not.
The crypto setup is also compatible with LineageOS 24.0.

> 繁體中文說明在下方。

## Status

| Feature | Status |
|---|---|
| Boot (`fastboot boot` / `fastboot flash recovery`) | ✅ |
| Decryption: metadata encryption + FBE v2 + wrapped keys (LOS 23.2), no lock screen | ✅ |
| Decryption with a lock screen PIN / password | ✅ |
| Mount system / vendor / product / system_ext / odm (retrofit dynamic partitions) | ✅ |
| Backup (boot partition; backup verified identical to the partition) | ✅ |
| ADB, MTP (browse storage from PC), logcat | ✅ |
| Vibration | ✅ |
| Flashing a kernel zip (AnyKernel3) | ✅ |
| Format Data (then LOS re-encrypts, then OrangeFox decrypts again) | ✅ |
| Flashing another recovery afterwards | ✅ |
| Restore / flashing ROM zips | ⚠️ not tested yet |

Known issue in builds before commit `a8e8f5c`: system could not be mounted, so rebooting showed a "No OS installed" warning. The release build fixes this (system is detected as 1009 MB; the warning threshold is 50 MB).

Tested on davinci with LineageOS 23.2 (2026-11-08 nightly).

## Install

> **Important — LineageOS restores its own recovery on every boot.** First go to
> **Settings → System → Updater → ⋮ → Preferences** and turn off **"Update recovery"**
> (`persist.vendor.recovery_update=false`). If you skip this, OrangeFox is replaced
> by the stock LOS recovery the next time the system boots
> (`vendor_flash_recovery` → `/vendor/bin/install-recovery.sh`).
>
> Note: whenever system/vendor is mounted, OrangeFox (by upstream design) renames
> `/vendor/bin/install-recovery.sh` to `wlfx0install-recoverybak0xwlf` so that the stock recovery
> can no longer overwrite it. LineageOS still boots normally (tested). A LOS update restores the file.
>
> **Formatting data resets this setting to "on"** (it is stored in `/data`). After a format, turn it
> off again before flashing OrangeFox, or LOS will put its own recovery back.

```bash
fastboot boot OrangeFox-R12.0_LOS23-24-Unofficial-davinci.img       # optional: test without flashing
fastboot getvar product                                             # see note below
fastboot flash recovery OrangeFox-R12.0_LOS23-24-Unofficial-davinci.img
fastboot reboot
```

If `fastboot flash` fails with `Requested download size is more than max allowed`, the bootloader
wasn't ready yet; the real limit is 768 MB. Send any command first (e.g. `fastboot getvar product`),
or `fastboot reboot bootloader`, then flash again.

## Build

Sync the OrangeFox `fox_16.0` manifest:

```bash
mkdir orangefox && cd orangefox
repo init --depth=1 -u https://gitlab.com/OrangeFox/Manifest.git -b fox_16.0
mkdir -p .repo/local_manifests
cp <this repo>/local_manifests/davinci.xml .repo/local_manifests/
repo sync -c -j4 --no-clone-bundle --no-tags
git clone https://github.com/20032773/ofox_device_xiaomi_davinci device/xiaomi/davinci
```

Then build:

```bash
export ALLOW_MISSING_DEPENDENCIES=true FOX_BUILD_DEVICE=davinci
source build/envsetup.sh
lunch twrp_davinci-bp2a-eng
m recoveryimage
```

The output is `out/target/product/davinci/OrangeFox-R12.0_*-davinci.img`.

Notes:
- Soong analysis needs about 32 GB of RAM plus swap. With 24 GB and no swap it gets OOM-killed.
- `local_manifests/davinci.xml` pins `external/util-linux`. Its 2026-11-08 commit adds a `libblkid`
  that conflicts with `bootable/recovery/libblkid`.
- Google's servers rate-limit (HTTP 429) syncs at high `-j` values. Use `-j4` if a sync fails.

## Updating blobs / kernel (e.g. LineageOS 24)

`extract-files.sh` pulls the decryption blobs from
[TheMuppets/proprietary_vendor_xiaomi_sm6150-common](https://github.com/TheMuppets/proprietary_vendor_xiaomi_sm6150-common).
It also takes the kernel, dtb and recovery dtbo from the official LineageOS `recovery.img`:

```bash
./extract-files.sh lineage-23.2                     # default
./extract-files.sh lineage-24.0                     # LOS 24 blobs + latest official 24.0 recovery
./extract-files.sh lineage-24.0 /path/recovery.img  # use a specific recovery.img
```

## Pitfalls solved in this tree

1. **Ramdisk size → no boot.** With gzip the ramdisk is about 36 MB. The davinci bootloader then
   silently refuses to start the kernel and drops back to fastboot. The tree uses
   `OF_USE_LZMA_COMPRESSION := 1` (about 22 MB). The LOS kernel supports `RD_LZMA` but not XZ/LZ4.
2. **`/data` mount options → no decryption.** The old tree used f2fs options from newer kernels
   (`gc_merge`, `atgc`, `checkpoint_merge`, `compress_extension`). The 4.14 kernel rejects them,
   recovery remounts `/data` with no options, and `inlinecrypt` is lost. Hardware-wrapped keys then
   can't be installed (`fscrypt_init_user0 returned fail`). The `/data` line now comes from LOS
   `fstab.default`, and `twrp.flags` no longer overrides `/data`.
3. **logd crash.** In Android 16, logd aborts in recovery unless it gets the `logd` control socket
   and `task_profiles.json`. Both are added.
4. **Recovery dtbo.** Use the 0.7 MB dtbo from inside `recovery.img`, not the 32 MB zero-padded
   `dtbo.img`. The padded one makes the image larger than the 64 MB recovery partition.
5. **Keymaster 4.1.** LOS 23.x/24.x use Keymaster 4.1 (not 4.0) and wrapped keys
   (`wrappedkey_v0`). The blobs are taken from the matching LOS vendor tree.
6. **Retrofit dynamic partitions.** davinci has no `super` partition; the metadata lives on
   `system`. OrangeFox's logical-partition code only understands `super`, so it dropped
   system/vendor/product/system_ext/odm from its partition list. The old tree pointed them at the
   raw `by-name/system` partitions, which can't be mounted. init already creates
   `/dev/block/mapper/*` at boot, so `twrp.flags` points directly at the mapper devices.
7. **Format Data.** With metadata encryption, `/data` sits on a dm-default-key device
   (`/dev/block/mapper/userdata`) on top of `sda32`. Without `OF_USE_DMCTL`, recovery only unmounts
   `/data`, and `make_f2fs` on the raw partition fails with `Error: In use by the system!`.
   `OF_USE_DMCTL := 1` runs `dmctl delete userdata` first.

## Credits

- Based on [DavinciRecoveries/twrp_device_xiaomi_davinci](https://github.com/DavinciRecoveries/twrp_device_xiaomi_davinci) (twrp-12.1)
- [OrangeFox Recovery Project](https://gitlab.com/OrangeFox), [TeamWin](https://github.com/TeamWin)
- [LineageOS](https://github.com/LineageOS) (kernel, fstab) and [TheMuppets](https://github.com/TheMuppets) (vendor blobs)

Device tree sources: Apache-2.0. Proprietary blobs belong to their respective owners.

---

# 繁體中文說明

這是 davinci（小米 9T / Redmi K20）的 **OrangeFox R12.0**（`fox_16.0`，Android 16 底）裝置樹。
它可以**完整解密 LineageOS 23.2**，舊版 OrangeFox/TWRP 做不到。加密設定也與 LOS 24.0 相容。

## 安裝

> **重要：LineageOS 每次開機都會把 recovery 換回官方版。**
> 刷入前，先到 **設定 → 系統 → 更新程式 → 右上角 ⋮ → 偏好設定**，關閉 **「更新 recovery」**。
> 沒關的話，下次開進系統時，OrangeFox 就會被換回 LOS 官方 recovery。
>
> 補充：只要在 OrangeFox 裡掛載過 system/vendor，OrangeFox 就會照官方預設行為，
> 把 `/vendor/bin/install-recovery.sh` 改名成 `wlfx0install-recoverybak0xwlf`，防止官方 recovery 再蓋掉它。
> 改名後 LOS 仍可正常開機（已測試），LOS 系統更新時會把這個檔案還原。
>
> **格式化 data 會把這個設定重置成「開啟」**（設定存在 /data 裡）。格式化後要刷 OrangeFox 前，
> 請再到設定裡關一次，否則 LOS 開機時又會換回官方 recovery。

1. 先關閉上面說的「更新 recovery」。
2. 手機進 fastboot（關機後按住 電源 + 音量下）。
3. （可選）先暫時開機測試，這不會寫入手機：
   ```bash
   fastboot boot OrangeFox-R12.0_LOS23-24-Unofficial-davinci.img
   ```
4. 刷入 recovery 分區：
   ```bash
   fastboot getvar product
   fastboot flash recovery OrangeFox-R12.0_LOS23-24-Unofficial-davinci.img
   fastboot reboot
   ```
   如果出現 `Requested download size is more than max allowed`，是 bootloader 還沒準備好
   （實際上限是 768MB，不是檔案太大）。先隨便下一個指令，例如 `fastboot getvar product`，
   或 `fastboot reboot bootloader`，再刷一次就好。

## 解決過的問題

1. **ramdisk 太大，開不了機**：用 gzip 壓縮時約 36MB，davinci 的 bootloader 會直接退回 fastboot。
   改用 LZMA 壓縮（約 22MB）就能開機。
2. **`/data` 掛載選項錯誤，解不了密**：舊樹用了新版核心才有的 f2fs 選項（例如 `gc_merge`）。
   4.14 核心不認得，掛載時 `inlinecrypt` 跟著被丟掉，硬體包裝金鑰就裝不進去。
   現在改用 LOS 23.2 官方 fstab 的掛載選項。
3. **logd 崩潰**：Android 16 的 logd 需要額外的 socket 和 `task_profiles.json`，兩者都已補上。
4. **dtbo 太大**：要用 recovery.img 裡 0.7MB 的 dtbo，不能用補零到 32MB 的 dtbo.img，
   否則映像會超過 64MB 的 recovery 分區。
5. **Keymaster 4.1**：LOS 23/24 用的是 Keymaster 4.1 和硬體包裝金鑰，加密相關檔案取自對應的 LOS vendor。
6. **掛不上系統分區**：davinci 是改裝式動態分區，沒有 super 分區，分區表放在 system 上。
   OrangeFox 只認 super，所以把 system/vendor 等分區從清單拿掉了。
   開機時系統已經建好 `/dev/block/mapper/*`，所以 `twrp.flags` 直接指定這些路徑。
7. **無法格式化 data**：有 metadata 加密時，`/data` 是架在 sda32 上的加密映射裝置（`/dev/block/mapper/userdata`）。
   原本格式化前只卸載 `/data`，沒有拆掉這層映射，`make_f2fs` 就會失敗並回報 `Error: In use by the system!`。
   打開 `OF_USE_DMCTL := 1` 後，OrangeFox 會先執行 `dmctl delete userdata` 再格式化。

## 測試結果

| 功能 | 狀態 |
|---|---|
| 開機（fastboot boot / 刷入 recovery） | ✅ |
| 解密（無鎖屏 / 有鎖屏密碼） | ✅ |
| 掛載 system / vendor / product 等系統分區 | ✅ |
| 備份（boot 分區，備份檔與分區內容一致） | ✅ |
| ADB、MTP（電腦瀏覽手機檔案）、logcat | ✅ |
| 震動 | ✅ |
| 刷核心 zip（AnyKernel3） | ✅ |
| 格式化 data（之後 LOS 重建加密、OrangeFox 再次解密） | ✅ |
| 之後再刷其他 recovery | ✅ |
| 還原、刷 ROM zip | ⚠️ 尚未測試 |

已知問題（`a8e8f5c` 之前的版本）：掛不上 system，重啟時會誤報「沒有安裝系統」。Release 版已修正（system 偵測為 1009MB，警告門檻是 50MB）。

## 升級到 LOS 24

```bash
./extract-files.sh lineage-24.0
```

這個指令會自動抓 LOS 24 的加密相關檔案，以及官方 LOS 24 recovery 裡的核心，然後重新編譯即可。
LOS 24.0 的 fstab 加密設定和加密檔案都跟 23.2 相同。
