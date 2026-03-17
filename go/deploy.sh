#!/bin/bash
# Go 程序 Docker 部署脚本（仅容器化）
# author: 李广龙 (Go 版)
version=v1.0-docker-only

#################################################################
# ====== 配置区（按需修改）======
#################################################################
# Go 二进制文件名（留空则自动查找）
BINARY_NAME=""

# 项目名称（默认同二进制名）
SERVICE_NAME=""



# 实例数量（单实例设为 1）
INSTANCES=1

# 镜像和二进制备份保留数量
ReservedImagesNum=5
ReservedBinNum=10

# 是否自动部署（true = 执行即部署，false = 显示菜单）
AUTOMATIC=false

#################################################################
# ====== 自动推导路径 ======
#################################################################
script_dir=$(readlink -f "$0")
bootpath=$(dirname "$script_dir")
logspath="$bootpath/logs"
configpath="$bootpath/config"
backpath="$bootpath/back"

# 自动查找可执行文件（排除脚本、隐藏文件等）
if [ -z "$BINARY_NAME" ]; then
  BINARY_NAME=$(find "$bootpath" -maxdepth 1 -type f -executable ! -name "*.sh" ! -name ".*" ! -name "*.txt" ! -name "Dockerfile" | head -n 1)
  [ -z "$BINARY_NAME" ] && { echo "❌ 未找到可执行的 Go 二进制文件！"; exit 1; }
  BINARY_NAME=$(basename "$BINARY_NAME")
fi

[ -z "$SERVICE_NAME" ] && SERVICE_NAME="$BINARY_NAME"
SERVER_BIN_PATH="$bootpath/$BINARY_NAME"
DATEVERSION=$(date +'%Y%m%d%H%M')
IP=$(ip -4 addr show scope global 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || echo "127.0.0.1")

# 颜色
RED='\e[1;31m'; GREEN='\e[1;32m'; YELLOW='\033[1;33m'; RES='\033[0m'

#################################################################
# ====== 辅助函数 ======
#################################################################
setupDirs() {
  mkdir -p "$configpath" "$logspath" "$backpath"
}

createDockerfile() {
  cat > "$bootpath/Dockerfile" <<EOF
FROM alpine:3.22
WORKDIR /app
COPY $BINARY_NAME .
COPY config ./config
RUN chmod +x ./$BINARY_NAME
ENV TZ=Asia/Shanghai
ENTRYPOINT ["./$BINARY_NAME", "--config", "config"]
EOF
  echo -e "${GREEN}✅ Dockerfile 已生成${RES}"
}

backupBinary() {
  cp "$SERVER_BIN_PATH" "$backpath/${DATEVERSION}_${BINARY_NAME}"
  echo -e "${GREEN}📦 二进制已备份: ${backpath}/${DATEVERSION}_${BINARY_NAME}${RES}"
  # 清理旧备份
  ls -1t "$backpath"/"${BINARY_NAME}"* 2>/dev/null | tail -n +$((ReservedBinNum + 1)) | xargs -r rm
}

deployDocker() {
  echo -e "${YELLOW}🚀 开始部署 $SERVICE_NAME (实例数: $INSTANCES)${RES}"

  setupDirs
  backupBinary

  createDockerfile

  # 构建镜像
  echo "📦 构建镜像: $SERVICE_NAME:$DATEVERSION"
  docker build -t "$SERVICE_NAME:$DATEVERSION" "$bootpath" || { echo "❌ 镜像构建失败"; exit 1; }

  # 停止并删除旧容器
  for ((i=0; i<INSTANCES; i++)); do
    name="${SERVICE_NAME}-$i"
    docker stop "$name" 2>/dev/null
    docker rm -f "$name" 2>/dev/null
  done

  # 启动新容器（host 网络模式）
  for ((i=0; i<INSTANCES; i++)); do
    name="${SERVICE_NAME}-$i"
    echo "▶ 启动容器: $name "
    docker run -d \
      --name "$name" \
      --network host \
      -v "$configpath:/app/config" \
      -v "$logspath:/app/logs" \
      --restart=always \
      --log-opt max-size=100m --log-opt max-file=5 \
      "$SERVICE_NAME:$DATEVERSION"
  done

  # 清理旧镜像（保留最新 N 个）
  echo "🧹 清理旧镜像（保留 $ReservedImagesNum 个）"
  docker images "$SERVICE_NAME" --format "{{.Tag}} {{.ID}}" | sort -r | tail -n +$((ReservedImagesNum + 1)) | awk '{print $2}' | xargs -r docker rmi

  echo -e "${GREEN}✅ 部署完成！${RES}"
}

showMenu() {
  echo
  echo -e "${GREEN}= 0. 一键部署（构建+启动容器）${RES}"
  echo -e "${BLUE}= 1. 仅生成 Dockerfile 和目录${RES}"
  echo -e "${YELLOW}= 2. 查看日志（实例0）${RES}"
  echo -e "${RED}= 3. 停止并删除所有容器${RES}"
  echo
}

stopAllContainers() {
  for ((i=0; i<INSTANCES; i++)); do
    name="${SERVICE_NAME}-$i"
    docker stop "$name" 2>/dev/null
    docker rm -f "$name" 2>/dev/null
    echo "⏹️  容器 $name 已删除"
  done
}

viewLogs() {
  name="${SERVICE_NAME}-0"
  if docker ps -a --format '{{.Names}}' | grep -q "^$name$"; then
    docker logs --tail=100 -f "$name"
  else
    echo "⚠️  容器 $name 不存在"
  fi
}

#################################################################
# ====== 主逻辑 ======
#################################################################
if [ "$AUTOMATIC" = true ] || [ "$1" = "devops" ]; then
  deployDocker
else
  while true; do
    showMenu
    read -p "请选择操作: " choice
    case $choice in
      0) deployDocker ;;
      1) setupDirs; createDockerfile ;;
      2) viewLogs ;;
      3) stopAllContainers ;;
      *) echo "👋 退出"; break ;;
    esac
    echo "---"
  done
fi