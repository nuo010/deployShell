# docker 安装mysql5.7从库
# 李广龙


DATAPATH="/data/mysqlc1"
PORT="3307"
PASSWORD="123456"


creatStart(){
    mkdir -p "$DATAPATH"/mysql/conf
    cd "$DATAPATH"/mysql/conf || exit
    creatMycnf
    start

}
creatMycnf(){
cat > ./my.cnf << EOF
[mysqld]
server-id = 2
log-bin=mysql-bin
relay-log = mysql-relay-bin
replicate-wild-ignore-table=mysql.%
replicate-wild-ignore-table=test.%
replicate-wild-ignore-table=information_schema.%
EOF
}

start(){
    docker run \
    --name mysqlc1 \
    -p "$PORT":3306 \
    -v "$DATAPATH"/mysql/conf/my.cnf:/etc/mysql/my.cnf \
    -e MYSQL_ROOT_PASSWORD="$PASSWORD" \
    --restart=always \
    -e TZ=Asia/Shanghai \
    -d mysql:5.7
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
