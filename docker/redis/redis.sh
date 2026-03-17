# 李广龙

# 本地redis配置文件映射
# 数据文件在当前子目录/data下
# 对于redis账号密码主从等多个配置在配置文件中修改
SERVICE_PATH="/data"
SERVICE_NAME="redis"
# redis 版本
REDIS_VERSION="7.2.2"
# 连接密码,必须设置密码
PASSWORD="redisPwd@123!"
# 运行端口
PORT="6379"

# 也可以直接使用以下命令启动redis容器
# docker run --name redis --restart=always -d --network host redis:7.2.2 --requirepass redisPwd@123!




creatConfig() {
mkdir -p $SERVICE_PATH/redis
mkdir -p $SERVICE_PATH/redis/data
cd $SERVICE_PATH/redis || exit
cat >./redis.conf <<EOF
# 2022-1-15
# 李广龙
# 配置说明
# config get  set
# 主从配置 读写分离
# docker network ipaddress
# 进入交互窗口
# redis-cli
# slaveof host port
# slaveof no one
# slaveof host port 命令可以将当前服务器转变为指定服务器的从属服务器(slave server)。
# 如果当前服务器已经是某个主服务器(master server)的从属服务器，那么执行 SLAVEOF host port 将使当前服务器停止对旧主服务器的同步，丢弃旧数据集，转而开始对新主服务器进行同步。
# 另外，对一个从属服务器执行命令 SLAVEOF NO ONE 将使得这个从属服务器关闭复制功能，并从从属服务器转变回主服务器，原来同步所得的数据集不会被丢弃。
# 利用『 SLAVEOF NO ONE 不会丢弃同步所得数据集』这个特性，可以在主服务器失败的时候，将从属服务器用作新的主服务器，从而实现无间断运行。
# 查看当前配置信息
# info replication
#
# 开始启动时必须如下指定配置文件
#
# ./redis-server /path/to/redis.conf

# 存储单位如下所示
#
# 1k => 1000 bytes
# 1kb => 1024 bytes
# 1m => 1000000 bytes
# 1mb => 1024*1024 bytes
# 1g => 1000000000 bytes
# 1gb => 1024*1024*1024 bytes
################################## INCLUDES ###################################
# 如果需要使用多配置文件配置redis，请用include
#
# include /path/to/local.conf
# include /path/to/other.conf
################################## MODULES #####################################
# 手动设置加载模块（当服务无法自动加载时设置）
# loadmodule /path/to/my_module.so
# loadmodule /path/to/other_module.so
################################## NETWORK #####################################
# 设置绑定的ip
# 如果设置127.0.0.1只能本地访问
# bind:绑定redis服务器网卡IP，默认为127.0.0.1,即本地回环地址。这样的话，访问redis服务只能通过本机的客户端连接，而无法通过远程连接。如果bind选项为空的话，那会接受所有来自于可用网络接口的连接
bind * -::*
#################################
# 保护模式：不允许外部网络连接redis服务 开启protected-mode保护模式，需配置bind ip或者设置访问密码,redis7默认为yes
protected-mode no
################################### 常用配置 ####################################
# 设置端口号
port ${PORT}
# 连接密码
requirepass ${PASSWORD}
# daemonize:设置为yes表示指定Redis以守护进程的方式启动（后台启动）。默认值为 no
# 是否守护进程运行（后台运行）
# 非后台模式，如果为YES 会的导致 redis 无法启动，因为后台会导致docker无任务可做而退出
daemonize no
# timeout：设置客户端连接时的超时时间，单位为秒。当客户端在这段时间内没有发出任何指令，那么关闭该连接。默认值为0，表示不关闭。
# 超时时间
timeout 0
# arm 架构需要打开此配置,要不然启动错误
# ignore-warnings ARM64-COW-BUG
###################主从设置 只有从机器才配置
# 当前机器要是主redis的话不用配置 masterauth 信息
# 主redis地址
# slaveof host port
# 主redis密码
# masterauth 123456

################################### 内存淘汰策略 ##################################
# volatile-lru，针对设置了过期时间的key，使用lru算法进行淘汰。
# allkeys-lru，针对所有key使用lru算法进行淘汰。
# volatile-lfu，针对设置了过期时间的key，使用lfu算法进行淘汰。
# allkeys-lfu，针对所有key使用lfu算法进行淘汰。
# volatile-random，从所有设置了过期时间的key中使用随机淘汰的方式进行淘汰。
# allkeys-random，针对所有的key使用随机淘汰机制进行淘汰。
# volatile-ttl，删除生存时间最近的一个键。
# noeviction，不删除键，值返回错误。(默认)
#   根据使用场景,来具体调整淘汰的策略

maxmemory-policy noeviction

################################### 持久化配置 ####################################
# Redis 提供了两种持久化方式，一种是基于快照形式的 RDB，另一种是基于日志形式的 AOF，每种方式都有自己的优缺点。
# RDB 基于内存快照，是 Redis 默认开启的持久化方式，并不需要我们单独开启。

# RDB 有两种持久化方式：手动触发 和 自动触发，手动触发使用以下两个命令：

# save：会阻塞当前 Redis 服务器响应其他命令，直到 RDB 快照生成完成为止，对于内存比较大的实例会造成长时间阻塞，所以线上环境不建议使用

# bgsave：Redis 主进程会 fork 一个子进程，RDB 快照生成有子进程来负责，完成之后，子进程自动结束，bgsave 只会在 fork 子进程的时候短暂的阻塞，这个过程是非常短的，所以推荐使用该命令来手动触发

# 大部分情况，我们会通过配置 时间间隔 触发 RDB 文件写入。
# AOF持久化
# Redis 默认并没有开启 AOF 持久化方式，需要我们自行开启，与 RDB 不同的是 AOF 是以记录操作命令的形式来持久化数据的，我们可以查看以下 AOF 的持久化文件 appendonly.aof

# appendfsync 的配置项有以下三种值可选：
# always：每一次系统 serverCorn 函数调用就刷新一次缓存区
# everysec：每秒执行一次磁盘写入，期间所有的命令都会存储在 aof 缓存区
# no：不做控制，任由操作系统决定什么时候刷新缓冲区
# redis 默认配置是 everysec，即每秒刷新一次缓存区。
# 总的来说，AOF 策略会使数据稳定性更高，具有更完整的数据备份，RDB 恢复效率高适合做灾难恢复，建议生产环境上两者都开启。

# 是否使用AOF持久化方式
# 默认redis使用的是rdb方式持久化，这种方式在许多应用中已经足够用了。但是redis如果中途宕机，会导致可能有几分钟的数据丢失，根据save来策略进行持久化，Append Only File是另一种持久化方式，  可以提供更好的持久化特性。Redis会把每次写入的数据在接收后都写入appendonly.aof文件，每次启动时Redis都会先把这个文件的数据读入内存里，先忽略RDB文件。默认值为no。
# 默认是 no 关闭的
appendonly yes
appendfilename "appendonly.aof"
# 持久化策略
# aof持久化策略的配置；no表示不执行fsync，由操作系统保证数据同步到磁盘，速度最快；always表示每次写入都执行fsync，以保证数据同步到磁盘；everysec表示每秒执行一次fsync，可能会导致丢失这1s数据
appendfsync always
# 在aof重写或者写入rdb文件的时候，会执行大量IO，此时对于everysec和always的aof模式来说，执行fsync会造成阻塞过长时间，no-appendfsync-on-rewrite字段设置为默认设置为no。如果对延迟要求很高的应用，这个字段可以设置为yes，否则还是设置为no，这样对持久化特性来说这是更安全的选择。   设置为yes表示rewrite期间对新写操作不fsync,暂时存在内存中,等rewrite完成后再写入，默认为no，建议yes。Linux的默认fsync策略是30秒。可能丢失30秒数据。默认值为no
no-appendfsync-on-rewrite no
# 默认值为100。aof自动重写配置，当目前aof文件大小超过上一次重写的aof文件大小的百分之多少进行重写，即当aof文件增长到一定大小的时候，Redis能够调用bgrewriteaof对日志文件进行重写。当前AOF文件大小是上次日志重写得到AOF文件大小的二倍（设置为100）时，自动启动新的日志重写过程。
auto-aof-rewrite-percentage 100
# 64mb。设置允许重写的最小aof文件大小，避免了达到约定百分比但尺寸仍然很小的情况还要重写。
auto-aof-rewrite-min-size 64mb
# truncated：aof文件可能在尾部是不完整的，当redis启动的时候，aof文件的数据被载入内存。重启可能发生在redis所在的主机操作系统宕机后，尤其在ext4文件系统没有加上data=ordered选项，出现这种现象  redis宕机或者异常终止不会造成尾部不完整现象，可以选择让redis退出，或者导入尽可能多的数据。如果选择的是yes，当截断的aof文件被导入的时候，会自动发布一个log给客户端然后load。如果是no，用户必须手动redis-check-aof修复AOF文件才可以。默认值为 yes。
##################默认开启的
# 表示900 秒内如果至少有 1 个 key 的值变化，则保存
# 当然如果你只是用Redis的缓存功能，不需要持久化，那么你可以注释掉所有的 save 行来停用保存功能。可以直接一个空字符串来实现停用：save ""
# 持久化操作设置 900秒内触发一次请求进行持久化，300秒内触发10次请求进行持久化操作，60s内触发10000次请求进行持久化操作
save 900 1
save 300 10
save 60 10000
set-proc-title yes
proc-title-template "{title} {listen-addr} {server-mode}"
# 默认值为yes。当启用了RDB且最后一次后台保存数据失败，Redis是否停止接收数据。这会让用户意识到数据没有正确持久化到磁盘上，否则没有人会注意到灾难（disaster）发生了。如果Redis重启了，那么又可以重新开始接收数据了
stop-writes-on-bgsave-error yes
# 默认值是yes。对于存储到磁盘中的快照，可以设置是否进行压缩存储。如果是的话，redis会采用LZF算法进行压缩。如果你不想消耗CPU来进行压缩的话，可以设置为关闭此功能，但是存储在磁盘上的快照会比较大。
rdbcompression yes
# 默认值是yes。在存储快照后，我们还可以让redis使用CRC64算法来进行数据校验，但是这样做会增加大约10%的性能消耗，如果希望获取到最大的性能提升，可以关闭此功能。
# 是否校验rdb文件，更有利于文件的容错性，但是在保存rdb文件的时候，会有大概10%的性能损耗
#rdbchecksum yes
# 设置快照的文件名，默认是 dump.rdb
dbfilename dump.rdb
rdb-del-sync-files no
# 设置快照文件的存放路径，这个配置项一定是个目录，而不能是文件名。使用上面的 dbfilename 作为保存的文件名。
# dbfilename文件的存放位置
dir ./
###########################################################################
## 是否通过upstart和systemd管理Redis守护进程
# supervised auto
# 数据库的个数
databases 16
##############################
# TCP 连接数，此参数确定了TCP连接中已完成队列(完成三次握手之后)的长度
tcp-backlog 511
# 通信协议设置，本机通信使用此协议不适用tcp协议可大大提升性能
#
# unixsocket /run/redis.sock
# unixsocketperm 700
###############################
# tcp-keepalive ：单位是秒，表示将周期性的使用SO_KEEPALIVE检测客户端是否还处于健康状态，避免服务器一直阻塞，官方给出的建议值是300s，如果设置为0，则不会周期性的检测。
# 定期检测cli连接是否存活
tcp-keepalive 300
# pidfile:配置PID文件路径，当redis作为守护进程运行的时候，它会把 pid 默认写到 /var/redis/run/redis_6379.pid 文件里面
# 以后台进程方式运行redis，则需要指定pid 文件
#pidfile /var/run/redis_6379.pid
##############################
# 日志级别
# 可选项有： # debug（记录大量日志信息，适用于开发、测试阶段）； # verbose（较多日志信息）； # notice（适量日志信息，使用于生产环境）；
# warning（仅有部分重要、关键信息才会被记录）。
loglevel notice
# 日志文件的位置
logfile ""
##############################
# 是否显示logo
always-show-logo no
##############################

# 默认值为yes。当一个 slave 与 master 失去联系，或者复制正在进行的时候，slave 可能会有两种表现
# 1) 如果为 yes ，slave 仍然会应答客户端请求，但返回的数据可能是过时，或者数据可能是空的在第一次同步的时候
# 2) 如果为 no ，在你执行除了 info he salveof 之外的其他命令时，slave 都将返回一个 "SYNC with master in progress" 的错误
replica-serve-stale-data yes
# 配置Redis的Slave实例是否接受写操作，即Slave是否为只读Redis。默认值为yes
replica-read-only yes
# 主从数据复制是否使用无硬盘复制功能。默认值为no。
repl-diskless-sync no
# 当启用无硬盘备份，服务器等待一段时间后才会通过套接字向从站传送RDB文件，这个等待时间是可配置的。  这一点很重要，因为一旦传送开始，就不可能再为一个新到达的从站服务。从站则要排队等待下一次RDB传送。因此服务器等待一段  时间以期更多的从站到达。延迟时间以秒为单位，默认为5秒。要关掉这一功能，只需将它设置为0秒，传送会立即启动。默认值为5。
repl-diskless-sync-delay 5
repl-diskless-load disabled
# 同步之后是否禁用从站上的TCP_NODELAY 如果你选择yes，redis会使用较少量的TCP包和带宽向从站发送数据。但这会导致在从站增加一点数据的延时。  Linux内核默认配置情况下最多40毫秒的延时。如果选择no，从站的数据延时不会那么多，但备份需要的带宽相对较多。默认情况下我们将潜在因素优化，但在高负载情况下或者在主从站都跳的情况下，把它切换为yes是个好主意。默认值为no。
repl-disable-tcp-nodelay no
replica-priority 100
acllog-max-len 128
lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no
lazyfree-lazy-user-del no
lazyfree-lazy-user-flush no
oom-score-adj no
oom-score-adj-values 0 200 800
disable-thp yes

aof-load-truncated yes
aof-use-rdb-preamble yes
# 一个lua脚本执行的最大时间，单位为ms。默认值为5000.
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
# redis事件配置,默认空字符串代表没有任何事件配置,如果要监听key过期,改为Ex
# notify-keyspace-events Ex
notify-keyspace-events ""

# K：keyspace 事件，事件以 keyspace@ 为前缀进行发布
# E：keyevent 事件，事件以 keyevent@ 为前缀进行发布
# g：一般性的，非特定类型的命令，比如del，expire，rename等
# $：字符串特定命令
# l：列表特定命令
# s：集合特定命令
# h：哈希特定命令
# z：有序集合特定命令
# x：过期事件，当某个键过期并删除时会产生该事件
# e：驱逐事件，当某个键因 maxmemore 策略而被删除时，产生该事件
# A：g$lshzxe的别名，因此”AKE”意味着所有事件

hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
######################### 定时清理过期的key ######################
# Redis采用惰性删除和定时任务删除机制实现过期键的内存回收
# 定期删除函数的运行频率，在Redis2.6版本中，规定每秒运行10次，大概100ms运行一次。在Redis2.8版本后，可以通过修改配置文件redis.conf 的 hz 选项来调整这个次数
# 建议不要改动
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
jemalloc-bg-thread yes


EOF
}
creatStart() {
  creatConfig
  start
}

start() {
  docker run --network host --name "$SERVICE_NAME" -v "$SERVICE_PATH"/redis/redis.conf:/redis.conf -v "$SERVICE_PATH"/redis/data:/data -itd --restart=always redis:"$REDIS_VERSION" redis-server /redis.conf --appendonly yes
  echo redis启动成功
  docker ps -a | grep $SERVICE_NAME
  echo $SERVICE_NAME"---->运行成功！"
  echo "完成!"
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

