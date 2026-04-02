#!/bin/bash
# 李广龙
# 脚本说明:
# 当前脚本配置文件只对docker部署方式起作用jar启动参数以config文件夹内的配置文件为准
# 默认单应用部署流程
# 支持docker方式部署
# 支持后台jar部署
# 端口必须根据实际项目端口修改(OPEN_PORT/HOST_PORT),docker网桥模式下,不是网桥模式不用修改端口
# 非docker部署则不用修改端口
# 后台运行jar必须添加java的环境变量
# sh文件必须与项目文件放在同一文件夹中并并创建对应的文件夹[config,logs,back]
# 用于 配置,日志,备份使用
# jar 启动的时候不要有重名的jar名称 要不kill错误
# docker 方式启动的时候jar包name 不要有大写或者奇葩名字要不然报错
# 自定义简介说明
# 如果不使用端口映射，多实例项目启动的时候要用随机端口启动
# jar包名称一定要唯一,最好带上项目名,否者一台电脑多个项目同一个容器有可能重名
# 如果项目正在运行,一定不要随便替换config下的项目配置文件......切记,如果要替换和修改,一定要提前备份
INSTRUCTIONS="脚本说明"
# author: 李广龙
# email: nuo010@126.com
version=v3.5
#################################################################
# 更新计划
# 3.5
# 删除多余的输出内容
# 3.4
# 添加图标
# 3.3
# 取消docker内存限制
# 3.1
# 优化docker容器删除逻辑,优化备份jar查找jar数量命令
# 有个bug,利用jpom多实例启动4个实例的情况下,amdimboot中只能监听到3个不知道为什么,需要在脚本中重启下容器就好了,不知道为什么
# 更新记录:
# 2.9
# 删除命令1模式下重启容器后,查看容器列表的的逻辑
# 2.8
# 加大内存,不要限制太小,否者出现莫名其妙的问题
# 修改docker容器日志查询方式改为倒序
# docker images 低于报错数量时删除会报错,添加判断
# jar包备份数量参数化,docker启动可以直接0一键启动,不用在第一次启动的时候创建dockerfile等文件
# 2.1
# 删除无用提示
# 增加jar包备份数量
# 2.0
# 多实例启动时删除logs文件夹
# 修改命令位置
# 根据文件名称检测进程pid时,如果有多个不在直接获取第一个,如果有多个直接退出
# 1.9
# 优化kill关闭方式,匹配方式改为全量匹配,kill优先使用 -15
# 1.8
# jar运行的时候不要有重名的jar包,如果根据关键字查出来两个,默认取第一个
#1.7
# 删除无用功能
#1.6
# 添加输出默认版本号修改
#1.5
# 自动清理无用镜像,备份方式是直接备份jar包到back路径下
# back路径下只会保存最新的5个文件,5个之外的旧文件会自动清理

##################################################################
#docker部署前必须修改======================
# docker 容器和宿主机用同一个网络，不需要单独配置
# 不需要修改默认使用 host模式，部署网桥模式
# 项目端口号
OPEN_PORT=8080
# docker 主机端口 部署前检查此端口是否占用 如果占用kill
HOST_PORT=8080
# jdk版本
JDK_VERSION=8
# 默认x86架构
# arm64v8/openjdk:8
JDK_NAME=openjdk
# 挂载服务器上传文件保存路径 如果需要 在docker 启动的时候添加 挂载参数 项目文件输出地址
# 建议还是用文件服务系统,直接挂载后期处理麻烦
# FILE_SAVE_PATH=/root/file/
# 项目内部使用的外部资源文件 模板文件等 大型建议资源文件和代码分离
# FILE_INPUT_PATH=/root/file/resources
#=======================================
#-----------------------------------------------------------------
#java后台部署必须修改======================
# 所有参数依赖config文件夹内的配置文件或者自身的配置文件
# java环境变量 默认全局java 可以指定启动jdk路径
JAVA_PATH=""
# logs文件名字没法统一,该功能废弃
LOG_FILENAME=""
#======================================
# 默认实例
# 多实例要在项目中使用随机端口启动
INSTANCES=1
# 手动启动还是自动启动 (默认手动启动 false) docker 方式
################################################
################################################
#################devOps#########################
################################################
################################################
# 或者执行脚本时添加 devops 参数即可
AUTOMATIC=false
#AUTOMATIC=true

# 自动部署方式
# java、docker
DEVOPSMODE=docker
#################################################################
#备份/back/文件夹下的jar包文件保留数量
ReservedJarNum=10
# docker镜像保留数量
ReservedDockerImagesNum=5
#################################################################
# 是否进行邮件通知
SENDMAIL=false
#################################################################
# 项目名字 默认空会获取同级目录的jar包名
# 项目所在路径
# 项目绝对路径
SERVICE_NAME=""
SERVICE_PATH=""
SERVER_ALL_PATH=""
# 默认日志文件夹
LOG_PATH=/logs
# SpringBoot外部配置文件夹
CONFIG_PATH=/config
# 服务文件备份文件夹
BACK_PATH=/back

# 本地ip
# IP=$(ip a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | grep -v docker | awk '{print $2}' | tr -d 'addr:' | awk -F '/' '{print $1}' | head -1)
# 外网ip
#IP=$(curl ifconfig.me)
#IP="0.0.0.0"
IP=$(ifconfig -a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addrs" | tr '\n' ';')
# 当前时间
DATEVERSION=$(date +'%Y%m%d%H%M')
# 获取当前sh绝对路径
script_dir=$(readlink -f "$0")
# 获取父级路径
bootpath=$(dirname "$script_dir")
logspath=$bootpath$LOG_PATH
configpath=$bootpath$CONFIG_PATH
backpath=$bootpath$BACK_PATH

if [ ${#LOG_FILENAME} == 0 ]; then
  LOG_FILENAME="all.log"
fi
if [ ${#JAVA_PATH} == 0 ]; then
  JAVA_PATH="java"
fi
if [ ${#SERVICE_PATH} == 0 ]; then
  SERVICE_PATH=$(ls "$bootpath" | grep ".jar")
fi
if [ ${#SERVICE_NAME} == 0 ]; then
  SERVICE_NAME=${SERVICE_PATH%*.jar}
fi
SERVER_ALL_PATH="${bootpath}/${SERVICE_PATH}"

# 颜色定义
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\033[1;33m'
BLUE='\E[1;34m'
PINK='\E[1;35m'
RES='\033[0m'

# docker 多实例的情况下删除 日志
rmPortLogs() {
  if [ $INSTANCES -gt 1 ]; then
    echo "多实例,$INSTANCES 删除logs文件!,$logspath/*"
    rm -rf $logspath/*
  fi
}

# get all filename in specified path
getFileName() {
  path=$1
  files=$(ls $bootpath/jar)
  for filename in $files; do
    echo $filename # >> filename.txt
  done

  for file in $(find $1 -name "*.jar"); do
    echo $file
  done
}

# touch Dockerfile
createDockerfile() {
  #  --Dspring.config.location=/config/*
  cat >./Dockerfile <<EOF
FROM $JDK_NAME:$JDK_VERSION
#ADD ./ /code
ADD ${SERVICE_PATH} /code/${SERVICE_PATH}
ADD ./config /code/config
# 用来备份配置文件
ADD ./config /code/config_back
WORKDIR /code
#VOLUME $LOG_PATH
#EXPOSE $OPEN_PORT
ENV TZ=Asia/Shanghai
# 不同系统有兼容问题
# RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' >/etc/timezone

#-Xmx ：jvm的最大值	-XX:MaxHeapSize 的简写
#-Xms ：jvm的最小值	-XX:InitialHeapSize 的简写
#-Xss             -XX:ThreadStackSize 的简写  Stack 栈,最小328
# jinfo -flags pid,jinfo -flag name pid,jmap -heap pid
# 如果是大项目修改xms和xmx的值,越大越好,设置jdk编码为utf8解决打印中文,或者拉取nacos配置文件的时候出现乱码问题
# 国产机器上加xms配置有可能会造成服务启动失败
ENTRYPOINT ["java","-server","-Xms1024M","-Xmx1024M","-Dfile.encoding=UTF-8","-Duser.timezone=GMT+08","-jar","$SERVICE_NAME.jar","--Dspring.config.location=config/*"]
# ENTRYPOINT ["java","-Dfile.encoding=UTF-8","-Duser.timezone=GMT+08","-jar","$SERVICE_NAME.jar","--Dspring.config.location=config/*"]
EOF
}

createDockerIgnore() {
  cat >./.dockerignore <<EOF
log?
back
EOF
}
createConfLogs() {
  #如果文件夹不存在，则创建文件夹
  if [ ! -d "$bootpath/config" ]; then
    mkdir config
    echo -e "${GREEN} 创建config文件夹成功!${RES}"
  fi
  if [ ! -d "$bootpath/logs" ]; then
    mkdir logs
    echo -e "${GREEN} 创建logs文件夹成功!${RES}"
  fi
  if [ ! -d "$bootpath/back" ]; then
    mkdir back
    echo -e "${GREEN} 创建back文件夹成功!${RES}"
  fi

  #如果文件不存在，则创建文件
  if [ ! -f "$bootpath/Dockerfile" ]; then
    echo -e "${GREEN} 创建DockerFile文件成功!${RES}"
    createDockerfile
  fi
  if [ ! -f "$bootpath/.dockerignore" ]; then
    createDockerIgnore
  fi
}
init() {
  createConfLogs
  jarNum=$(ls -l | grep ".jar" | wc -l)
  if [ $jarNum -ne 1 ]; then
    echo -e "${RED} "$bootpath 文件夹下jar包数量不等于1,退出脚本!"${RES}"
    exit 0
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

# 运行镜像
# 默认单实例 运行1个
runImage() {
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    # 强制删除已存在的容器
    docker container rm -f $name >>/dev/null 2>&1
    echo "❌删除容器>>>>>>>>>>>>>>>>>>>>>>: $name"
  done
  rmPortLogs
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    port=$(($HOST_PORT + $i))
    # 强制删除已存在的容器
    docker container rm -f $name >>/dev/null 2>&1
    #    echo "创建容器是:$name:$IP:$port:$OPEN_PORT"
    echo -e $GREEN"📦创建容器是:>>>>>>>>>>>>>>>>>>>>>>: $name" $RES
    # 只挂载logs日志文件配置文件不挂载
    docker run \
      --name "$name" \
      --network host \
      -v "$configpath":/code/config \
      -v "$logspath":/code/"$LOG_PATH" \
      --restart=always \
      --log-opt max-size=100m --log-opt max-file=10 \
      -d "$SERVICE_NAME":"$DATEVERSION"
    # -m 2G --memory-reservation 1.5G \ 取消内存限制
    # --privileged=true \ 默认是普通用户 使用root权限
    # -m 300M --memory-reservation 200M \ 要配合jvm同时进行限制,docker 不要限制太低,容易崩,重启....
    # --log-opt max-size=100m --log-opt max-file=10 \ 单log文件最大100m,最多保存10个,docker低版本有问题,一定要限制,要不然磁盘占用太大,docker版本如果低的话可能会不支持此命令
    #--restart=on-failure:10 \
    CONTAINERID_NEW=$(docker container ps -a | grep "${name}" | awk '{print $NF}')
    echo -e 📦已创建容器: $PINK"$CONTAINERID_NEW"$RES
    if [ $i -lt $INSTANCES ]; then
      sleep 1
    fi
  done
  #  docker container ps
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
  # docker container ps
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
  # docker container ps
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
  # docker container ps
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
sendMail() {
  # 有的服务器可能因为库的原因发送不了邮件
  # 当前功能没什么用,废弃了
  echo 发送邮件通知
  echo '{"data":"版本:'$DATEVERSION'IP:'$IP'","dizi":"nuo010@126.com","title":"服务部署通知:'$SERVICE_NAME'"}'
  curl 'https://elel.fun/fastjson/sendMail' -H "Content-Type:application/json" -H 'Authorization:bearer' -X POST -d '{"data":"版本:'$DATEVERSION'----IP:'$IP'","dizi":"nuo010@126.com","title":"服务部署通知:'$SERVICE_NAME'"}'
}

var() {
  echo IP "$IP"
  echo 服务名称 "$SERVICE_NAME"
  echo 服务文件 "${bootpath}/${SERVICE_PATH}"
  echo 实例数量 $INSTANCES
  #  echo docker容器端口 $OPEN_PORT
  #  echo docker主机端口 $HOST_PORT
  echo -e docker网络映射规则 $GREEN --network host $RES
  echo -e docker基础镜像版本 $GREEN$JDK_NAME:$JDK_VERSION$RES
  echo docker镜像版本 "$DATEVERSION"
  echo -e 宿主机javaJDK "${GREEN}$JAVA_PATH${RES}"
  echo -e deploy版本 "${GREEN}$version${RES}"
  echo configpath "$configpath"
  echo logspath "$logspath"
  #  echo 默认查看log文件 "$LOG_FILENAME"
  echo -e "${GREEN}当前工作目录:${bootpath}${RES}"
  echo -e "当前脚本说明:" $PINK $INSTRUCTIONS $RES
  echo
  echo
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
getJarPid() {
  #  pid=$(ps -ef | grep -w "$SERVICE_PATH" | grep -v grep | awk '{print $2}' | head -n 1)
  pid=$(ps -ef | grep -w "$SERVICE_PATH" | grep -v grep | awk '{print $2}')
  # shellcheck disable=SC2206
  array=(${pid//\n/ })
  #  echo ${#array[*]}
  if [ ${#array[*]} -gt 1 ]; then
    echo "重名jar"
  else
    echo "$pid"
  fi
}
isPid() {
  echo "************** 查找进程($SERVICE_PATH) ****************"
  ps -ef | grep -w "$SERVICE_PATH" | grep -v grep
  pid=$(getJarPid)
  #  echo "ispid:"$pid
  echo "${bootpath}/${SERVICE_PATH} 进程id: $pid"
  if [ -n "$pid" ]; then
    if [ "重名jar" == "$pid" ]; then
      echo -e "$RED存在重名jar包,请手动处理!$RES"
      exit 1
    fi
    echo "检测进程Pid不为空:" $pid
    kill -15 "$pid"
    for ((i = 1; i < 20; i++)); do
      pid=$(getJarPid)
      echo "等待 $SERVICE_PATH 资源关闭,等待次数:$i/20,Pid: $pid"
      sleep 1
      if [ -z "$pid" ]; then
        echo -e "\033[31mkill -15 $pid 成功!\033[0m"
        break
      fi
    done
    sleep 1
    # 进程还存在的话......强制关闭tmd
    pid=$(getJarPid)
    if [ -n "$pid" ]; then
      kill -9 "$pid"
      for ((i = 1; i < 10; i++)); do
        pid=$(getJarPid)
        echo "强制关闭,等待进程结束 $SERVICE_PATH ,等待次数:$i/10,Pid: $pid"
        sleep 1
        if [ -z "$pid" ]; then
          echo -e "\033[31mkill -9 $pid 成功!\033[0m"
          break
        fi
      done
    fi
    pid=$(getJarPid)
    # 进程还存在的话......手动处理吧... kill -9 都关闭不掉,就给父进程有关系了
    if [ -n "$pid" ]; then
      echo -e "\033[31m手动处理吧!...... \033[0m"
    fi
  else
    echo -e "$RED进程不存在!$RES"
  fi
  echo "************** 关闭进程完毕 ****************"
}
runjar() {
  echo "************** 开始运行jar ****************"
  pid=$(nohup ${JAVA_PATH} -jar ${bootpath}/${SERVICE_PATH} --Dspring.config.location="${bootpath}"/config/* >/dev/null 2>&1 &)
  echo -e "$GREEN${bootpath}/${SERVICE_PATH}$RES"
  echo "************** 运行完成 ****************"
}
# 部署方式为后台运行jar时使用此方法
backjar() {
  echo "📦************** 开始备份jar ****************"
  cp "${SERVICE_NAME}.jar" back/"${DATEVERSION}".jar
  echo -e "$GREEN备份路径:back/${DATEVERSION}.jar $RES"
  echo "📦************** 备份完成 ****************"
}
rmjar() {
  echo "❌************** 开始删除多余备份 ****************"
  #显示文件数， *.*可以改为指定文件类型
  cd "$backpath" || exit
  FileNum=$(ls -l *.jar | wc -l)
  while (($FileNum > $ReservedJarNum)); do
    #取最旧的文件，*.*可以改为指定文件类型
    OldFile=$(ls -rt *.jar | head -1)
    echo -e "$RED清理过时备份文件:$backpath/$OldFile $RES"
    rm -f $backpath'/'$OldFile
    let "FileNum--"
  done
  cd "$bootpath" || exit
  echo "❌************** 删除完成默认保留:$ReservedJarNum 个 ****************"
}

functionItems() {
  echo
  echo
  echo
  echo
  echo
  echo -e "$GREEN = 0. 🚀部署单个docker容器 $RES"
  echo -e "$BLUE = 1. 🔄重启 $SERVICE_NAME ($INSTANCES)容器(重新加载config下配置文件) $RES"
  echo -e "$BLUE = 2. 🟢启动容器 $SERVICE_NAME ($INSTANCES)容器 $RES"
  echo -e "$RED = 3. 🛑停止容器 $SERVICE_NAME ($INSTANCES)容器 $RES"
  echo -e "$YELLOW = 4. 📝查看 $SERVICE_NAME ($INSTANCES)容器 日志(-f) $RES"
  echo -e "$BLUE = 5. ❌全部删除容器 $SERVICE_NAME ($INSTANCES)容器 $RES"
  echo -e "$YELLOW = 6. 🧱在当前目录创建 Dockerfile,dockerIgnore文件config,logs,back文件夹  $RES"
  echo -e "$GREEN = 7. 🟢后台部署jar ${bootpath}/${SERVICE_PATH} $RES"
  echo -e "$BLUE = 8. 📦备份${SERVER_ALL_PATH}到当前back文件夹下 $RES"
  echo -e "$RED = 9. 🛑结束后台jar包 ${bootpath}/${SERVICE_PATH}  $RES"

  echo
}
upgrade() {
  init
  backjar
  rmjar
  deleteServerNameAllImage
  #echo -e "${GREEN}❌删除容器成功${RES}"
  #deleteOldAllImage
  #echo -e "${GREEN}📦备份镜像成功${RES}"
  buildImage
  echo -e "${GREEN}📦打包镜像成功${SERVICE_NAME}${RES}"
  #isPort 不需要检查端口
  runImage
  echo -e "${GREEN} 🚀运行镜像成功 🚀${RES}"
}
runjars() {
  init
  isPid
  #isPort #访问和项目端口可能不一样不检测端口
  # 运行前先备份
  rmjar
  backjar
  runjar
  sleep 2
  echo "************** 进程详情 **************"
  ps -ef | grep -w "$SERVICE_PATH" | grep -v grep
  pid=$(getJarPid)
  echo -e "${RED}Pid:$pid${RES}"
  echo "************** 后台启动jar完成！**************"
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
    createDockerfile
    createDockerIgnore
    echo -e "${GREEN}Dockerfile 创建成功,默认基于 $JDK_NAME:$JDK_VERSION $RES"
    cat Dockerfile
    echo -e "${GREEN}dockerIgnore 创建成功$RES"
    cat .dockerignore
    createConfLogs
    echo -e "${GREEN}创建config、logs、back 文件夹成功$RES"
    ;;
  7)
    runjars
    ;;
  8)
    backjar
    ;;
  9)
    isPid
    ps -ef | grep -w "$SERVICE_PATH" | grep -v grep
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
if [ $AUTOMATIC = true ] || [ "$1" == "devops" ]; then
  # 判断是jar还是docker
  if [ "docker" == $DEVOPSMODE ]; then
    upgrade
  else
    runjars
  fi
  if [ $SENDMAIL = true ]; then
    sendMail
  fi
else
  while true; do
    main
    sleep 1
  done
fi
