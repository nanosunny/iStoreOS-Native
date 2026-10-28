#!/bin/bash -e

# ============================================================================================================
# 自定义DIY⬇⬇⬇
# ============================================================================================================
# TTYD
sed -i 's/procd_set_param stdout 1/procd_set_param stdout 0/g' feeds/packages/utils/ttyd/files/ttyd.init
sed -i 's/procd_set_param stderr 1/procd_set_param stderr 0/g' feeds/packages/utils/ttyd/files/ttyd.init
#sed -i '/${interface:+-i \$interface}/s/^/# /' feeds/packages/utils/ttyd/files/ttyd.init

# samba4 default config
sed -i 's/invalid users = root/#invalid users = root/g' feeds/packages/net/samba4/files/smb.conf.template

# 集成无线驱动
mkdir -p package/base-files/files/lib/firmware/brcm
cp -a $GITHUB_WORKSPACE/configfiles/firmware/brcm/* package/base-files/files/lib/firmware/brcm/

# 处理Rust报错
#sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile
rm -rf feeds/packages/lang/rust && git clone https://github.com/xiangfeidexiaohuo/extra-others && mv extra-others/rust feeds/packages/lang/

# ============================================================================================================
# OpenAppFilter (OAF) 应用过滤 相关兼容处理
# ============================================================================================================
# 1) 6.x 内核下 GCC 对 -Werror=missing-prototypes / -Werror=strict-prototypes 更加严格，
#    原生 OAF 代码会因缺少函数原型而编译失败（参见 destan19/OpenAppFilter#222）。
#    jjm2473 的 dev7 分支已修复大部分，但在某些内核版本上仍可能触发；这里在 feeds 安装后
#    给 oaf 内核模块的 Makefile 追加 EXTRA_CFLAGS，把相关错误降为警告，保证固件可编译。
if [ -d feeds/oaf/oaf ]; then
  OAF_KMOD_MK="feeds/oaf/oaf/Makefile"
  if ! grep -q "Wno-error=missing-prototypes" "$OAF_KMOD_MK" 2>/dev/null; then
    sed -i '/^MAKE_FLAGS/ a\  EXTRA_CFLAGS += -Wno-error=missing-prototypes -Wno-error=strict-prototypes -Wno-error=implicit-function-declaration' "$OAF_KMOD_MK"
    echo "[OAF] 已为 oaf 内核模块添加 -Wno-error 兼容编译参数"
  fi
fi

# 2) OAF 依赖内核 conntrack mark/netlink 功能。iStoreOS rockchip 默认内核已开启这些选项，
#    这里显式检查，若没开启则给出警告，方便排查。
for kopt in CONFIG_NF_CONNTRACK_MARK CONFIG_NETFILTER_NETLINK; do
  if ! grep -q "^${kopt}=y" linux-"${KERNEL_VER:-$(grep -oP 'KERNEL_PATCHVER:=\K.+' target/linux/rockchip/Makefile 2>/dev/null || echo 6.6)}"/.config 2>/dev/null; then
    echo "[OAF] 提示：建议确认内核选项 ${kopt}=y（iStoreOS rockchip 默认已开启，此提示仅作自检）"
  fi
done

# 3) 关闭与 OAF 冲突的软件/硬件流量加速提示（OAF 依赖 nf_conn mark，SFE/Fast Path 等加速
#    会绕过 netfilter，导致应用识别失效；默认保持防火墙 flow offloading 关闭）。
#    这里仅修改默认配置文件，不强制禁用用户在 LuCI 中的手动开关。
if [ -f package/network/config/firewall4/files/fw4.uc 2>/dev/null ] || \
   grep -q "flow_offloading" package/base-files/files/etc/uci-defaults/* 2>/dev/null; then
  :  # 不强制改写，仅作注释；用户使用时请在 OAF 页面或防火墙页关闭软/硬加速
fi

echo "[OAF] OpenAppFilter 兼容处理完成"

