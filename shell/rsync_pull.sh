# 李广龙 2022-02-24
# 用来设置备份机器的脚本
# 异地存放机器要手动安装rsync
# 一般linux默认自带rsync
# 要把当前脚本加入linux定时任务中




# server端配置文件中设置的用户名和密码
# 当前密码部署linux机器的登陆密码,仅仅是rsync的密码
user="lgl"
password="123456"
# server要备份机器ip
ip="121.43.149.217"
# server定义的备份模板
model="bf1"
# 当前机器存放server要备份的文件
backdir="/root/rsyncfile"
# 要保留的备份天数 #
backup_day=10


test ! -d ${backdir} && mkdir -p ${backdir}

creat_password(){
  # 只在第一次运行的时候 创建一次密码就可以
  echo $password > /etc/rsyncd.passwd
  chmod 600 /etc/rsyncd.passwd
}
back(){
  # 客户机设置备份用户名 ip 备份模块名 存放文件夹 指定密码
  rsync -avz $user@$ip::$model $backdir --password-file=/etc/rsyncd.passwd
}
delete_old_backup(){
    # 删除旧的备份 查找出当前目录下七天前生成的文件，并将之删除
    find ${backdir} -type f -mtime +${backup_day} | tee delete_list.log | xargs rm -rf

}
# 备份机器 只创建一次密码就可以
creat_password
back
delete_old_backup