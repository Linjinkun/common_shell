#!/bin/bash
set -e

VERSION=redis-6.2.5
SERVER_DIR=/data/server
PASSWORD=
INSTALL_DIR=${SERVER_DIR}/${VERSION}

# 创建工作目录
if [ -d "$INSTALL_DIR" ]; then
    echo "目录存在，删除中..."
    rm -fr "$directory"
    echo "目录已删除"
fi


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
    
    echo  "开始执行..."
    
    yum  -y install gcc jemalloc-devel || { color "安装软件包失败，请检查网络配置" 1 ; exit; }
    
    mkdir -p $SERVER_DIR && cd $SERVER_DIR
    
    wget http://download.redis.io/releases/${VERSION}.tar.gz || { color "Redis 源码下载失败" 1 ; exit; }
    
    tar -zxvf ${VERSION}.tar.gz
    
    cd ${VERSION}
    
    make -j $(awk '/processor/{i++}END{print i}' /proc/cpuinfo) && color "Redis 编译安装完成" 0 || { color "Redis 编译安装失败" 1 ;exit ; }
    
    REDIS_CONFIG=${INSTALL_DIR}/redis.conf
    
    # 备份配置文件
    cp ${REDIS_CONFIG} ${INSTALL_DIR}/redis.conf.bak
    
    # 创建redis 目录
    mkdir -p $INSTALL_DIR/{data,log,run}
    
    sed -i -e "/^dir .*/c dir ${INSTALL_DIR}/data/" ${REDIS_CONFIG}
    sed -i -e "/logfile .*/c logfile ${INSTALL_DIR}/log/redis-6379.log" ${REDIS_CONFIG}
    sed -i -e "/^pidfile .*/c  pidfile ${INSTALL_DIR}/run/redis_6379.pid" ${REDIS_CONFIG}
    sed -i -e "s/^daemonize no/daemonize yes/" ${REDIS_CONFIG}
    if [ -n "$PASSWORD" ]; then
        sed -i -e "/# requirepass/a requirepass $PASSWORD" ${REDIS_CONFIG}
    fi
    
    # sed -i -e "s/bind 127.0.0.1/bind 0.0.0.0/" ${REDIS_CONFIG}  不配置默认只能本地访问
    
    # 创建软链
    REDIS_SOFT_LINK="/usr/bin/redis-cli"
    
    if [ -L "$REDIS_SOFT_LINK" ]; then
        echo "软链接存在，删除中..."
        rm "$REDIS_SOFT_LINK"
        echo "软链接已删除"
    fi
    
    ln -s ${INSTALL_DIR}/src/redis-cli ${REDIS_SOFT_LINK}
    
    if ! id -u redis &> /dev/null; then
        useradd -r -s /sbin/nologin redis
        echo "Redis 用户创建成功"
    fi
    
    chown -R redis:redis $INSTALL_DIR
    chmod -R 700 $INSTALL_DIR
    chmod -x $REDIS_CONFIG
    
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
    
    # 删除服务配置
    rm -fr /usr/lib/systemd/system/redis.service
    
cat > /usr/lib/systemd/system/redis.service <<EOF
[Unit]
#描述
Description=Redis
#在哪个服务之后启动
After=syslog.target network.target remote-fs.target nss-lookup.target

#表示服务信息
[Service]
Type=forking
#注意：需要和redis.conf配置文件中的信息一致
PIDFile=${INSTALL_DIR}/run/redis_6379.pid
#启动服务的命令
#redis-server安装的路径 和 redis.conf配置文件的路径
ExecStart=${INSTALL_DIR}/src/redis-server ${INSTALL_DIR}/redis.conf
#重新加载命令
ExecReload=/bin/kill -s HUP \$MAINPID
#停止服务的命令
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

#安装相关信息
[Install]
#以哪种方式启动
WantedBy=multi-user.target
#multi-user.target表明当系统以多用户方式（默认的运行级别）启动时，这个服务需要被自动运行。

EOF
    rm -fr ${SERVER_DIR}/${VERSION}.tar.gz && color "Redis 压缩包删除成功"  0
    
    # 检查Redis进程是否正在运行
    if pgrep redis-server > /dev/null; then
        # 获取Redis进程的PID
        redis_pid=$(pgrep redis-server)
        
        # 终止Redis进程
        kill $redis_pid
        
        echo "已关闭Redis进程（PID: $redis_pid）"
    fi
    
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