# docker 安装mysql 8.4.0 并挂载数据卷到宿主机
# 李广龙

# 会在DATAPATH目录下创建mysql文件夹 并在内部放其配置文件
# 端口不要与 已有的容器端口冲突 包括停止的

DATAPATH="/data"
PORT="3306"
PASSWORD="123456"
SERVICE_NAME="mysql8"
MYSQL_VERSION="8.4.0"

creatStart() {
  docker pull mysql:$MYSQL_VERSION
  mkdir -p "$DATAPATH"/mysql8/data
  start
}

start() {
  # conf.d 文件夹下默认是空的 includedir, 主配置文件是引用这下边的, 主文件是 /etc/mysql/my.cnf 在容器中默认是不存在的
  docker run \
    --name "$SERVICE_NAME" \
    --network host \
    -v "$DATAPATH"/mysql8/data:/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD="$PASSWORD" \
    --restart=always \
    -e TZ=Asia/Shanghai \
    -d mysql:$MYSQL_VERSION \
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_general_ci \
    --lower-case-table-names=1 \
    --default-storage-engine=INNODB \
    --skip-name-resolve \
    --host-cache-size=0 \
    --mysqlx-max-connections=9999 \
    --max-connections=9999 \
    --wait-timeout=1800 \
    --port="$PORT"
  docker ps
  echo "运行成功"
}

read -p '输入功能编号0创建挂载运行 1挂载运行: (任意键退出)' input
echo "输入编号:$input"

case $input in
0)
  creatStart
  ;;
1)
  start
  ;;
*)
  echo -e "${RED}退出sh脚本${RES}"
  exit 0
  ;;
esac








