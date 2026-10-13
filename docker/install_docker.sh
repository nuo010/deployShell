#!/bin/bash

# Docker + Docker Compose 二进制离线安装脚本
# 版本: docker-26.1.3
# 下载源: 七牛云
# 使用方法: sudo bash install_docker.sh

set -e

# ============ 配置 ============
ARCH=$(uname -m)
DOWNLOAD_URL=""
COMPOSE_DOWNLOAD_URL=""
DOCKER_VERSION="26.1.3"
INSTALL_DIR="/usr/bin"
SERVICE_FILE="/etc/systemd/system/docker.service"
CONFIG_FILE="/etc/docker/daemon.json"
COMPOSE_DIR="/usr/libexec/docker/cli-plugins"
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"

# ============ 判断架构，选下载地址 ============
if [ "$ARCH" = "x86_64" ]; then
    DOWNLOAD_URL="http://singlecloud.cfsingle.fun/software/docker-${DOCKER_VERSION}.tgz"
    COMPOSE_DOWNLOAD_URL="https://singlecloud.cfsingle.fun/dockerimages/docker-compose-linux-x86_64"
    echo "检测到架构: x86_64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    DOWNLOAD_URL="https://singlecloud.cfsingle.fun/software/docker_arm-${DOCKER_VERSION}.tgz"
    COMPOSE_DOWNLOAD_URL="https://singlecloud.cfsingle.fun/dockerimages/docker-compose-linux-aarch64"
    echo "检测到架构: arm64"
else
    echo "不支持的架构: $ARCH，脚本退出"
    exit 1
fi

echo "Docker 下载地址: $DOWNLOAD_URL"
echo "Compose 下载地址: $COMPOSE_DOWNLOAD_URL"
echo "Docker 版本: $DOCKER_VERSION"
echo ""

# ============ 检查 root 权限 ============
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用 root 用户或 sudo 执行此脚本"
    exit 1
fi

# ============ 检查是否已安装 Docker ============
echo ">>> 检查本地 Docker 安装状态..."
if command -v docker &> /dev/null; then
    INSTALLED_DOCKER_VERSION=$(docker --version 2>/dev/null)
    echo ""
    echo "========================================"
    echo "本地已安装 Docker！"
    echo "$INSTALLED_DOCKER_VERSION"
    echo "========================================"
    echo ""
    echo "如需重新安装，请先手动卸载："
    echo "  systemctl stop docker"
    echo "  systemctl disable docker"
    echo "  rm -f /usr/bin/docker* /usr/bin/containerd* /usr/bin/ctr /usr/bin/runc"
    echo "  rm -f /etc/systemd/system/docker.service"
    echo "  systemctl daemon-reload"
    echo ""
    exit 0
else
    echo "本地未检测到 Docker，继续安装"
fi
echo ""

# ============ 检查 iptables 是否安装 ============
echo ">>> 检查 iptables 安装状态..."
if command -v iptables &> /dev/null; then
    echo "iptables 已安装: $(iptables --version 2>/dev/null)"
    echo "继续安装 Docker"
else
    echo ""
    echo "========================================"
    echo "iptables 未安装！"
    echo "========================================"
    echo ""
    echo "Docker 启动依赖 iptables，不安装会导致 Docker 启动失败。"
    echo "请先安装 iptables 后再执行本脚本："
    echo ""
    echo "  CentOS/RHEL:  yum install -y iptables iptables-services"
    echo "  Ubuntu/Debian: apt-get install -y iptables"
    echo ""
    echo "安装完成后重新执行本脚本即可。"
    echo ""
    exit 1
fi
echo ""

# ============ 1. 下载安装包 ============
echo ">>> 步骤1: 下载 Docker 安装包..."
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "工作目录: $WORK_DIR"
echo ""

if [ -f "docker-${DOCKER_VERSION}.tgz" ]; then
    echo "Docker 安装包已存在，跳过下载"
else
    wget -O "docker-${DOCKER_VERSION}.tgz" "$DOWNLOAD_URL"
fi

# 校验下载文件
DOCKER_TGZ_SIZE=$(stat -c%s "docker-${DOCKER_VERSION}.tgz" 2>/dev/null || echo 0)
if [ "$DOCKER_TGZ_SIZE" -lt 1000000 ]; then
    echo ""
    echo "========================================"
    echo "Docker 安装包下载失败！"
    echo "文件大小: ${DOCKER_TGZ_SIZE} 字节，明显不正常"
    echo "下载地址: $DOWNLOAD_URL"
    echo "========================================"
    echo ""
    echo "可能原因："
    echo "  1. 网络不通，无法连接七牛云"
    echo "  2. 下载地址失效"
    echo "  3. 磁盘空间不足"
    echo ""
    echo "请检查网络连通性后重新执行本脚本。"
    echo ""
    exit 1
fi
echo "Docker 安装包下载完成，大小: $((DOCKER_TGZ_SIZE / 1024 / 1024))MB"
echo ""

# ============ 2. 解压安装包 ============
echo ">>> 步骤2: 解压安装包..."
rm -rf docker/
tar -zxvf "docker-${DOCKER_VERSION}.tgz"

# 校验解压结果
if [ ! -f "docker/dockerd" ]; then
    echo ""
    echo "========================================"
    echo "Docker 解压失败！"
    echo "解压后未找到 docker/dockerd 文件，安装包可能已损坏"
    echo "========================================"
    echo ""
    echo "请删除 docker-${DOCKER_VERSION}.tgz 后重新执行本脚本："
    echo "  rm -f docker-${DOCKER_VERSION}.tgz"
    echo "  sudo bash install_docker.sh"
    echo ""
    exit 1
fi
echo "解压完成"
echo ""

# ============ 3. 将解压后的 Docker 文件移到 /usr/bin 目录下 ============
echo ">>> 步骤3: 复制 Docker 文件到 /usr/bin/ ..."
cp docker/* "$INSTALL_DIR/"
echo "复制完成"
echo ""

# ============ 4. 将 Docker 注册为系统服务 ============
echo ">>> 步骤4: 创建 systemd 服务文件..."
cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
[Install]
WantedBy=multi-user.target
EOF
echo "服务文件创建完成"
echo ""

# ============ 5. 给文件增加可执行权限 ============
echo ">>> 步骤5: 设置服务文件可执行权限..."
chmod +x "$SERVICE_FILE"
echo "权限设置完成"
echo ""

# ============ 6. 重新加载配置文件 ============
echo ">>> 步骤6: 重新加载 systemd 配置..."
systemctl daemon-reload
echo "配置重新加载完成"
echo ""

# ============ 7. 设置开机自启动 ============
echo ">>> 步骤7: 设置 Docker 开机自启..."
systemctl enable docker.service
echo "开机自启设置完成"
echo ""

# ============ 8. 配置 daemon.json ============
echo ">>> 步骤8: 创建 Docker 配置文件 daemon.json..."
mkdir -p /etc/docker
cat > "$CONFIG_FILE" << 'EOF'
{
    "data-root": "/var/lib/docker",
    "log-opts": {
        "max-size": "100m",
        "max-file": "5"
    },
    "registry-mirrors": [
        "https://docker.1ms.run",
        "https://docker.1panel.live",
        "https://docker.sparkcr.cn",
        "https://hub.rat.dev",
        "https://dockerproxy.net"
    ]
}
EOF
echo "配置文件创建完成"
echo ""

# ============ 9. 重新加载配置并启动 Docker ============
echo ">>> 步骤9: 重新加载配置并启动 Docker..."
systemctl daemon-reload
systemctl restart docker || true

# 检查 Docker 是否真正启动成功
if ! systemctl is-active --quiet docker; then
    echo ""
    echo "========================================"
    echo "Docker 启动失败！"
    echo "========================================"
    echo ""
    echo "Docker 服务状态:"
    systemctl status docker --no-pager || true
    echo ""
    echo "最近 20 行 Docker 日志（排查线索）:"
    journalctl -u docker --no-pager -n 20 2>/dev/null || true
    echo ""
    echo "常见原因："
    echo "  1. iptables 未启动或规则冲突"
    echo "  2. daemon.json 配置文件格式错误"
    echo "  3. 端口被占用（2375/2376）"
    echo "  4. 内核模块缺失（overlay/br_netfilter）"
    echo ""
    echo "请根据日志排查后重新启动："
    echo "  systemctl start docker"
    echo ""
    exit 1
fi
echo "Docker 启动成功"
echo ""

# ============ 10. 验证安装 ============
echo ">>> 验证 Docker 安装结果..."
docker --version
echo ""
systemctl status docker --no-pager
echo ""

# ============================================
# Docker Compose 插件安装
# ============================================
echo ""
echo "========== 开始安装 Docker Compose =========="
echo ""

# ============ 11. 下载 docker-compose 二进制文件 ============
echo ">>> 步骤11: 下载 docker-compose 二进制文件..."
cd "$WORK_DIR"

if [ -f "docker-compose-binary" ]; then
    echo "docker-compose 已存在，跳过下载"
else
    wget -O "docker-compose-binary" "$COMPOSE_DOWNLOAD_URL"
fi

# 校验下载文件
COMPOSE_BIN_SIZE=$(stat -c%s "docker-compose-binary" 2>/dev/null || echo 0)
if [ "$COMPOSE_BIN_SIZE" -lt 1000000 ]; then
    echo ""
    echo "========================================"
    echo "docker-compose 下载失败！"
    echo "文件大小: ${COMPOSE_BIN_SIZE} 字节，明显不正常"
    echo "下载地址: $COMPOSE_DOWNLOAD_URL"
    echo "========================================"
    echo ""
    echo "请检查网络连通性后重新执行本脚本。"
    echo ""
    exit 1
fi
echo "docker-compose 下载完成，大小: $((COMPOSE_BIN_SIZE / 1024 / 1024))MB"
echo ""

# ============ 12. 创建插件目录并复制文件 ============
echo ">>> 步骤12: 创建插件目录并安装 docker-compose..."
mkdir -p "$COMPOSE_DIR"
cp "docker-compose-binary" "$COMPOSE_DIR/docker-compose"
echo "安装完成"
echo ""

# ============ 13. 给可执行权限 ============
echo ">>> 步骤13: 设置 docker-compose 可执行权限..."
chmod +x "$COMPOSE_DIR/docker-compose"
echo "权限设置完成"
echo ""

# ============ 14. 验证 docker compose ============
echo ">>> 验证 docker compose 安装结果..."
docker compose version
echo ""

# ============ 15. 输出最终版本信息 ============
echo "========================================"
echo "Docker + Docker Compose 安装完成！"
echo "========================================"
echo ""
echo "安装版本信息："
echo "  Docker:        $(docker --version)"
echo "  Docker Compose: $(docker compose version 2>/dev/null | head -1)"
echo ""
echo "架构: $ARCH"
echo "工作目录: $WORK_DIR"
echo "安装包已保留在脚本所在目录，未清理。"
