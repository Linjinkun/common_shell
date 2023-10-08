#!/bin/bash

VERSION=redis-7.0.6
PASSWORD=
INSTALL_DIR=/data/server/redis
SERVER_DIR=/data/server
 
color () {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ] ;then
        ${SETCOLOR_SUCCESS}
        echo -n $"  OK  "
    elif [ $2 = "failure" -o $2 = "1"  ] ;then
        ${SETCOLOR_FAILURE}
        echo -n $"FAILED"
    else
        ${SETCOLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo
}
 
 
install() {
yum  -y install gcc jemalloc-devel || { color "安装软件包失败，请检查网络配置" 1 ; exit; }
 
mkdir -p $SERVER_DIR && cd $SERVER_DIR

wget http://download.redis.io/releases/${VERSION}.tar.gz || { color "Redis 源码下载失败" 1 ; exit; }

tar -zxvf ${VERSION}.tar.gz
cd ${VERSION}
make -j $(awk '/processor/{i++}END{print i}' /proc/cpuinfo) && color "Redis 编译安装完成" 0 || { color "Redis 编译安装失败" 1 ;exit ; }

# 备份配置文件  
cp redis.conf redis.conf.bak

REDIS_CONFIG = ${INSTALL_DIR}/redis.conf
sed -i -e "/# requirepass/a requirepass $PASSWORD" ${REDIS_CONFIG}
sed -i -e "/^dir .*/c dir ${INSTALL_DIR}/data/" ${REDIS_CONFIG}
sed -i -e "/logfile .*/c logfile ${INSTALL_DIR}/log/redis-6379.log" ${REDIS_CONFIG}
sed -i -e "/^pidfile .*/c  pidfile ${INSTALL_DIR}/run/redis_6379.pid" ${REDIS_CONFIG}
sed -i -e "s/^daemonize no/daemonize yes/" ${REDIS_CONFIG}

# sed -i -e "s/bind 127.0.0.1/bind 0.0.0.0/" ${REDIS_CONFIG}  不配置默认只能本地访问

ln -s ${INSTALL_DIR}/src/redis-cli /usr/bin/redis-cli
 
if id redis &> /dev/null ;then
    color "Redis 用户已存在" 1
else
    useradd -r -s /sbin/nologin redis
    color "Redis 用户创建成功" 0
fi
 
chown -R redis:redis ${INSTALL_DIR}
chmod -R 700 ${INSTALL_DIR}
chmod -x REDIS_CONFIG

# cat >> /etc/sysctl.conf <<EOF
# net.core.somaxconn = 1024
# vm.overcommit_memory = 1
# EOF

# 配置不存在就追加
grep -q "net.core.somaxconn = 1024" /etc/sysctl.conf || echo "net.core.somaxconn = 1024" >> /etc/sysctl.conf
grep -q "vm.overcommit_memory = 1" /etc/sysctl.conf || echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf

sysctl -p
 
echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
/etc/rc.d/rc.local
 
cat > /usr/lib/systemd/system/redis.service <<EOF
[Unit]
Description=Redis persistent key-value database
After=network.target
 
[Service]
ExecStart=${INSTALL_DIR}/src/redis-server ${INSTALL_DIR}/redis.conf --supervised systemd
ExecStop=/bin/kill -s QUIT \$MAINPID
#Type=notify
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=0755
 
[Install]
WantedBy=multi-user.target
 
EOF
systemctl daemon-reload
systemctl enable --now  redis &> /dev/null && color "Redis 服务启动成功,Redis信息如下:"  0 || { color "Redis 启动失败" 1 ;exit; }
sleep 2

if [ -z "$PASSWORD" ]; then
    redis-cli -a INFO Server 2> /dev/null
else
   redis-cli -a $PASSWORD INFO Server 2> /dev/null
fi
 
}

install