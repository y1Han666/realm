#!/bin/bash

# 1. 权限检查
[[ $EUID -ne 0 ]] && echo "Error: Please run as root." && exit 1

# 2. 架构检测
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  TAG="x86_64-unknown-linux-gnu.tar.gz" ;;
    aarch64) TAG="aarch64-unknown-linux-gnu.tar.gz" ;;
    armv7l)  TAG="armv7-unknown-linux-gnueabihf.tar.gz" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# 3. 获取最新版本 URL (排除 slim)
URL=$(curl -s https://api.github.com/repos/zhboner/realm/releases/latest | \
      grep "browser_download_url" | \
      grep "$TAG" | \
      grep -v "slim" | \
      cut -d '"' -f 4 | head -n 1)

if [ -z "$URL" ]; then
    echo "Error: Could not find download URL."
    exit 1
fi

# 4. 下载并安装程序
echo "Updating realm to latest version..."
curl -L "$URL" -o realm.tar.gz
tar -xzvf realm.tar.gz
chmod +x realm
mv -f realm /usr/bin/realm
rm -f realm.tar.gz

# 5. 配置目录 (仅在不存在时创建配置)
mkdir -p /etc/realm
if [ ! -f /etc/realm/config.toml ]; then
    cat <<EOF > /etc/realm/config.toml
[[endpoints]]
listen = "0.0.0.0:10000"
remote = "1.2.3.4:20000"
EOF
    echo "Default config created at /etc/realm/config.toml"
fi

# 6. 写入 Systemd 服务
cat <<EOF > /etc/systemd/system/realm.service
[Unit]
Description=realm
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/realm -c /etc/realm/config.toml
Restart=always
RestartSec=5
LimitNOFILE=512000

[Install]
WantedBy=multi-user.target
EOF

# 7. 重载并重启
systemctl daemon-reload
systemctl enable realm
systemctl restart realm

echo "-----------------------------------------------"
echo "Realm has been installed/updated successfully!"
echo "Status: $(systemctl is-active realm)"
echo "-----------------------------------------------"
