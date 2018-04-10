---
title: docker 入门
date: 2018-04-08 15:56:31
categories: 
- learning
tags:
- docker
---

{% cq %}

开发人员总是会这么说：“在我的机器上是正常的呀！”
这就是开发过程中避免不了的一个问题：开发和上线环境不一致的问题。
Docker作为一种解决方案，很好的解决了这个问题。

{% endcq %}

<!--more-->

# 目录

* [背景](#背景)
* [安装](#安装)
* [HelloWorld](#HelloWorld)
* [Image](#Image)
* [Container](#Container)
* [制作自己的Image](#制作自己的Image)
* [微服务](#微服务)

# 背景

虚拟化技术应用非常广泛，主要有虚拟机和容器(LXC)两种。
虚拟机尤其有点也有缺点，冗余，占用资源高，启动慢，为此，诞生了Linux容器技术即LXC。
Docker 属于 Linux 容器的一种封装，提供简单易用的容器使用接口。它是目前最流行的 Linux 容器解决方案。

# 安装

根据官网教程选择自己的平台对应的[安装指引](https://docs.docker.com/install/)

安装完成后，在命令行中运行查看是否安装成功:

```shell
$ docker version
# 或者
$ docker info
```

Docker 是服务器----客户端架构。命令行运行docker命令的时候，需要本机有 Docker 服务。如果这项服务没有启动，可以用下面的命令启动(Linux宿主机。Windows 不需要)。

``` shell
# service 命令的用法
$ sudo service docker start
# systemctl 命令的用法
$ sudo systemctl start docker
```

补充一句，Windows下的Docker实际是通过Hyper-V创建了Linux虚拟机运行的。这个虚拟机已经配置好Docker的运行环境。

# HelloWorld

``` shell

#运行下面的命令，将 image 文件从仓库抓取到本地。

$ docker image pull library/hello-world

#上面代码中，docker image pull是抓取 image 文件的命令。library/hello-world是 image 文件在仓库里面的位置，其中library是 image 文件所在的组，hello-world是 image 文件的名字。
#由于 Docker 官方提供的 image 文件，都放在library组里面，所以它的是默认组，可以省略。因此，上面的命令可以写成下面这样。

$ docker image pull hello-world

#抓取成功以后，就可以在本机看到这个 image 文件了。

$ docker image ls

#运行

$ docker container run hello-world

# 可以看到类似下面的输出
#Hello from Docker!
#This message shows that your installation appears to be working correctly.

```

或者，可以直接输入命令：

``` shell
docker container run hello-world
```

docker 会自动查找Image，如果本地没有，会从官方仓库中pull，然后运行。

另外可以安装运行 Ubuntu

```shell
docker container run -it ubuntu bash
```

但是安装的Ubuntu是以服务运行的，并不会自动停止，需要使用kill命令停止

```shell
docker container kill [containID]

```

# Image

Docker 把应用程序及其依赖，打包在 image 文件里面。只有通过这个文件，才能生成 Docker 容器。image 文件可以看作是容器的模板。Docker 根据 image 文件生成容器的实例。同一个 image 文件，可以生成多个同时运行的容器实例。

image 是二进制文件。实际开发中，一个 image 文件往往通过继承另一个 image 文件，加上一些个性化设置而生成。举例来说，你可以在 Ubuntu 的 image 基础上，往里面加入 Apache 服务器，形成你的 image。

```shell
# 列出本机的所有 image 文件。
docker image ls

# 删除 image 文件
docker image rm [imageName]
image 文件是通用的，一台机器的 image 文件拷贝到另一台机器，照样可以使用。一般来说，为了节省时间，我们应该尽量使用别人制作好的 image 文件，而不是自己制作。即使要定制，也应该基于别人的 image 文件进行加工，而不是从零开始制作。
```

为了方便共享，image 文件制作完成后，可以上传到网上的仓库。Docker 的官方仓库 Docker Hub 是最重要、最常用的 image 仓库。此外，出售自己制作的 image 文件也是可以的。

# Container

image 文件生成的容器实例，本身也是一个文件，称为容器文件。也就是说，一旦容器生成，就会同时存在两个文件： image 文件和容器文件。而且关闭容器并不会删除容器文件，只是容器停止运行而已。

```shell
# 列出本机正在运行的容器
$ docker container ls

# 列出本机所有容器，包括终止运行的容器
$ docker container ls --all
```

上面命令的输出结果之中，包括容器的 ID。很多地方都需要提供这个 ID，比如上一节终止容器运行的docker container kill命令。

终止运行的容器文件，依然会占据硬盘空间，可以使用docker container rm命令删除。

```shell
$ docker container rm [containerID]
运行上面的命令之后，再使用docker container ls --all命令，就会发现被删除的容器文件已经消失了。
```

# 制作自己的Image

下面以 koa-demos 项目为例，介绍怎么写 Dockerfile 文件，实现让用户在 Docker 容器里面运行 Koa 框架。
作为准备工作，请先下载源码。

```shell
#作为准备工作，请先下载源码。
$ git clone https://github.com/ruanyf/koa-demos.git
$ cd koa-demos
```

接下来编写 Dockerfile 文件，首先，在项目的根目录下，新建一个文本文件.dockerignore，写入下面的内容。

```shell
.git
node_modules
npm-debug.log
```

上面代码表示，这三个路径要排除，不要打包进入 image 文件。如果你没有路径要排除，这个文件可以不新建。

然后，在项目的根目录下，新建一个文本文件 Dockerfile，写入下面的内容。

```shell
FROM node:8.4 #该 image 文件继承官方的 node image，冒号表示标签，这里标签是8.4，即8.4版本的 node。
COPY . /app #将当前目录下的所有文件（除了.dockerignore排除的路径），都拷贝进入 image 文件的/app目录。
WORKDIR /app #指定接下来的工作路径为/app。
RUN npm install --registry=https://registry.npm.taobao.org #在/app目录下，运行npm install命令安装依赖。注意，安装后所有的依赖，都将打包进入 image 文件。
EXPOSE 3000 #将容器 3000 端口暴露出来， 允许外部连接这个端口。
```

上面代码一共五行，含义如下:
FROM node:8.4：该 image 文件继承官方的 node image，冒号表示标签，这里标签是8.4，即8.4版本的 node。
COPY . /app：将当前目录下的所有文件（除了.dockerignore排除的路径），都拷贝进入 image 文件的/app目录。
WORKDIR /app：指定接下来的工作路径为/app。
RUN npm install：在/app目录下，运行npm install命令安装依赖。注意，安装后所有的依赖，都将打包进入 image 文件。
EXPOSE 3000：将容器 3000 端口暴露出来， 允许外部连接这个端口。

接下来创建 image 文件，使用docker image build命令创建 image 文件。

```shell
$ docker image build -t koa-demo .
# 或者
$ docker image build -t koa-demo:0.0.1 .
上面代码中，-t参数用来指定 image 文件的名字，后面还可以用冒号指定标签。如果不指定，默认的标签就是latest。最后的那个点表示 Dockerfile 文件所在的路径，上例是当前路径，所以是一个点。
```

如果运行成功，就可以看到新生成的 image 文件koa-demo了。

```shell
$ docker image ls
```

docker container run命令会从 image 文件生成容器。

```shell
$ docker container run -p 8000:3000 -it koa-demo /bin/bash
# 或者
$ docker container run -p 8000:3000 -it koa-demo:0.0.1 /bin/bash
```

上面命令的各个参数含义如下：

-p参数：容器的 3000 端口映射到本机的 8000 端口。
-it参数：容器的 Shell 映射到当前的 Shell，然后你在本机窗口输入的命令，就会传入容器。
koa-demo:0.0.1：image 文件的名字（如果有标签，还需要提供标签，默认是 latest 标签）。
/bin/bash：容器启动以后，内部第一个执行的命令。这里是启动 Bash，保证用户可以使用 Shell。
如果一切正常，运行上面的命令以后，就会返回一个命令行提示符。

```shell
root@66d80f4aaf1e:/app#
#这表示你已经在容器里面了，返回的提示符就是容器内部的 Shell 提示符。执行下面的命令。

root@66d80f4aaf1e:/app# node demos/01.js
#这时，Koa 框架已经运行起来了。打开本机的浏览器，访问 http://127.0.0.1:8000，网页显示"Not Found"，这是因为这个 demo 没有写路由。
```


这个例子中，Node 进程运行在 Docker 容器的虚拟环境里面，进程接触到的文件系统和网络接口都是虚拟的，与本机的文件系统和网络接口是隔离的，因此需要定义容器与物理机的端口映射（map）。
现在，在容器的命令行，按下 Ctrl + c 停止 Node 进程，然后按下 Ctrl + d （或者输入 exit）退出容器。此外，也可以用docker container kill终止容器运行。

```shell
# 在本机的另一个终端窗口，查出容器的 ID
$ docker container ls

# 停止指定的容器运行
$ docker container kill [containerID]
容器停止运行之后，并不会消失，用下面的命令删除容器文件。


# 查出容器的 ID
$ docker container ls --all

# 删除指定的容器文件
$ docker container rm [containerID]
# 也可以使用docker container run命令的--rm参数，在容器终止运行后自动删除容器文件。
$ docker container run --rm -p 8000:3000 -it koa-demo /bin/bash
```

最后说一下CMD 命令，上面说到容器启动以后，需要手动输入命令node demos/01.js。我们可以把这个命令写在 Dockerfile 里面，这样容器启动以后，这个命令就已经执行了，不用再手动输入了。

```shell
FROM node:8.4
COPY . /app
WORKDIR /app
RUN npm install --registry=https://registry.npm.taobao.org
EXPOSE 3000
CMD node demos/01.js
```

上面的 Dockerfile 里面，多了最后一行CMD node demos/01.js，它表示容器启动后自动执行node demos/01.js。

RUN命令与CMD命令的区别在哪里？简单说，RUN命令在 image 文件的构建阶段执行，执行结果都会打包进入 image 文件；CMD命令则是在容器启动后执行。另外，一个 Dockerfile 可以包含多个RUN命令，但是只能有一个CMD命令。

注意，指定了CMD命令以后，docker container run命令就不能附加命令了（比如前面的/bin/bash），否则它会覆盖CMD命令。现在，启动容器可以使用下面的命令。

```shell
docker container run --rm -p 8000:3000 -it koa-demo:0.0.1
```

最后的最后，是发布 image 文件，容器运行成功后，就确认了 image 文件的有效性。这时，我们就可以考虑把 image 文件分享到网上，让其他人使用。

首先，去 hub.docker.com 或 cloud.docker.com 注册一个账户。然后，用下面的命令登录。

```shell
$ docker login
#接着，为本地的 image 标注用户名和版本。
$ docker image tag [imageName] [username]/[repository]:[tag]
# 实例
$ docker image tag koa-demos:0.0.1 guodp9u0/koa-demos:0.0.1
#也可以不标注用户名，重新构建一下 image 文件。
$ docker image build -t [username]/[repository]:[tag] .
#最后，发布 image 文件。
$ docker image push [username]/[repository]:[tag]
```

发布成功以后，登录 hub.docker.com，就可以看到已经发布的 image 文件。

docker 的主要用法就是上面这些，此外还有几个命令，也非常有用。

* docker container start

前面的docker container run命令是新建容器，每运行一次，就会新建一个容器。同样的命令运行两次，就会生成两个一模一样的容器文件。如果希望重复使用容器，就要使用docker container start命令，它用来启动已经生成、已经停止运行的容器文件。

```shell
docker container start [containerID]
```

* docker container stop

前面的docker container kill命令终止容器运行，相当于向容器里面的主进程发出 SIGKILL 信号。而docker container stop命令也是用来终止容器运行，相当于向容器里面的主进程发出 SIGTERM 信号，然后过一段时间再发出 SIGKILL 信号。

```shell
bash container stop [containerID]
```

这两个信号的差别是，应用程序收到 SIGTERM 信号以后，可以自行进行收尾清理工作，但也可以不理会这个信号。如果收到 SIGKILL 信号，就会强行立即终止，那些正在进行中的操作会全部丢失。

* docker container logs

docker container logs命令用来查看 docker 容器的输出，即容器里面 Shell 的标准输出。如果docker run命令运行容器的时候，没有使用-it参数，就要用这个命令查看输出。

```shell
docker container logs [containerID]
```

* docker container exec

docker container exec命令用于进入一个正在运行的 docker 容器。如果docker run命令运行容器的时候，没有使用-it参数，就要用这个命令进入容器。一旦进入了容器，就可以在容器的 Shell 执行命令了。

```shell
docker container exec -it [containerID] /bin/bash
```

* docker container cp

docker container cp命令用于从正在运行的 Docker 容器里面，将文件拷贝到本机。下面是拷贝到当前目录的写法。

```shell
docker container cp [containID]:[/path/to/file] .
```

# 微服务