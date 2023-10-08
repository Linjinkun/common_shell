#安装nginx的依赖，不存在就安装

```
packages=("pcre" "zlib" "openssl-devel" "gcc" "gcc-c++" "make")

for package in "${packages[@]}"; do
    if ! yum list installed "$package" >/dev/null 2>&1; then
        echo "Installing $package..."
        yum -y install "$package"
    else
        echo "$package is already installed."
    fi
done
```

#创建www用户

```
useradd -m -s /bin/bash www
```

#创建目录

```
mkdir -p /data/server/nginx
mkdir -p /var/temp/nginx/client
```

#https://nginx.org/
#下载指定版本的nginx => https://nginx.org/download/nginx-1.24.0.tar.gz

```
wget https://nginx.org/download/nginx-1.24.0.tar.gz

tar -zxvf nginx-1.24.0.tar.gz

cd nginx-1.24

./configure \
    --prefix=/data/server/nginx \
    --pid-path=/var/run/nginx/nginx.pid \
    --lock-path=/var/lock/nginx.lock \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --with-http_gzip_static_module \
    --http-client-body-temp-path=/var/temp/nginx/client \
    --http-proxy-temp-path=/var/temp/nginx/proxy \
    --http-fastcgi-temp-path=/var/temp/nginx/fastcgi \
    --http-uwsgi-temp-path=/var/temp/nginx/uwsgi \
    --http-scgi-temp-path=/var/temp/nginx/scgi

make && make install

ln -s /data/server/nginx/sbin/nginx /usr/local/sbin/  #让系统识别nginx的操作命令   
```

```
vi /usr/lib/systemd/system/nginx.service
```

```
[Unit]
  Description=nginx web server
  Documentation=http://nginx.org/en/docs/
  After=network.target remote-fs.target nss-lookup.target
[Service]
  Type=forking
  PIDFile=/var/run/nginx/nginx.pid
  ExecStartPre=/usr/local/sbin/nginx -t -c /data/server/nginx/conf/nginx.conf
  #指定你刚才查到的目录和你的nginx配置文件
  ExecStart=/usr/local/sbin/nginx -c /data/server/nginx/conf/nginx.conf
  #同上
  ExecReload=/bin/kill -s HUP $MAINPID
  ExecStop=/bin/kill -s QUIT $MAINPID
  #以下写法也行
  #ExecReload=/usr/sbin/nginx -s reload
  #ExecStop=/usr/sbin/nginx -s stop
  PrivateTmp=true
[Install]
  WantedBy=multi-user.target
```

```
vi /usr/lib/systemd/system/nginx.service

chmod +x /usr/lib/systemd/system/nginx.service

systemctl daemon-reload   #重载配置
systemctl enable nginx 
systemctl reload nginx
nginx -s reload
```

