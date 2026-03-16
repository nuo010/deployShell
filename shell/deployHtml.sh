#!/bin/bash
# 李广龙
# 脚本说明:
# 首次使用先使用命令5创建容器名称文件,改文件名称文件就是用来当做docker打包后的容器名称默认 init_html 如有多个前端项目,需要修改init就可以,不要有特殊字符和大写字母
# 其他说明文件都在nginx.conf中,请查看该文件
# 前端打包后的文件放入到dist文件夹内
# 使用脚本后,在linux主机查询进程的时候会出现多个nginx进程,例如:master process nginx -g daemon off


# 自定义简介说明
INSTRUCTIONS="脚本说明"
# author: 李广龙
# email: nuo010@126.com
version=v2.3
#################################################################
# 更新计划

##################################################################
# 2.3
# 优化缓存策略
# 2.2
# 更新日志
# 2.1
# 优化日志打印
# 优化缓存配置
# 2.0
# 添加nginx端口配置
# 添加自动根据文件夹名称生成文件名
# 添加空文件夹自动选择最后一次更新逻辑
# 1.8
# 添加nginx配置文件挂载,优化配置参数
# 1.5
# 可以在dist下直接放打包后的dist文件,也可以直接上传dist文件夹,也可以放dist压缩包
# 1.4
# 添加可以根据zip包自动解压部署
# 添加dist空文件夹判断
# 1.3
# 添加dist自动清理功能
# 手动启动还是自动启动 (默认手动启动 false) docker 方式
################################################
################################################
#################devOps#########################
################################################
################################################
# 或者执行脚本时添加 devops 参数即可
AUTOMATIC=false
#AUTOMATIC=true

#################################################################
#备份/back/文件夹下的文件保留数量
ReservedJarNum=10
# docker镜像保留数量
ReservedDockerImagesNum=3
INSTANCES=1
#################################################################
# 是否进行邮件通知
SENDMAIL=false
#################################################################
# 存放打包后的文件
DIST_PATH=/dist
# 服务文件备份文件夹
BACK_PATH=/back

#################################################################
NGINX_PORT=13001

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

# 项目名字
SERVICE_NAME=$(ls "${bootpath}"/ | grep "_html")

backpath=$bootpath$BACK_PATH
# 项目使用的nginx配置文件路径

CONFIG_PATH=/nginx.conf

configpath=$bootpath$CONFIG_PATH


# 颜色定义
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\033[1;33m'
BLUE='\E[1;34m'
PINK='\E[1;35m'
RES='\033[0m'


# 创建dockerFile文件,指定nginx镜像版本,如果不指定不同版本的配置文件路径可能不同
createDockerfile() {
  cat >./Dockerfile <<EOF

FROM nginx:1.25.1
ENV TZ=Asia/Shanghai
# RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' >/etc/timezone
COPY $DIST_PATH/  /usr/share/nginx/html/
#COPY $NGINX_PATH/default.conf /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf

EOF
}

createNginxConfig() {
  cat >$bootpath/nginx.conf <<EOF

#Author LiGuangLong
# 这里经常出现没有权限的情况建议使用root
# user  nginx;
user root;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
    multi_accept on;
    accept_mutex on;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format json escape=json

    # 变量要转义

    log_format json '{"dtTime":"\$time_iso8601","clientIp":"\$remote_addr","uri":"\$uri","httpMethod":"\$request_method","requestBodySize":\$request_length,"responseStatus":"\$status","responseSize":\$body_bytes_sent,"requestTime":\$request_time,"serverIp":"\$server_addr","userAgent":"\$http_user_agent","appName":"Nginx"}';
    access_log  /var/log/nginx/access.log  json;

    sendfile        on;
    server_tokens off;
    gzip  on;
    tcp_nodelay    on;
    tcp_nopush     on;
    charset 'utf-8';
    proxy_buffering on;
    keepalive_timeout  120s;
    client_max_body_size 100m;
    client_header_timeout    60s;
    client_body_timeout      60s;
    proxy_connect_timeout     60s;
    proxy_read_timeout      60s;
    proxy_send_timeout      60s;
    proxy_buffer_size 512k;
    proxy_buffers 32 512k;
    proxy_busy_buffers_size 512k;
    proxy_max_temp_file_size 512k;



	# 注意⚠️:如果使用了多个nginx通过proxy_pass进行代理,如果上层没有设置压缩参数,是不生效的,

	# 无条件压缩所有结果数据
	gzip_proxied any;
	# 设置压缩所需要的缓冲区大小
	gzip_buffers 4 16k;
	# 压缩级别1-9,越大压缩率越高,同时消耗cpu资源也越多,建议设置在4左右。
	gzip_comp_level 6;
	# 需要压缩哪些响应类型的资源，缺少的类型自己补。不要加 application/json
	gzip_types text/plain application/javascript application/x-javascript text/javascript text/css application/xml;
	# 配置禁用gzip条件，支持正则。此处表示ie6及以下不启用gzip（因为ie低版本不支持）
	gzip_disable "msie6";
	# 是否添加“Vary: Accept-Encoding”响应头，
	gzip_vary on;
	# 设置gzip压缩针对的HTTP协议版本，没做负载的可以不用
	gzip_http_version 1.1;

	server {
		listen       $NGINX_PORT;
		server_name  localhost;


		# 前搓配置方式一
		# base配置,如果前端添加了前搓,需要修改本文件中location匹配路径与前搓相同 如:location /blog 则访问路径:http://172.30.196.141:13009/blog
		# 前搓配置方式二(建议使用)
		# 如果前端项目使用必须使用80端口访问多个前端项目则,前搓需要在80Nginx中配置前搓,并配置转发 proxy_pass 到本容器端口,本文件中的location不用修改


		# xss 安全配置
    add_header Content-Security-Policy "default-src 'self'";
    add_header X-XSS-Protection "1; mode=block";

		location / {
			# 注意⚠️:如果vue-router使用的是history模式，try_files $uri $uri/ /index.html;  非常重要！！！
			# 如果使用了hash模式，可以省略这个
			# try_files $uri $uri/ /index.html;

			# 完全禁用缓存,如果数据量大的话，可以根据实际情况对该配置调整
			# 使用该配置，每次访问都重新请求服务器获取资源文件
			# add_header Pragma   no-cache;
      # add_header Expires  0;
      # add_header Cache-Control no-cache,no-store,must-revalidate,max-age=0;
      # 完全启用缓存
      add_header Expires  30d;
      add_header Cache-Control public,immutable,max-age=2592000;

			alias   /usr/share/nginx/html/;
		}
    # 有些文件可能识别失败，导致页面打不开
#		location ~* \.(js|css|png|jpg|jpeg|gif|ico|webp|svg)$ {
#        add_header Cache-Control "public, max-age=31536000, immutable";
#    }



		error_page   500 502 503 504 404  = /50x;
        location = /50x {
            add_header Content-Type application/json;
            default_type application/json;
            return 200 '{"msg":"Nginx异常!","code":500,"data":"匹配不到location块!","time":"\$time_iso8601","status":false}';
        }
	}
}


EOF
}

createDockerIgnore() {
  cat >./.dockerignore <<EOF
back
EOF
}
createConfLogs() {
  echo -e "${GREEN} 初始化配置文件!${RES}"
  #如果文件夹不存在，则创建文件夹
  if [ ! -d "$bootpath/nginx.conf" ]; then
    echo -n "请输入Nginx监听端口(默认 13001): "
    read NGINX_PORT
    # 检查userInput是否为空或只包含空格
    if [ -z "$NGINX_PORT" ]; then
        NGINX_PORT=13001
        echo "输入值为空,默认使用 13001 端口"
    else
        echo "Nginx监听端口是: $NGINX_PORT"
    fi
    createNginxConfig
    echo -e "${GREEN} 创建nginx配置文件成功, 监听端口 $NGINX_PORT !${RES}"
  fi
  if [ ! -d "$bootpath/back" ]; then
    mkdir back
    echo -e "${GREEN} 创建back文件夹成功!${RES}"
  fi
  if [ ! -f "$bootpath/Dockerfile" ]; then
    echo -e "${GREEN} 创建DockerFile文件成功!${RES}"
    createDockerfile
  fi
  if [ ! -f "$bootpath/dist" ]; then
    echo -e "${GREEN} 创建dist文件夹成功!${RES}"
    mkdir dist
  fi
  if [ ! -f "$bootpath/.dockerignore" ]; then
    createDockerIgnore
  fi
}
init() {
  if [ ${#SERVICE_NAME} == 0 ]; then
    echo -e "$RED 请先使用命令5创建容器名称文件 $RES"
    echo -e "$RED 创建成功后退出脚本并重新运行 $RES"
    exit 0
  fi
}

creatNameFile(){
    # 使用basename获取最后一个目录名
    dirname=$(basename "$bootpath")
    # 将目录名转换为小写（Bash内置功能）
    dirname_lowercase="${dirname,,}"
    # 构造新文件名（这里只是一个示例，你可能需要不同的逻辑）
    # 假设我们想要文件名是 "vuepress_" 加上最后一个目录名再加上 "_html"
    filename="${dirname_lowercase}_html"
    # 构造文件的完整路径
    filepath="$bootpath/$filename"
    # touch $bootpath/init_html
    touch $filepath
    echo -e "${GREEN} 创建名称文件成功!${RES}"
    echo -e "名称文件: ${filepath}"
    # echo -e "${RED} 第一次创建请修改init_html文件名,该文件对应创建的docker容器名称!!!!!!!!!!!!!!!!${RES}"
    exit 0
}

deleteServerNameAllImage() {
  echo -e "${RED}删除${SERVICE_NAME}镜像,只保留最新的${ReservedDockerImagesNum}个${RES}"
  echo -e "${RED}版本不同镜像id相同的需要手动进行删除${RES}"
  arr=$(docker images --no-trunc | grep "${SERVICE_NAME}" | tr -s ' ' | cut -d ' ' -f 3 | cut -d ':' -f 2)
  array=(${arr//\n/ })
  echo -e "${RED}当前备份镜像数量:${#array[*]}${RES}"
  if [ ${#array[*]} -gt ${ReservedDockerImagesNum} ]; then
    docker rmi -f $(docker images --no-trunc | grep "${SERVICE_NAME}" | tail -n +${ReservedDockerImagesNum} | tr -s ' ' | cut -d ' ' -f 3 | cut -d ':' -f 2)
  fi
}
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

buildImage() {
  docker build -t $SERVICE_NAME:$DATEVERSION .
}

runImage() {
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    docker container rm -f $name >>/dev/null 2>&1
    echo "删除容器>>>>>>>>>>>>>>>>>>>>>>: $name"
  done
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    port=$(($HOST_PORT + $i))
    # 强制删除已存在的容器
    docker container rm -f $name >>/dev/null 2>&1
    #    echo "创建容器是:$name:$IP:$port:$OPEN_PORT"
    echo -e $GREEN"创建容器是:>>>>>>>>>>>>>>>>>>>>>>: $name" $RES
    # 只挂载logs日志文件配置文件不挂载
    docker run \
      --name "$name" \
      --network host \
      -v "$configpath":/etc/nginx/nginx.conf \
      --restart=always \
      --log-opt max-size=100m --log-opt max-file=10 \
      -d "$SERVICE_NAME":"$DATEVERSION"
    CONTAINERID_NEW=$(docker container ps -a | grep "${name}" | awk '{print $NF}')
    echo -e 已创建容器: $PINK"$CONTAINERID_NEW"$RES
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
    echo 重启容器 $name
    if [ $i -lt $INSTANCES ]; then
      sleep 1
    fi
  done
  docker container ps
}
stopContainer() {
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    port=$(($HOST_PORT + $i))
    docker container stop $name >>/dev/null 2>&1
    echo 停止容器: $name
    if [ $i -lt $INSTANCES ]; then
      sleep 1
    fi
  done
  docker container ps
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
rmContainer() {
  for ((i = 0; i < $INSTANCES; i++)); do
    name=$SERVICE_NAME-$i
    port=$(($HOST_PORT + $i))
    docker container rm $name >>/dev/null 2>&1
    echo 删除容器: $name
    if [ $i -lt $INSTANCES ]; then
      sleep 1
    fi
  done
  docker container ps
}


current() {
  echo
  echo -e "${PINK}当前时间:$(date +'%Y-%m-%d %T')${RES}"
  echo
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
  echo 服务文件 "${bootpath}"$DIST_PATH
  echo -e docker网络映射规则 $GREEN --network host $RES
  echo 服务镜像版本 "$DATEVERSION"
  echo -e deploy版本 "${GREEN}$version${RES}"
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

backHtml() {
  echo "************** 开始备份文件 ****************"
  cd "${bootpath}" || exit
  cp -r "${bootpath}"/dist back/"${DATEVERSION}"/
  echo -e "$GREEN备份路径:back/${DATEVERSION} $RES"
  echo "************** 备份完成 ****************"
}
rmHtml() {
  echo "************** 开始删除多余备份 ****************"
  cd "$bootpath"$BACK_PATH || exit
  Num=$(ls -l |grep "^d"|wc -l)
  while(( $Num > $ReservedJarNum ))
  do
    OldFile=$(ls -l -t -r | tail -n +2 | head -1 | awk '{print $9}')
    echo -e "清理过时备份文件夹: ""$bootpath"$BACK_PATH/${OldFile}
    rm -rf "$bootpath$BACK_PATH"/${OldFile}
    let "Num--"
  done
  cd $bootpath || exit
  echo "************** 删除完成默认保留:$ReservedJarNum 个 ****************"
}
rmDist() {
  echo "************** 清理dist文件夹 ****************"
  cd "$bootpath"$DIST_PATH || exit
  echo -e "清理dist文件夹: ""$bootpath"$DIST_PATH
  rm -rf "$bootpath$DIST_PATH"/*
  cd $bootpath || exit
  echo "************** 清理dist文件夹成功  ****************"
}
emptyDir() {
  if [ "`ls -A ${bootpath}${DIST_PATH}/`" = "" ]; then
   echo "${bootpath}${DIST_PATH}/ 是空文件夹,选择最后一次部署版本开始部署...."
   latest_folder=$(basename "$(ls -dt "${bootpath}${BACK_PATH}"/*/ | head -n 1)")
   # 检查选择的文件夹是否存在
   if [ ! -d "${bootpath}${BACK_PATH}/${latest_folder}" ]; then
     echo "错误：无法找到或确定最新的文件夹。"
     exit 0;
   fi
   # 拷贝文件
   echo "正在将 ${bootpath}${BACK_PATH}/${latest_folder} 的内容拷贝到 ${bootpath}${DIST_PATH} ..."
   cp -r "${bootpath}${BACK_PATH}/${latest_folder}/"* "${bootpath}${DIST_PATH}/"
  fi
}
judgeZip() {
  cd "${bootpath}"${DIST_PATH} || exit
  zipNum=$(ls -l |grep ".zip"|wc -l)
  if [ "$zipNum" -eq 1 ];then
      echo "$bootpath$DIST_PATH 文件夹下存在zip包,开始使用zip包进行部署!"
      # shellcheck disable=SC2035
      unzip "${bootpath}"${DIST_PATH}/*.zip
      rm -rf "${bootpath}"${DIST_PATH}/*.zip
  fi
  # -d 参数判断 dist文件夹 是否存在
  if [ -d "${bootpath}${DIST_PATH}/dist/" ]; then
    echo "$bootpath$DIST_PATH 文件夹下存在dist子包,开始进行文件转移!"
    mv "${bootpath}"${DIST_PATH}/dist/* "${bootpath}"${DIST_PATH}/
    rm -rf "${bootpath}"${DIST_PATH}/dist
  fi
}
functionItems() {
  echo
  echo -e "$GREEN = 0. 部署单个docker容器 $RES"
  echo -e "$BLUE = 1. 重启 容器 $SERVICE_NAME ($INSTANCES)容器 $RES"
  echo -e "$RED = 2. 停止容器 $SERVICE_NAME ($INSTANCES)容器 $RES"
  echo -e "$BLUE = 3. 全部删除容器 $SERVICE_NAME ($INSTANCES)容器 $RES"
  echo -e "$YELLOW = 4. 查看 $SERVICE_NAME ($INSTANCES)容器 日志(-f) $RES"
  echo -e "$YELLOW = 5. 创建容器名称文件(服务名称为空的情况下创建) $RES"
  echo
}
upgrade() {
  init
  emptyDir
  judgeZip
  backHtml
  rmHtml
  deleteServerNameAllImage
  echo -e "${GREEN}删除容器成功${RES}"
  echo -e "${GREEN}备份镜像成功${RES}"
  buildImage
  echo -e "${GREEN}打包镜像成功${SERVICE_NAME}${RES}"
  runImage
  echo -e "${GREEN}运行镜像成功${RES}"
  rmDist
}

# shellcheck disable=SC2120
main() {
  functionItems
  read -p '输入功能编号: (任意键退出)' input
  echo "输入编号:$input"
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>开始执行!!!"
  case $input in
  0)
    upgrade
    ;;
  1)
    restartContainer
    echo -e "${GREEN}重启容器:${SERVICE_NAME}${RES}"
    ;;
  2)
    stopContainer
    echo -e "${GREEN}停止容器:${SERVICE_NAME}${RES}"
    ;;
  3)
    rmContainer
    echo -e "${GREEN}删除容器:${SERVICE_NAME}${RES}"
    ;;
  4)
    dockerLogs
    ;;
  5)
    createConfLogs
    creatNameFile
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
#当前时间
current
#变量值
var

# 判断是自动部署还是手动部署
if [ $AUTOMATIC = true ] || [ "$1" == "devops" ]; then
  upgrade
  if [ $SENDMAIL = true ]; then
    sendMail
  fi
else
  while true; do
    main
    sleep 1
  done
fi
