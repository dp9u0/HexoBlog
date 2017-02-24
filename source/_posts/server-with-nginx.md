---
title: 使用Nginx运行服务器
date: 2017-02-24 15:18:17
categories:
- knowledge
tags:
- nginx
---
hexo server 不太好用，决定使用nginx

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
```

编辑完成后 esc -> !wq 退出。

编写crontab脚本:

```
#!/bin/bash
# this srcipt call by cron 
# will not exoprt some env var in profile or .profile

rm -fr ~/update.log

# execute profile
. /etc/profile
. ~/.profile

# auto pull source code , generate and deploy to git
. ~/HexoBlog/AutoUpdate.sh >> ~/update.log # 根据实际位置填写

# deploy
sudo cp -r ~/HexoBlog/public/* /var/www/hexoblog # 注意权限
```

其中  脚本 AutoUpdate.sh 是自己随着库进行同步的 ，内容如下(之所以两个脚本原因看![这里](about-crontab.md).)。

```
#!/bin/bash
# 如果使用cron 定时call 更新脚本 
# 会出现 一些定义在profile 中的环境变量无法引入的情况
# 可以单独建立一个壳脚本 添加一些必要的变量 再呼叫当前脚本 AutoUpdate.sh
# . /etc/profile
# . ~/.profile
# . ~/<somepath>/AutoUpdate.sh # call this srcipt
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