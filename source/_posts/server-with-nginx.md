---
title: 使用Nginx运行网站
date: 2017-02-24 15:18:17
categories:
- knowledge
tags:
- nginx
---
hexo server 不太好用，决定使用nginx。

<!-- more -->

首先在服务器上安装nginx，以ubuntu为例。使用apt-get安装比较方便，节省很多配置。

```
sudo apt-get nginx
```

然后开始配置nginx：

```
cd /etc/nginx
sudp cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
sudo vi /etc/nginx/nginx.conf
```

配置内容如下：

```
user www-data;

worker_processes auto;

pid /run/nginx.pid;


events {
        worker_connections 768;
        # multi_accept on;
}

http {

        ##
        # Basic Settings
        ##

        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 65;
        types_hash_max_size 2048;
        # server_tokens off;

        # server_names_hash_bucket_size 64;
        # server_name_in_redirect off;

        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        ##
        # SSL Settings
        ##

        ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;

        ##
        # Logging Settings
        ##

        # log_format main '$remote_addr - $remote_user [$time_local] "$request" ' '$status $body_bytes_sent "$http_referer" ' '"$http_user_agent" "$http_x_forwarded_for"';

        error_log /var/log/nginx/error.log;

        ##
        # Gzip Settings
        ##

        gzip on;
        gzip_disable "msie6";
        gzip_min_length 1k;
        gzip_vary on;
        gzip_proxied any;
        gzip_comp_level 6;
        gzip_buffers 16 8k;
        gzip_http_version 1.1;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

        ##
        # Http Proxy Settings
        ##
        client_max_body_size   10m;
        client_body_buffer_size   128k;
        proxy_connect_timeout   75;
        proxy_send_timeout   75;
        proxy_read_timeout   75;
        proxy_buffer_size   4k;
        proxy_buffers   4 32k;
        proxy_busy_buffers_size   64k;
        proxy_temp_file_write_size  64k;
        proxy_temp_path   /tmp/proxy_temp 1 2;

        ##
        # Upstream Settings
        ##

        upstream  backend  { 
              ip_hash; 
              server   127.0.0.1:4000 max_fails=2 fail_timeout=30s ;  
              # server   192.168.10.101:8080 max_fails=2 fail_timeout=30s ;  
        }


        ##
        # Server Settings
        ##

        ## Server baochen.name

        server {

                listen       80;
                server_name  baochen.name;
                charset utf-8;
        
                access_log      /var/log/nginx/baochen.name.access.log;
                error_log       /var/log/nginx/baochen.name.error.log;
        
                location / {
                        # proxy_pass        http://backend;  
                        # proxy_redirect off;
                        # proxy_set_header  Host  $host;
                        # proxy_set_header  X-Real-IP  $remote_addr;  
                        # proxy_set_header  X-Forwarded-For  $proxy_add_x_forwarded_for;
                        # proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
                        root /var/www/hexoblog;
                        index  index.html;
                }

                location /nginx_status {
                        stub_status on;
                        access_log /var/log/nginx/ngs.access.log;
                        # allow 192.168.10.0/24;
                        # deny all;
                }

                location ~ ^/(WEB-INF)/ {   
                        deny all;   
                }

                # error_page  404              /404.html;
                # redirect server error pages to the static page /50x.html
                #

                error_page   500 502 503 504  /50x.html;

                location = /50x.html {
                        root   html;
                }

    } 

        ##
        # Virtual Host Configs
        ##

        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
}
```

编辑完成后 esc -> !wq 退出。

编写crontab脚本:

```
#!/bin/bash
#this srcipt call by cron 
#will not exoprt some env var in profile or .profile

rm -fr ~/update.log

#execute profile
. /etc/profile
. ~/.profile

#auto pull source code , generate and deploy to git
. ~/HexoBlog/AutoUpdate.sh >> ~/update.log # 根据实际位置填写

#deploy
sudo cp -r ~/HexoBlog/public/* /var/www/hexoblog # 注意权限
```

其中  脚本 AutoUpdate.sh 是自己随着库进行同步的 ，内容如下(之所以两个脚本原因看{% post_link about-crontab 这里 %})。

```
#!/bin/bash
# 如果使用cron 定时call 更新脚本 
# 会出现 一些定义在profile 中的环境变量无法引入的情况
# 可以单独建立一个壳脚本 添加一些必要的变量 再呼叫当前脚本 AutoUpdate.sh
#. /etc/profile
#. ~/.profile
#. ~/<somepath>/AutoUpdate.sh # call this srcipt
DEFAULT_DIR=$HOME/HexoBlog
echo "========================================" 
echo $(date +%y_%m_%d_%H_%I_%T) 
echo "----------------------------------------" 
echo "HOME : $HOME"
echo "PATH : $PATH"
echo "NODE_HOME : $NODE_HOME"
echo `whereis hexo`
echo "----------------------------------------" 
if [ $1 ] ; then        
    echo "first argument is not empty : $1" 
    TAR_DIR=$1 
    echo "use first argument as target dir : $TAR_DIR" 
else
    echo "first argument is empty"   
    # use $DEFAULT_DIR as the target dir    
    TAR_DIR=$DEFAULT_DIR
    echo "use default dir as target dir : $TAR_DIR" 
fi 
echo "----------------------------------------" 
if [ -d $TAR_DIR ] ; then 
    echo "$TAR_DIR is a dir,try update" 
    cd $TAR_DIR
    echo "++++++++++++++begin git pull++++++++++++" 
    git pull 
    echo "++++++++++++++begin  hexo clean+++++++++"
    hexo clean 
    echo "++++++++++++++begin  hexo generate+++++++"
    hexo g 
    echo "++++++++++++++begin hexo deploy+++++++++"
    hexo d 
    #echo "++++++++++++++begin killall hexo++++++++" 
    #killall hexo 
    #echo "++++++++++++++begin hexo server+++++++++"
    #hexo server &   
else
    echo "$TAR_DIR is not a dir,do nothing" 
fi
echo "----------------------------------------" 
echo $(date +%y_%m_%d_%H_%I_%T) 
echo "========================================" 

```

然后  启动nginx ！

```
sudo service nginx start
```

完成！