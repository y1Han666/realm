#!/bin/bash

# 1. 环境检查
[[ $EUID -ne 0 ]] && echo "请以 root 权限运行此脚本" && exit 1

# 2. 自动获取架构并匹配下载名
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  TAG="x86_64-unknown-linux-gnu.tar.gz" ;;
    aarch64) TAG="aarch64-unknown-linux-gnu.tar.gz" ;;
    armv7l)  TAG="armv7-unknown-linux-gnueabihf.tar.gz" ;;
    *) echo "暂时不支持的架构: $ARCH"; exit 1 ;;
esac

echo "检测到架构: $ARCH，正在获取最新版本..."

# 3. 精准获取最新版本下载链接 (排除 slim 版本)
URL=$(curl -s https://api.github.com/repos/zhboner/realm/releases/latest | \
      grep "browser_download_url" | \
      grep "$TAG" | \
      grep -v "slim" | \
      cut -d '"' -f 4 | head -n 1)

if [ -z "$URL" ]; then
    echo "错误：未能找到对应的下载链接，请检查网络。"
    exit 1
fi

# 4. 下载并安装
echo "正在从 $URL 下载..."
curl -L "$URL" -o realm.tar.gz
if [ $? -ne 0 ]; then echo "下载失败"; exit 1; fi

tar -xzvf realm.tar.gz
chmod +x realm
mv -f realm /usr/bin/realm
rm -f realm.tar.gz

# 5. 配置文件与服务设置 (保持不变)
mkdir -p /etc/realm
if [ ! -f /etc/realm/config.toml ]; then
    cat <<EOF > /etc/realm/config.toml
[[endpoints]]
listen = "0.0.0.0:10000"
remote = "1.2.3.4:20000"
EOF
    echo "已创建示例配置: /etc/realm/config.toml"
fi

cat <<EOF > /etc/systemd/system/realm.service
[Unit]
Description=realm
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/realm -c /etc/realm/config.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable realm
systemctl restart realm

echo "-----------------------------------------------"
echo "修复安装完成！"
echo "当前状态: $(systemctl is-active realm)"
echo "-----------------------------------------------"
