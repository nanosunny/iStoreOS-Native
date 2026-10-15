#!/bin/bash -e

# 以“追加/注入”方式添加设备，不再整体覆盖上游 legacy.mk 和 uboot-rockchip/Makefile，
# 这样 istoreos-24.10 / istoreos-25.12 及以后的分支都能直接使用
KERNEL_PATCHVER=$(sed -n 's/^KERNEL_PATCHVER:=//p' target/linux/rockchip/Makefile)
UBOOT_MK=package/boot/uboot-rockchip/Makefile
UBOOT_SRC=package/boot/uboot-rockchip/src
echo "内核版本：$KERNEL_PATCHVER"

# 用法：add_uboot_target <U-Boot目标名> <SoC默认配置> <名称> <设备名>
# 会使用上游当前分支里对应 SoC 的 ATF/TPL 版本
add_uboot_target() {
  local target="$1" soc="$2" name="$3" devices="$4"
  grep -q "^define U-Boot/${target}\$" "$UBOOT_MK" && return 0
  awk -v t="$target" -v s="$soc" -v n="$name" -v d="$devices" '
    /^UBOOT_TARGETS := \\$/ {
      printf "define U-Boot/%s\n  $(U-Boot/%s/Default)\n  NAME:=%s\n  BUILD_DEVICES:= \\\n    %s\nendef\n\n", t, s, n, d
      print
      printf "  %s \\\n", t
      next
    }
    { print }' "$UBOOT_MK" > "$UBOOT_MK.tmp"
  mv "$UBOOT_MK.tmp" "$UBOOT_MK"
}

# ============================================================================================================
# 移植RK3566示例，其他RK35xx可模仿
# ============================================================================================================
# 增加设备（RK35xx 走 legacy.mk，使用上游通用 U-Boot）
cat >> target/linux/rockchip/image/legacy.mk <<'EOT'

define Device/panther_panther-x2
$(call Device/Legacy/rk3566,$(1))
  DEVICE_VENDOR := Panther
  DEVICE_MODEL := panther-x2
  DEVICE_DTS := rk3568/rk3566-panther-x2
  SUPPORTED_DEVICES += panther,panther-x2
  DEVICE_PACKAGES += kmod-scsi-core
endef
TARGET_DEVICES += panther_panther-x2

define Device/nsy_g68-plus
$(call Device/Legacy/rk3568,$(1))
  DEVICE_VENDOR := NSY
  DEVICE_MODEL := G68-PLUS
  DEVICE_DTS := rk3568/rk3568-nsy-g68-plus
  UBOOT_DEVICE_NAME := easepi-rk3568-rk809
  SUPPORTED_DEVICES += nsy,g68-plus
  DEVICE_PACKAGES += kmod-dsa-rtl8365mb kmod-nvme kmod-scsi-core kmod-mt7915e kmod-mt7916-firmware
endef
TARGET_DEVICES += nsy_g68-plus
EOT

# 复制dts到target/linux/rockchip/dts/rk3568
cp -f $GITHUB_WORKSPACE/configfiles/dts/rk3568/rk3566-panther-x2.dts target/linux/rockchip/dts/rk3568/
cp -f $GITHUB_WORKSPACE/configfiles/dts/rk3568/rk3568-nsy-g68-plus.dts target/linux/rockchip/dts/rk3568/

# 网口：G68-PLUS 的 RTL8367S 交换机走 DSA，lan1~lan4 + wan
sed -i '0,/^\tcase "$board" in$/s//&\n\tnsy,g68-plus)\n\t\tucidef_set_interfaces_lan_wan "lan1 lan2 lan3 lan4" "wan"\n\t\t;;/' \
  target/linux/rockchip/armv8/base-files/etc/board.d/02_network

# G68-PLUS：MT7916 无线（开源 mt76，板载 efuse 为空时读取默认 eeprom）+ RTL8367S 网口灯
G68=$GITHUB_WORKSPACE/configfiles/nsy-g68-plus
mkdir -p package/base-files/files/lib/firmware/mediatek package/kernel/mt76/patches
cp -f $G68/mt7916_eeprom.bin package/base-files/files/lib/firmware/mediatek/
cp -f $G68/990-mt76-add-mt7916-chipid.patch package/kernel/mt76/patches/
cp -f $G68/999-rtl8365mb-dsa-leds.patch target/linux/rockchip/patches-${KERNEL_PATCHVER}/

# 自定义 U-Boot 示例：Station M2 改用自编译的 station-m2-rk3566
add_uboot_target station-m2-rk3566 rk3566 "Station M2" firefly_station-m2
sed -i '/^define Device\/firefly_station-m2$/,/^endef$/{
  s/^  DEVICE_PACKAGES := /  DEVICE_PACKAGES += /
  /^endef$/i\  UBOOT_DEVICE_NAME := station-m2-rk3566
}' target/linux/rockchip/image/legacy.mk
cp -f $GITHUB_WORKSPACE/configfiles/dts/rk3568/rk3566-roc-pc.dts $UBOOT_SRC/arch/arm/dts/
cp -f $GITHUB_WORKSPACE/configfiles/uboot-rockchip/rk3566-station-m2-u-boot.dtsi $UBOOT_SRC/arch/arm/dts/
cp -f $GITHUB_WORKSPACE/configfiles/uboot-rockchip/station-m2-rk3566_defconfig $UBOOT_SRC/configs/
