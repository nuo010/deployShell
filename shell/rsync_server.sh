# 李广龙 2022-02-24
# rsync客户端脚本
# 备份和被备份的机器都要安装rsync 默认端口873
# 该脚本只运行一次可以
# 需要linux 机器安装rsync 不是docker方式
# 该脚本只是 创建自定义配置文件
# 一般linux默认安装rsync
# 记得开放873端口
echo -e "========================开始创建rsync备份脚本!"$(date +'%Y-%m-%d %T')"============================"

# user,password是rsync进行通信时的身份验证
# rsync登陆用户
user="rsync"
# rsync用户密码
password="rsyncPwd123"
# 可以连接的的机器,* 代表所有机器可以连接
ip="*"
# 备份别名,对应配置文件中的备份模块,一个模块配置一个备份路径,如果想要备份多个不同路径,可以写多个模块
# 同时客户端进行拉取文件时也需要用到该备份模块名称
model="bf1"
# 要备份文件夹
backdir="/data/mysqlback/real/"



cat > /etc/rsyncd.conf << EOF
# vim /etc/rsyncd.conf
# #全局值
pid file=/var/lock/subsys/rsync.pid
lock file=/var/lock/subsys/rsync.lock
# 指定rsync进程以什么用户身份在后台运行
uid=root
# 服务运行的用户组
gid=root
# 同步传输前是否切换到指定目录下（用于增强传输的安全性）
use chroot = no
# 指定rsync进程的pid文件的路径和名称
pid file = /var/lock/rsync.pid
lock file = /var/lock/rsync.lock
log file=/var/log/rsync.log
# 最大连接数
max connections = 100
timeout = 100




# 模块名
[$model]
# 当前模块备份路径
path=$backdir
# 只读文件是否同步，yes表示无法同步只读文件
read only=no
# 客户端请求显示模块列表是，是否显示该模块
list=yes
# 进行验证的用户，即客户端进行传输时的用户
auth users=$user
# 指定该用户名的密码
secrets file=/etc/rsyncd.passwd
# 可以连接备份的ip
hosts allow=$ip


EOF
# 设置模块密码
echo "$user:$password" > /etc/rsyncd.passwd
chmod 600 /etc/rsyncd.passwd
# 启动rsync 会寻找默认配置文件 /etc/rsyncd.passwd
rsync --daemon
netstat -luntp
# 修改配置文件请先kill rsync进程
echo -e "========================创建完成!"$(date +'%Y-%m-%d %T')"============================\n\n"