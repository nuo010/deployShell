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
  [ -z "$BINARY_NAME" ] && { echo "未找到可执行的 Go 二进制文件！"; exit 1; }
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
  cat > "$bootpath/Dockerfile" <<EOF || return 1
FROM alpine:3.22
WORKDIR /app
COPY $BINARY_NAME .
COPY config ./config
RUN chmod +x ./$BINARY_NAME
RUN apk add --no-cache tzdata
ENV TZ=Asia/Shanghai
ENTRYPOINT ["./$BINARY_NAME", "--config", "config"]
EOF
  echo -e "${GREEN}Dockerfile 已生成${RES}"
}

createDockerIgnore() {
  cat > "$bootpath/.dockerignore" <<EOF
back
logs
EOF
}

backupBinary() {
  mkdir -p "$backpath" || return 1
  local backup
  backup=$(mktemp "$backpath/$(date +'%Y%m%d%H%M%S').XXXXXX") || return 1
  DATEVERSION=${backup##*/}
  [ ! -e "${backup}_${BINARY_NAME}" ] && [ ! -L "${backup}_${BINARY_NAME}" ] || { rm -f "$backup"; return 1; }
  if ! cp "$SERVER_BIN_PATH" "${backup}_${BINARY_NAME}"; then
    rm -f "${backup}_${BINARY_NAME}" "$backup"
    return 1
  fi
  rm -f "$backup" || return 1
  echo -e "${GREEN}二进制已备份: ${backpath}/${DATEVERSION}_${BINARY_NAME}${RES}"
  # 清理旧备份
  local old
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    rm -f "$old" || return 1
  done < <(ls -1t "$backpath"/*_"$BINARY_NAME" 2>/dev/null | tail -n +$((ReservedBinNum + 1)))
}

deployDocker() {
  echo -e "${YELLOW}开始部署 $SERVICE_NAME (实例数: $INSTANCES)${RES}"

  createConfigFiles || return 1
  backupBinary || { echo "备份失败，停止部署" >&2; return 1; }

  # 构建镜像
  echo "构建镜像: $SERVICE_NAME:$DATEVERSION"
  docker build -t "$SERVICE_NAME:$DATEVERSION" "$bootpath" || { echo "镜像构建失败"; return 1; }

  # 构建成功后才允许删除旧容器。
  removeAllContainers || return 1

  # 启动新容器（host 网络模式）
  for ((i=0; i<INSTANCES; i++)); do
    name="${SERVICE_NAME}-$i"
    echo "启动容器: $name"
    docker run -d \
      --name "$name" \
      --network host \
      -v "$configpath:/app/config" \
      -v "$logspath:/app/logs" \
      --restart=unless-stopped \
      --log-opt max-size=100m --log-opt max-file=5 \
      "$SERVICE_NAME:$DATEVERSION" || { echo "容器启动失败: $name" >&2; return 1; }
    [ "$(docker inspect --format '{{.State.Running}}' "$name")" = true ] || return 1
  done

  # 清理旧镜像（保留最新 N 个）
  echo "清理旧镜像（保留 $ReservedImagesNum 个）"
  docker images "$SERVICE_NAME" --format "{{.Tag}} {{.ID}}" | sort -r | tail -n +$((ReservedImagesNum + 1)) | awk '{print $2}' | xargs -r docker rmi

  echo -e "${GREEN}部署完成！${RES}"
}

showMenu() {
  echo
  echo -e "${GREEN}= 0. 部署（构建+启动容器）${RES}"
  echo -e "${GREEN}= 1. 重启容器${RES}"
  echo -e "${RED}= 2. 停止容器（不删除）${RES}"
  echo -e "${RED}= 3. 删除该服务的全部实例容器${RES}"
  echo -e "${YELLOW}= 4. 查看日志（实例0）${RES}"
  echo -e "${YELLOW}= 5. 创建配置文件和目录（已有文件不覆盖）${RES}"
  echo
}

restartAllContainers() {
  for ((i=0; i<INSTANCES; i++)); do
    name="${SERVICE_NAME}-$i"
    echo "重启容器: $name"
    docker restart "$name" || { echo "重启失败: $name；后续实例未执行" >&2; return 1; }
  done
}

stopAllContainers() {
  for ((i=0; i<INSTANCES; i++)); do
    name="${SERVICE_NAME}-$i"
    echo "停止容器: $name"
    docker stop "$name" || { echo "停止失败: $name；后续实例未执行" >&2; return 1; }
  done
}

removeAllContainers() {
  local names name suffix
  names=$(docker container ls -a --format '{{.Names}}') || return
  while IFS= read -r name; do
    [[ "$name" == "$SERVICE_NAME-"* ]] || continue
    suffix=${name#"$SERVICE_NAME-"}
    [[ "$suffix" =~ ^[0-9]+$ ]] || continue
    echo "删除容器: $name"
    docker container rm -f "$name" || return
  done <<< "$names"
  return 0
}

createConfigFiles() {
  setupDirs || return 1
  if [ ! -f "$bootpath/Dockerfile" ]; then
    createDockerfile || return 1
  fi
  if [ ! -f "$bootpath/.dockerignore" ]; then
    createDockerIgnore || return 1
  fi
}

viewLogs() {
  name="${SERVICE_NAME}-0"
  if docker ps -a --format '{{.Names}}' | grep -q "^$name$"; then
    docker logs --tail=100 -f "$name"
  else
    echo "容器 $name 不存在"
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
      1) restartAllContainers ;;
      2) stopAllContainers ;;
      3) removeAllContainers ;;
      4) viewLogs ;;
      5) createConfigFiles ;;
      *) echo "退出"; break ;;
    esac
    echo "---"
  done
fi