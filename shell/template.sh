# 李广龙
# 服务器sh脚本
# 0.40 版本
echo frps版本:0.40

SERVICE_PATH="/data/frp"
SERVICE_NAME="DOCKER NAME"

creatConfig() {
mkdir -p $SERVICE_PATH
cd $SERVICE_PATH || exit
cat >./frps.ini <<EOF
配置文件
EOF
}
creatStart() {
  creatConfig
  start
}

start() {
  docker run .............................
  docker ps -a | grep "$SERVICE_NAME"
  echo "$SERVICE_NAME""运行成功！"
  echo "完成！"
}

read -p '输入功能编号 0:创建挂载运行 1:挂载运行: (任意键退出)' input
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

