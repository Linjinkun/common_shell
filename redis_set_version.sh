#!/bin/bash

# 提示用户输入 Redis 版本
read -p "请输入您要安装的 Redis 版本: " REDIS_VERSION

# 用户可以修改这些变量来设置自己想要的路径
INSTALL_DIR="/opt/redis"

# 下载并编译 Redis
cd /tmp
wget http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz
tar xvzf redis-${REDIS_VERSION}.tar.gz
cd redis-${REDIS_VERSION}
make

# 将编译好的 Redis 安装到指定目录
mkdir -p ${INSTALL_DIR}
cp src/redis-server ${INSTALL_DIR}
cp src/redis-cli ${INSTALL_DIR}
cp src/redis-sentinel ${INSTALL_DIR}

# 清理临时文件
cd /tmp
rm -rf redis-${REDIS_VERSION} redis-${REDIS_VERSION}.tar.gz

# 添加 Redis 到系统 PATH
echo "export PATH=\$PATH:${INSTALL_DIR}" >> ~/.bashrc
source ~/.bashrc

# 启动 Redis 服务器
redis-server &

echo "Redis ${REDIS_VERSION} 已成功安装并运行