#!/bin/bash
# 李广龙
# 脚本说明: 部署 Python 项目
# 主目录只保留一个 .py 作为入口，其他 py 放到子文件夹；镜像名=入口文件名(无.py)
INSTRUCTIONS="部署 Python 项目(入口=当前目录唯一.py)"
# author: 李广龙
# email: nuo010@126.com
version=v3.4
#################################################################
# 更新计划
# Python 基础镜像（仅当自动生成 Dockerfile 时使用）
PYTHON_IMAGE=python:3.12-slim
#=======================================
# 后台 Python 部署 ======================
# python 解释器，空则用 python3
PYTHON_PATH=""
# 主入口脚本（空则自动取当前目录唯一的 .py）
APP_ENTRY=""
#======================================
# 默认实例数
INSTANCES=1
# 或者执行脚本时添加 devops 参数即可
AUTOMATIC=false
#AUTOMATIC=true

# 自动部署方式
DEVOPSMODE=docker
#################################################################
# 备份目录 back/ 下保留的备份数量（按时间戳目录）
ReservedBackupNum=10
# docker 镜像保留数量
ReservedDockerImagesNum=5
#################################################################
# 项目名/镜像名（空则=入口.py 去掉扩展名，由脚本自动检测）
SERVICE_NAME=""
# 主入口脚本路径（相对 bootpath，空则自动检测）
SERVICE_PATH=""
SERVER_ALL_PATH=""
# 挂载目录（仅 data 用于配置/会话，不挂载 downloads）
DATA_PATH=data
LOG_PATH=logs
BACK_PATH=back


IP=$(ifconfig -a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addrs" | tr '\n' ';')
# 当前时间
DATEVERSION=$(date +'%Y%m%d%H%M')
# 获取当前 sh 所在目录的绝对路径（兼容 Linux/macOS）
bootpath=$(cd "$(dirname "$0")" && pwd)
logspath=$bootpath/$LOG_PATH
datapath=$bootpath/$DATA_PATH
backpath=$bootpath/$BACK_PATH

# 颜色定义（需在 detect_py_entry 前）
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\033[1;33m'
BLUE='\E[1;34m'
PINK='\E[1;35m'
RES='\033[0m'

# 当前目录有且仅有一个 .py 时：作为入口，其名(无.py)作为 SERVICE_NAME/镜像名
detect_py_entry() {
  local count=0
  local found=""
  for f in "$bootpath"/*.py; do
    [ -f "$f" ] || continue
    count=$((count + 1))
    found=$f
  done
  if [ "$count" -ne 1 ]; then
    echo -e "${RED}当前目录须有且仅有 1 个 .py 文件作为入口，当前有 ${count} 个，退出!${RES}" >&2
    exit 1
  fi
  APP_ENTRY=$(basename "$found")
  SERVICE_NAME="${APP_ENTRY%.py}"
}
if [ -z "$APP_ENTRY" ]; then
  detect_py_entry
fi
if [ -z "$PYTHON_PATH" ]; then
  PYTHON_PATH="python3"
fi
if [ -z "$SERVICE_PATH" ]; then
  SERVICE_PATH=$APP_ENTRY
fi
if [ -z "$SERVICE_NAME" ]; then
  SERVICE_NAME="${APP_ENTRY%.py}"
fi
SERVER_ALL_PATH="${bootpath}/${SERVICE_PATH}"

# docker 多实例的情况下删除 日志
rmPortLogs() {
  if [ $INSTANCES -gt 1 ]; then
    echo "多实例,$INSTANCES 删除logs文件!,$logspath/*"
    rm -rf $logspath/*
  fi
}



# touch Dockerfile
createDockerfile() {
  # 镜像名/入口由变量决定：当前目录唯一 .py 作为入口，其名为 SERVICE_NAME
  cat >./Dockerfile <<DOCKERFILE_EOF
FROM ${PYTHON_IMAGE}
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE ${OPEN_PORT}
CMD ["python", "${APP_ENTRY}"]
DOCKERFILE_EOF
}

createDockerIgnore() {
  cat >./.dockerignore <<EOF
data
logs
back
*.pyc
__pycache__
.git
Dockerfile
.dockerignore
deploy.sh
EOF
}
createConfLogs() {
  for dir in "$DATA_PATH" "$LOG_PATH" "$BACK_PATH"; do
    if [ ! -d "$bootpath/$dir" ]; then
      mkdir -p "$bootpath/$dir"
      echo -e "${GREEN} 创建 $dir 文件夹成功!${RES}"
    fi
  done
  if [ ! -f "$bootpath/Dockerfile" ]; then
    echo -e "${GREEN} 创建 Dockerfile 成功!${RES}"
    createDockerfile
  fi
  if [ ! -f "$bootpath/.dockerignore" ]; then
    createDockerIgnore
  fi
}
init() {
  [ -z "$APP_ENTRY" ] && detect_py_entry
  createConfLogs
  if [ ! -f "$bootpath/$APP_ENTRY" ]; then
    echo -e "${RED} $bootpath 下未找到 $APP_ENTRY，退出脚本!${RES}"
    exit 1
  fi
}

# 删除docker同服务的镜像
deleteOldAllImage() {
  #  echo -e "${RED}要删除镜像手动 请手动删除 docker备份基于镜像备份${RES}"
  echo -e "${RED}清除当前docker镜像${RES}"
  arr=$(docker images | grep "${SERVICE_NAME}" | awk '{print $2}')
  #echo ================
  #echo docker image rmi -f "$SERVICE_NAME":"$arr"
  docker image rmi -f "$SERVICE_NAME":"$arr" >>/dev/null 2>&1
  #docker image ls
}
deleteServerNameAllImage() {
  echo -e "${RED}❌删除${SERVICE_NAME}镜像,只保留最新的${ReservedDockerImagesNum}个${RES}"
  echo -e "${RED}❌版本不同镜像id相同的需要手动进行删除${RES}"
  arr=$(docker images --no-trunc | grep "${SERVICE_NAME}" | tr -s ' ' | cut -d ' ' -f 3 | cut -d ':' -f 2)
  array=(${arr//\n/ })
  echo -e "${RED}❌当前备份镜像数量:${#array[*]}${RES}"
  if [ ${#array[*]} -ge ${ReservedDockerImagesNum} ]; then
    docker rmi -f $(docker images --no-trunc | grep "${SERVICE_NAME}" | tail -n +${ReservedDockerImagesNum} | tr -s ' ' | cut -d ' ' -f 3 | cut -d ':' -f 2)
  fi
}
# delete old containers
deleteOldContainer() {
  OLD_INSTANCES=$(docker container ps -a | grep -i $SERVICE_NAME | wc -l)
  for ((i = 0; i < $OLD_INSTANCES; i++)); do
    docker container stop $SERVICE_NAME-$i >>/dev/null 2>&1
    docker container rm -f $SERVICE_NAME-$i >>/dev/null 2>&1
  done
  # rm -rf $bootpath/logs;
  if docker container ps -a | grep -i $SERVICE_NAME; then
    echo -e $RED hase $OLD_INSTANCES instances. $RES
  fi
  #  docker container ps
}

# 打包docker镜像
# 已当前运行脚本的时间为版本号
buildImage() {
  docker build -t $SERVICE_NAME:$DATEVERSION .
  #  docker image ls
}

# 运行镜像（仅挂载 data，映射端口；镜像名=变量 SERVICE_NAME）
runImage() {
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    docker container rm -f $name >>/dev/null 2>&1
    echo "❌删除容器>>>>>>>>>>>>>>>>>>>>>>: $name"
  done
  rmPortLogs
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    port=$(($HOST_PORT + $i))
    docker container rm -f $name >>/dev/null 2>&1
    echo -e $GREEN"📦创建容器: $name (端口 $port:$OPEN_PORT)"$RES
    docker run \
      --name "$name" \
      -p "$port:$OPEN_PORT" \
      -v "$datapath":/data \
      --restart=always \
      --log-opt max-size=100m --log-opt max-file=10 \
      -d "$SERVICE_NAME":"$DATEVERSION"
    CONTAINERID_NEW=$(docker container ps -a | grep "${name}" | awk '{print $NF}')
    echo -e 📦已创建容器: $PINK"$CONTAINERID_NEW"$RES
    if [ $i -lt $INSTANCES ]; then
      sleep 1
    fi
  done
}
startContainer() {
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    port=$(($HOST_PORT + $i))

    docker container start $name >>/dev/null 2>&1
    #    echo start container is $name:$port:$OPEN_PORT
    echo 启动容器: $name
    if [ $i -lt $INSTANCES ]; then
      sleep 1
    fi
  done
  docker container ps
}
restartContainer() {
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    port=$(($HOST_PORT + $i))

    docker container restart $name >>/dev/null 2>&1
    #    echo restart container is $name:$port:$OPEN_PORT
    echo 重启容器 $name
    if [ $i -lt $INSTANCES ]; then
      sleep 1
    fi
  done
  # docker container ps
}
stopContainer() {
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    port=$(($HOST_PORT + $i))
    docker container stop $name >>/dev/null 2>&1
    #    echo stop container is $name:$port:$OPEN_PORT
    echo 停止容器: $name
    if [ $i -lt $INSTANCES ]; then
      sleep 1
    fi
  done
  docker container ps
}
rmContainer() {
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    port=$(($HOST_PORT + $i))
    docker container rm $name >>/dev/null 2>&1
    #    echo rm container is $name:$port:$OPEN_PORT
    echo 删除容器: $name
    if [ $i -lt $INSTANCES ]; then
      sleep 1
    fi
  done
  docker container ps
}
viewContainerLog() {
  if [ $INSTANCES -eq 1 ]; then
    showLog $SERVICE_NAME-0
  else
    # 存在多个容器时进行选择查看
    echo -e $GREEN show logs for containers: $RES
    docker ps -a | grep ${SERVICE_NAME} | awk '{print $1, $2, $(NF-1), $NF}'
    read -p '请输入容器id或name:' input
    showLog $input
  fi
}
showJarAllLog() {
  echo "${bootpath}"/logs/${LOG_FILENAME}
  tail -n 100 "${bootpath}"/logs/${LOG_FILENAME}
}
showLog() {
  docker container logs --tail=300 "$1"
}

current() {
  echo
  echo -e "${PINK}当前时间:$(date +'%Y-%m-%d %T')${RES}"
  echo
}
dockerRestart() {
  echo " 重启$SERVICE_NAME容器"
  docker restart "$SERVICE_NAME"-0
  echo -e "$RED 重启$SERVICE_NAME-0容器 成功!!!$RES"
}

dockerLogs() {
  if [ $INSTANCES -eq 1 ]; then
    dockerLogsF $SERVICE_NAME-0
  else
    # 存在多个容器时进行选择查看
    echo -e $GREEN show logs for containers: $RES
    docker ps -a | grep ${SERVICE_NAME} | awk '{print $1, $2, $(NF-1), $NF}'
    read -p '请输入容器id或name:' input
    dockerLogsF $input
  fi
}
dockerLogsF() {
  echo "查看$1容器日志"
  # docker logs "$1" -f
  docker logs -f -t --tail=500 "$1"
}

var() {
  echo IP "$IP"
  echo 服务名称 "$SERVICE_NAME"
  echo 入口脚本 "${bootpath}/${SERVICE_PATH}"
  echo 实例数量 $INSTANCES
  echo 端口映射 "$HOST_PORT:$OPEN_PORT"
  echo docker 镜像 "$SERVICE_NAME:$DATEVERSION"
  echo -e 宿主机 Python "${GREEN}$PYTHON_PATH${RES}"
  echo -e deploy 版本 "${GREEN}$version${RES}"
  echo data 目录 "$datapath"
  echo log 目录 "$logspath"
  echo -e "${GREEN}当前工作目录:${bootpath}${RES}"
  echo -e "当前脚本说明:" $PINK $INSTRUCTIONS $RES
  echo
}

# setting env var
setEnvironmentVariable() {
  ARRT=$1
  ARRT_NAME=$(echo "${ARRT}" | awk -F '=' '{print $1}')
  ARRT_VALUE=$(echo "${ARRT}" | awk -F '=' '{print $2}')
  # echo $ARRT_NAME is $ARRT_VALUE
  # shellcheck disable=SC2086
  if [ $ARRT_NAME == 'name' ]; then
    SERVICE_NAME=$ARRT_VALUE
  elif [ "$ARRT_NAME" == 'port' ]; then
    OPEN_PORT=$ARRT_VALUE
  elif [ "$ARRT_NAME" == 'ip' ]; then
    IP=$ARRT_VALUE
  elif [ $ARRT_NAME == 'i' ]; then
    INSTANCES=$ARRT_VALUE
  else
    echo
    echo -e $RED $ARRT no matches found. $RES
    echo
  fi
}
volumeList() {
  docker volume ls -qf dangling=true
}

deleteVolumeList() {
  docker volume rm $(docker volume ls -qf dangling=true)
}
isPort() {
  echo "************ 检查端口占用(${HOST_PORT}) **************"
  echo "************ 只能kill非docker容器占用的端口*************"
  port=$(netstat -nlp | grep :"${HOST_PORT}" | awk '{print $7}')
  port=${port%%/*}
  if [ ${#port} -gt 1 ]; then
    echo "端口占用-进程id: $port"
    kill -9 "$port"
    echo "开始 kill ${HOST_PORT} 端口占用进程!"
    if [ "$?" -eq 0 ]; then
      echo -e "\033[31mkill $port 成功!\033[0m"
    else
      echo -e "\033[31mkill $port 失败\033[0m"
    fi
  fi
}
getAppPid() {
  pid=$(ps -ef | grep "[p]ython.*${APP_ENTRY}" | awk '{print $2}')
  if [ -z "$pid" ]; then
    pid=$(ps -ef | grep "[p]ython3.*${APP_ENTRY}" | awk '{print $2}')
  fi
  count=$(echo "$pid" | wc -w)
  if [ "$count" -gt 1 ] 2>/dev/null; then
    echo "重名进程"
  else
    echo "$pid"
  fi
}
isPid() {
  echo "************** 查找进程($APP_ENTRY) ****************"
  ps -ef | grep "[p]ython.*${APP_ENTRY}"
  pid=$(getAppPid)
  echo "${bootpath}/${APP_ENTRY} 进程id: $pid"
  if [ -n "$pid" ]; then
    if [ "重名进程" = "$pid" ]; then
      echo -e "$RED存在多个 $APP_ENTRY 进程,请手动处理!$RES"
      exit 1
    fi
    echo "检测进程 Pid 不为空: $pid"
    kill -15 "$pid"
    for ((i = 1; i < 20; i++)); do
      pid=$(getAppPid)
      echo "等待 $APP_ENTRY 关闭, 等待次数:$i/20, Pid: $pid"
      sleep 1
      if [ -z "$pid" ] || [ "重名进程" = "$pid" ]; then break; fi
    done
    pid=$(getAppPid)
    if [ -n "$pid" ] && [ "重名进程" != "$pid" ]; then
      kill -9 "$pid"
      for ((i = 1; i < 10; i++)); do
        pid=$(getAppPid)
        echo "强制关闭, 等待次数:$i/10, Pid: $pid"
        sleep 1
        if [ -z "$pid" ] || [ "重名进程" = "$pid" ]; then break; fi
      done
    fi
    pid=$(getAppPid)
    if [ -n "$pid" ] && [ "重名进程" != "$pid" ]; then
      echo -e "\033[31m请手动处理!\033[0m"
    fi
  else
    echo -e "$RED进程不存在!$RES"
  fi
  echo "************** 关闭进程完毕 ****************"
}
runpython() {
  echo "************** 开始运行 Python 项目 ****************"
  (cd "$bootpath" && nohup $PYTHON_PATH "$APP_ENTRY" >> logs/run.log 2>&1 &)
  echo -e "$GREEN${bootpath}/${APP_ENTRY}$RES"
  echo "************** 运行完成 ****************"
}
backpython() {
  echo "📦************** 开始备份代码 ****************"
  mkdir -p "$backpath/$DATEVERSION"
  [ -f "$bootpath/$APP_ENTRY" ] && cp "$bootpath/$APP_ENTRY" "$backpath/$DATEVERSION/"
  [ -f "$bootpath/requirements.txt" ] && cp "$bootpath/requirements.txt" "$backpath/$DATEVERSION/"
  for d in "$bootpath"/*/; do
    [ -d "$d" ] || continue
    base=$(basename "$d")
    case "$base" in data|logs|back|.git) continue ;; esac
    cp -r "$d" "$backpath/$DATEVERSION/"
  done
  echo -e "$GREEN备份路径:back/${DATEVERSION}/ $RES"
  echo "📦************** 备份完成 ****************"
}
rmBackup() {
  echo "❌************** 清理过多备份 ****************"
  cd "$backpath" || exit
  # 备份目录名为时间戳如 202603061200，按时间升序最旧的在前
  for _ in $(seq 1 100); do
    count=$(find . -maxdepth 1 -type d -name '[0-9]*' 2>/dev/null | wc -l)
    [ "$count" -le "$ReservedBackupNum" ] 2>/dev/null && break
    OldDir=$(find . -maxdepth 1 -type d -name '[0-9]*' 2>/dev/null | sort | head -1)
    [ -z "$OldDir" ] && break
    rm -rf "$OldDir" && echo -e "$RED清理过时备份:$backpath/$OldDir$RES"
  done
  cd "$bootpath" || exit
  echo "❌************** 删除完成,默认保留 $ReservedBackupNum 个 ****************"
}

functionItems() {
  echo
  echo -e "$GREEN = 0. 🚀 部署单个 Docker 容器（Python 项目）$RES"
  echo -e "$BLUE = 1. 🔄 重启 $SERVICE_NAME ($INSTANCES) 容器 $RES"
  echo -e "$BLUE = 2. 🟢 启动容器 $SERVICE_NAME ($INSTANCES) 容器 $RES"
  echo -e "$RED = 3. 🛑 停止容器 $SERVICE_NAME ($INSTANCES) 容器 $RES"
  echo -e "$YELLOW = 4. 📝 查看 $SERVICE_NAME 容器日志(-f) $RES"
  echo -e "$BLUE = 5. ❌ 全部删除容器 $SERVICE_NAME ($INSTANCES) 容器 $RES"
  echo -e "$YELLOW = 6. 🧱 创建 Dockerfile/.dockerignore、data、downloads、logs、back 目录 $RES"
  echo -e "$GREEN = 7. 🟢 后台运行 Python 项目 ${bootpath}/${APP_ENTRY} $RES"
  echo -e "$BLUE = 8. 📦 备份代码到 back 目录 $RES"
  echo -e "$RED = 9. 🛑 结束后台 Python 进程 ${APP_ENTRY} $RES"
  echo
}
upgrade() {
  init
  backpython
  rmBackup
  deleteServerNameAllImage
  buildImage
  echo -e "${GREEN}📦打包镜像成功 ${SERVICE_NAME}${RES}"
  runImage
  echo -e "${GREEN} 🚀 运行镜像成功 🚀${RES}"
}
runpythons() {
  init
  isPid
  rmBackup
  backpython
  runpython
  sleep 2
  echo "************** 进程详情 **************"
  ps -ef | grep "[p]ython.*${APP_ENTRY}"
  pid=$(getAppPid)
  echo -e "${RED}Pid:$pid${RES}"
  echo "************** 后台启动 Python 完成！**************"
}

# shellcheck disable=SC2120
main() {
  functionItems
  read -p '⌨输入功能编号: (任意键退出)' input
  echo "输入编号:$input"
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>开始执行!!!"
  case $input in
  0)
    upgrade
    ;;
  1)
    restartContainer
    echo -e "${GREEN}重启容器${RES}"
    ;;
  2)
    startContainer
    echo -e "${GREEN}启动容器:${SERVICE_NAME}${RES}"
    ;;
  3)
    stopContainer
    echo -e "${GREEN}停止容器:${SERVICE_NAME}${RES}"
    ;;
  4)
    dockerLogs
    ;;
  5)
    rmContainer
    echo -e "${GREEN}删除容器:${SERVICE_NAME}${RES}"
    ;;
  6)
    createConfLogs
    if [ ! -f "$bootpath/Dockerfile" ]; then
      createDockerfile
      echo -e "${GREEN}Dockerfile 创建成功（Python 项目）$RES"
      cat Dockerfile
    else
      echo -e "${GREEN}已存在 Dockerfile，跳过$RES"
    fi
    [ ! -f "$bootpath/.dockerignore" ] && createDockerIgnore && echo -e "${GREEN}.dockerignore 创建成功$RES"
    ;;
  7)
    runpythons
    ;;
  8)
    backpython
    ;;
  9)
    isPid
    ps -ef | grep "[p]ython.*${APP_ENTRY}"
    ;;
  *)
    echo " _________________            "
    echo -e "${RED}< 退出脚本成功!... >${RES}"
    echo " -----------------            "
    echo "        \   ^__^              "
    echo "         \  (oo)\_______      "
    echo "            (__)\       )\/\  "
    echo "                ||----w |     "
    echo "                ||     ||     "
    exit 0
    ;;
  esac
}
echo -e "${YELLOW}当前工作目录:${bootpath}${RES}"
#查看目录文件
cd "$bootpath" || exit
ls -all
#for arg in $@
#do
#  setEnvironmentVariable $arg
#done
#版本信息
#readme
#当前时间
current
#变量值
var

# 判断是自动部署还是手动部署
if [ "$AUTOMATIC" = true ] || [ "$1" = "devops" ]; then
  if [ "docker" = "$DEVOPSMODE" ]; then
    upgrade
  else
    runpythons
  fi
else
  while true; do
    main
    sleep 1
  done
fi
