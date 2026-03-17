# docker 安装mysql5.7 并挂载数据卷到宿主机
# 李广龙
# 5.7.44 mysql5.7.x的最终版本
# 会在DATAPATH目录下创建mysql文件夹 并在内部放其配置文件
# 端口不要与 已有的容器端口冲突 包括停止的
DATAPATH="/data"
PORT="3306"
PASSWORD="mysqlPwd@123!"
SERVICE_NAME="mysql"

creatStart() {
  mkdir -p "$DATAPATH"/mysql/conf && mkdir -p "$DATAPATH"/mysql/data && mkdir -p "$DATAPATH"/mysql/logs && mkdir -p "$DATAPATH"/mysql/logs/binlog
  cd "$DATAPATH"/mysql/conf || exit
  creatMycnf
  start
}
creatMycnf() {
  cat >./my.cnf <<EOF
[mysqld]
pid-file        = /var/run/mysqld/mysqld.pid
socket          = /var/run/mysqld/mysqld.sock

# mysql的数据目录
datadir         = /var/lib/mysql
# mysql 表名大小写转换,有的框架会生成表,如果表名大写,这个字段设置的是1实际存储在磁盘上的表名是小写,每次查询的时候会进行转换,会影响一些性能
# lower_case_table_names=0 表名存储为给定的大小和比较是区分大小写的
# lower_case_table_names = 1 表名存储在磁盘是小写的，但是比较的时候是不区分大小写
# lower_case_table_names=2 表名存储为给定的大小写但是比较的时候是小写的
lower_case_table_names=1
#log-error      = /var/log/mysql/error.log
# 错误日志
log-error = /logs/error.log
# By default we only accept connections from localhost
# mysql监听的ip地址，如果是127.0.0.1，表示仅本机访问
#bind-address   = 127.0.0.1
# Disabling symbolic-links is recommended to prevent assorted security risks
# 是否支持符号链接，即数据库或表可以存储在my.cnf中指定datadir之外的分区或目录，为0不开启
symbolic-links=0

# mysql调优=======================================
# 在MySQL暂时停止回答新请求之前的短时间内多少个请求可以被存在堆栈中。
# 当MySql的连接数据达到max_connections时，新来的请求将会被存在堆栈中，以等待某一连接释放资源，该堆栈的数量即back_log。
# 如果等待连接的数量超过back_log，将不被授予连接资源。
back_log=500

# 端口
port=${PORT}

# 编码字符集
collation_server = utf8mb4_general_ci
character_set_server = utf8mb4

# 针对某一个账号的所有客户端并行连接到MYSQL服务的最大并行连接数。简单说是指同一个账号能够同时连接到mysql服务的最大连接数（设置为0表示不限制）。
# 目前默认值为：0不受限制。
# max_user_connections=800

# 设置默认引擎
default-storage-engine=INNODB

# 禁止 MySQL 在验证客户端连接时解析主机名。
# 默认行为 MySQL 会把客户端 IP 地址解析成主机名，然后再匹配权限表（mysql.user）中的 Host 列。
# 但是用户表里 Host 列必须用 IP 或 %，不能用主机名。
skip-name-resolve
# 禁用主机名缓存
skip-host-cache

# 服务器关闭交互式连接前等待活动的秒数。交互式客户端定义为在mysql_real_connect()中使用CLIENT_INTERACTIVE选项的客户端,如navicat
interactive_timeout=1800

# 非交互,如jdbc,在线程启动时，根据全局wait_timeout值或全局interactive_timeout值初始化会话wait_timeout值，取决于客户端类型(由mysql_real_connect()的连接选项CLIENT_INTERACTIVE定义)
wait_timeout=1800


# MySql的最大连接数，如果服务器的并发连接请求量比较大，建议调高此值，以增加并行连接数量，当然这建立在机器能支撑的情况下，因为如果连接数越多，介于MySql会为每个连接提供连接缓冲区，就会开销越多的内存，所以要适当调整该值，不能盲目提高设值。可以过'conn%'通配符查看当前状态的连接数量，以定夺该值的大小。
# MySQL服务器允许的最大连接数16384；查看系统当前最大连接数：>>> show variables like 'max_connections';
max_connections=5000

# 某台host连接错误次数等于max_connect_errors（默认10） ，主机'host_name'再次尝试时被屏蔽。可有效反的防止dos攻击
max_connect_errors = 1000

# thread_concurrency的值的正确与否, 对mysql的性能影响很大。在多个cpu(或多核)的情况下，错误设置了thread_concurrency的值, 会导致mysql不能充分利用多cpu(或多核), 出现同一时刻只能一个cpu(或核)在工作的情况。
# thread_concurrency应设为CPU核数的2倍.1.若Server为一个双核的CPU, thread_concurrency  应设置为4;2. 若Server为两个双核的cpu, thread_concurrency应设置为8
# thread_concurrency=64


# 允许的最大数据包（大字段 / 大事务 / mysqldump 必须），最大就是1g，多了不生效
max_allowed_packet = 1G

# 网络读写超时时间（单位：秒）
net_read_timeout = 600
net_write_timeout = 600



# 配置主从需要设置一下参数=======================================
# 开启binlog
server-id = 1        # 节点ID，确保唯一
## log config
# log-bin = mysql-bin     #开启mysql的binlog日志功能
log-bin = /logs/binlog/mysql-bin

#sync_binlog = 1         #控制数据库的binlog刷到磁盘上去 , 0 不控制，性能最好，1每次事物提交都会刷到日志文件中，性能最差，最安全
binlog_format = row   #binlog日志格式，mysql默认采用statement，建议使用row
expire_logs_days = 60                           #binlog过期清理时间
max_binlog_size = 1000m                    #binlog每个日志文件大小
binlog_cache_size = 4m                        #binlog缓存大小
# 如果导入一个很大的sql文件，sql文件的大小不能超过该大小，否则会报错
max_binlog_cache_size= 4096m              #最大binlog缓存大
#binlog-ignore-db=mysql #不生成日志文件的数据库，多个忽略数据库可以用逗号拼接，或者 复制这句话，写多行
#
#auto-increment-offset = 1     # 自增值的偏移量
#auto-increment-increment = 1  # 自增值的自增量
#slave-skip-errors = all #跳过从库错误


# 慢查询日志
slow_query_log = 1
slow_query_log_file = /logs/mysql-slow.log
long_query_time = 3
log_queries_not_using_indexes = 1

# 数据库审计，需要企业版，免费版本没有
# audit_log.so
EOF
}

# binlog 开启方式 https://www.utheme.cn/code/mysql/26369.html
# https://blog.csdn.net/bestcxx/article/details/123637918
start() {
  docker run \
    --name "$SERVICE_NAME" \
    --network host \
    -v "$DATAPATH"/mysql/conf:/etc/mysql/conf.d \
    -v "$DATAPATH"/mysql/data:/var/lib/mysql \
    -v "$DATAPATH"/mysql/logs:/logs \
    -e MYSQL_ROOT_PASSWORD="$PASSWORD" \
    --restart=always \
    -e TZ=Asia/Shanghai \
    -d mysql:5.7.44
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
