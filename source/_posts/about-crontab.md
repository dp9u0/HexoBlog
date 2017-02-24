---
title: 关于crontab执行脚本环境变量问题
date: 2017-02-24 23:05:37
categories:
- knowledge
tags:
- crontab
- shell
---

搭建自己的博客配置了自动化脚本，用来同步git仓库、执行hexo命令生成&部署站点。

<!-- more -->

脚本内容如下

```
#!/bin/bash
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
    echo "++++++++++++++begin killall hexo++++++++" 
    killall hexo 
    echo "++++++++++++++begin hexo server+++++++++"
    hexo server &   
else
    echo "$TAR_DIR is not a dir,do nothing" 
fi
echo "----------------------------------------" 
echo $(date +%y_%m_%d_%H_%I_%T) 
echo "========================================" 
```
脚本中使用了nodejs中的hexo，在登录状态下，运行命令行是正常的。

这是由于在 /etc/profile 中配置了环境变量 ，添加了 NODE_HOME 、NODE_PATH 并将 NODE_HOME/bin 添加到 PATH。
这样，安装的 nodejs 包（默认安装的NODE_HOME/lib/node_modules，使用npm安装同时会创建软链接到 NODE_HOME/bin）都可以直接访问到。

```
#set nodejs env  
export NODE_HOME=/usr/local/node  
export PATH=$NODE_HOME/bin:$PATH  
export NODE_PATH=$NODE_HOME/lib/node_modules:$PATH

```

但是问题在于，crontab 执行脚本时。没有用户登录（用户登录会执行 /etc/profile 和 ~/.profile）
以及打开终端（打开终端会执行 /etc/bashrc 和 ~/.bashrc）的动作，需要的诸如 NODE_HOME 、NODE_PATH 等（通过/etc/profile 导入）就找不到了，PATH中也没有node的路径。

因此，这种情况下，配置 crontab 如下:

```
10 * * * * $HOME/CallAutoUpdate.sh # 每十分钟执行一次
```

其中CallAutoUpdate.sh为：


```
#!/bin/bash
# this srcipt call by cron 
# will not exoprt some env var in profile or .profile
# so ...
rm -fr ~/update.log
. /etc/profile
. ~/.profile
. ~/HexoBlog/AutoUpdate.sh >> ~/update.log
```

这样就解决了。
