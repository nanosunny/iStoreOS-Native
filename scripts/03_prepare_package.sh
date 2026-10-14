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
