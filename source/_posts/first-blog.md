---
title: hexo搭建个人博客
date: 2017-02-22 22::56:56
categories: 
- knowledge
tags:
- hexo
---

发现一个基于 Node.js的高效的静态站点生成框架[Hexo](https://hexo.io/zh-cn/),使用 Markdown 编写文章,于是用来搭建自己的网站。
接下来介绍如何一步一步完成搭建的。

<!-- more -->

# 目录

- [目录](#目录)
- [准备](#准备)
- [构建](#构建)
  - [创建](#创建)
  - [配置](#配置)
  - [主题](#主题)
  - [插件](#插件)
  - [写作](#写作)
  - [生成](#生成)
  - [运行](#运行)
  - [部署](#部署)
    - [代码托管](#代码托管)
    - [自动部署云服务器](#自动部署云服务器)
    - [github.io](#githubio)

# 准备

需要在电脑中安装以下：

* [node.js](https://nodejs.org/en)

node 安装后 自带 npm 包管理器。安装方式请参考官网。

* [git](https://git-scm.com)

git 用于创建hexo项目、更换主题、管理创建的hexo项目源码以及部署到github.io使用。安装方式请参考官网。

* [hexo-cli](https://hexo.io/)

用于创建、管理、发布hexo项目。使用npm包管理器安装：

``` CSharp

npm install -g hexo-cli

```

# 构建

安装完 node 、git 以及hexo-cli 后，就可以开始构建hexo blog了。

## 创建

在源码目录下，命令行运行

``` 
hexo init youbsitename
```

就可以创建名为 __youbsitename__ 的站点目录了。此过程会clone一些项目到本地站点目录，过程如下：

```
INFO  Cloning hexo-starter to D:\Temp\test
Cloning into 'D:\Temp\test'...
remote: Counting objects: 53, done.
remote: Total 53 (delta 0), reused 0 (delta 0), pack-reused 53
Unpacking objects: 100% (53/53), done.
Submodule 'themes/landscape' (https://github.com/hexojs/hexo-theme-landscape.git) registered for path 'themes/landscape'
Cloning into 'D:/Temp/test/themes/landscape'...
remote: Counting objects: 764, done.
remote: Compressing objects: 100% (3/3), done.
remote: Total 764 (delta 0), reused 0 (delta 0), pack-reused 761
Receiving objects: 100% (764/764), 2.53 MiB | 53.00 KiB/s, done.
Resolving deltas: 100% (390/390), done.
Submodule path 'themes/landscape': checked out 'decdc2d9956776cbe95420ae94bac87e22468d38'
INFO  Install dependencies
npm WARN deprecated swig@1.4.2: This package is no longer maintained
npm WARN deprecated minimatch@0.3.0: Please update to minimatch 3.0.2 or higher to avoid a RegExp DoS issue
npm WARN prefer global marked@0.3.6 should be installed with -g
> dtrace-provider@0.8.0 install D:\Temp\test\node_modules\dtrace-provider
> node scripts/install.js
> hexo-util@0.6.0 postinstall D:\Temp\test\node_modules\hexo-util
> npm run build:highlight
> hexo-util@0.6.0 build:highlight D:\Temp\test\node_modules\hexo-util
> node scripts/build_highlight_alias.js > highlight_alias.json
```
然后，进入blog目录，就可以对blog进行操作了。

``` 
cd yousitename && dir
```

blog 目录结构如下

```
yousitename
├─package.json      项目package
├─_config.yml       站点配置文件
├─public            发布文件夹
├─scaffolds         模版文件夹
├─source            原始文件，通过"hexo g"将本目录下的文件生成为html等到public文件夹
├─themes            主题文件夹
├─...
└─...
```

## 配置

根目录下的站点配置文件 _config.yml 中的内容是对项目的一些配置，例如
*   网站信息：作者、名称、描述等
*   网站结构
*   发布方式：支持发布到git(需要插件[hexo-deployer-git](https://github.com/hexojs/hexo-deployer-git)支持)

## 主题

修改站点配置文件 _config.yml 中的内容：
```
theme: next(你想要的主题，主题需要放在站点目录下的themes目录下)
```
官网有提供[主题列表](https://hexo.io)可以选择，当然你也可以做自己的主题

另外，主题也有自己的主题配置文件 _config.yml，存放主题自己的一些配置。主题配置文件位置在主题目录下。

## 插件

同样，hexo提供了插件功能，可以提供很多生成、发布和运行等的功能。
例如可以生成静态网站后，通过插件[hexo-deployer-git](https://github.com/hexojs/hexo-deployer-git)将生成的内容发布到git.
利用这个插件搭配[github.io](https://pages.github.com/),可以实现自动生成&部署自己的网站。

## 写作

```
hexo new [layout] <title>
```

Hexo 有三种默认布局：post、page 和 draft，它们分别对应不同的路径，而您自定义的其他布局和 post 相同，都将储存到 source/_posts 文件夹。
如果不想文章被布局处理，可以将 Front-Matter 中的layout: 设为 false 。


| 布局  |      路径      |
| ----- | :------------: |
| post  | source/_posts  |
| page  |     source     |
| draft | source/_drafts |


更多的写作可以参考[官网](https://hexo.io/zh-cn/).

建议创建页面 : tags 和categories 页面,生成的时候可以自动生成[分类]((http://localhost:4000/categories/))和[标签](http://localhost:4000/tags/)页面的内容。

```shell
hexo new page tags
hexo new page categories
```

## 生成

```shell
hexo generate
```

或者

```shell
hexo g
```

默认将静态网站生成到 public 目录下，生成完成后就可以将 public 目录下的内容发布到静态网站服务器上。

## 运行

可以使用 hexo server 命令，本地启动服务器，运行网站

```shell
hexo server
```

默认启动端口为 4000 的服务端，可以使用 [http://localhost:4000](http://localhost:4000/) 访问。

## 部署

### 代码托管

将创建的网站仓库托管到github，注册等过程不表。

配置自己的[网站仓库](https://github.com/dp9u0/HexoBlog)，然后就可以git commit & git push ,将源码推送到github上。这样就可以随时编辑自己的网站了。

不必要的内容不需要提交，可以使用  .gitignore， 贴一下自己的 .gitignore 文件:

```
# Logs
logs
*.log
npm-debug.log*

# Runtime data
pids
*.pid
*.seed

# Directory for instrumented libs generated by jscoverage/JSCover
lib-cov

# Coverage directory used by tools like istanbul
coverage

# nyc test coverage
.nyc_output

# Grunt intermediate storage (http://gruntjs.com/creating-plugins#storing-task-files)
.grunt

# node-waf configuration
.lock-wscript

# Compiled binary addons (http://nodejs.org/api/addons.html)
build/Release

# Dependency directories
node_modules
jspm_packages

# Optional npm cache directory
.npm

# Optional REPL history
.node_repl_history

.DS_Store
Thumbs.db
db.json
*.log
public/
.deploy*/
```
### 自动部署云服务器

在云服务器(ubuntu 16.04)上安装 nodejs 、git 、hexo-cli

然后clone 到仓库本地：

```
cd ~ 
git clone https://github.com/dp9u0/HexoBlog
```

创建周期执行的呼叫脚本：

```
vi CallHexoBlogAutoUpdate.sh
```

CallHexoBlogAutoUpdate.sh脚本中，添加以下内容，呼叫仓库中的自动更新脚本：

```
#!/bin/bash
. ~/HexoBlog/AutoUpdate.sh
```

为什么要有两个脚本: CallHexoBlogAutoUpdate.sh  和 AutoUpdate.sh?
不知道怎么给 AutoUpdate.sh 添加权限 ，不同的操作系统clone后，权限依旧保留。
同时 . ~/HexoBlog/AutoUpdate.sh 如果直接配置在 crontab 环境变量好像有点问题。
因此将所以自动更新的逻辑放在 AutoUpdate.sh 并且在每个需要执行自动更新的机器上添加外壳程序 CallHexoBlogAutoUpdate.sh  用点符号执行脚本 AutoUpdate.sh。
并且外壳程序添加到定时任务中。

调用的自动更新脚本（该脚本加入到git仓库中，可以自更新）：

```shell
#!/bin/bash
LOG_FILE=~/HexoBlogAutoUpdate.log
echo "========================================" >> $LOG_FILE
echo $(date +%y_%m_%d_%H_%I_%T) >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE
if [ $1 ] ; then        
    echo "first argument is not empty : $1" >> $LOG_FILE
    TAR_DIR=$1 
    echo "use first argument as target dir : $TAR_DIR" >> $LOG_FILE
else
    echo "first argument is empty" >> $LOG_FILE  
    # use  ~/HexoBlog as the default dir    
    TAR_DIR=~/HexoBlog # 修改为你需要的默认路径
    echo "use default dir as target dir : $TAR_DIR" >> $LOG_FILE
fi 
echo "----------------------------------------" >> $LOG_FILE
if [ -d $TAR_DIR ] ; then 
    echo "$TAR_DIR is a dir,try update" >> $LOG_FILE
    cd $TAR_DIR
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    git pull >> $LOG_FILE # 同步git
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    killall hexo >> $LOG_FILE # 关闭 hexo server
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    hexo clean >> $LOG_FILE # 清理 
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    hexo g >> $LOG_FILE # 生成
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    hexo server &  # 启动 hexo server
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
    hexo d >> $LOG_FILE   # 自动 
    echo "++++++++++++++++++++++++++++++++++++++++" >> $LOG_FILE
else
    echo "$TAR_DIR is not a dir,do nothing" >> $LOG_FILE
fi
echo "----------------------------------------" >> $LOG_FILE
echo $(date +%y_%m_%d_%H_%I_%T) >> $LOG_FILE
echo "========================================" >> $LOG_FILE
```

添加 CallHexoBlogAutoUpdate 脚本执行权限：

```
chmod +x CallHexoBlogAutoUpdate.sh
```

添加定时任务

```
crontab -e
```

添加如下内容

```
*/5 * * * *  ~/CallHexoBlogAutoUpdate.sh # 五分钟执行检查一次更新

```

### github.io

hexo deploy 命令根据站点配置文件_config.yml中的配置，将生成的内容发布到站点中。

其中不同的type需要特殊的插件支持。
例如发布到git上，需要插件[hexo-deployer-git](https://github.com/hexojs/hexo-deployer-git)

首先创建自己的[github.io仓库](https://github.com/dp9u0/dp9u0.github.io)

关于github.io:如果建立了 用户名.github.io 的仓库，github会定时将这个仓库的静态页面发布到 用户名.github.io 的站点上.
可以了解更多关于 [github.io](github.io)的内容

站点配置文件配置参考如下：

```shell
deploy:
  type: git
  repo: git@github.com:dp9u0/dp9u0.github.io.git
  branch: master
```

部署到git，需要有你的github仓库的push权限，可以参考[github文档](https://help.github.com/articles/connecting-to-github-with-ssh/)中关于[生成 SSH Key](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/)
以及[添加SSH Key](https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/)的部分，配置通过SSH免密码push代码到github。

然后，就可以运行生成部署命令了。

```shell
hexo g
hexo d
```

这些也可以添加到AutoUpdate.sh脚本中，这样我只需要在自己的个人电脑上hexo new ,编辑自己的网站，然后git commit 提交，再执行git push到推送到 将源码推送到github上。这样就可以随时编辑自己的网站了。
部署在云服务器上的[网站](http://baochen.name:4000) 和[github.io](https://dp9u0.github.io) 上的内容，都会自动更新了！
