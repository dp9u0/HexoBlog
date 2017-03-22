---
title: 3.SQL Server基本管理单位:区(Extend)
categories:
  - knowledge
tags:
  - mssql
  - performance tuning 
date: 2017-03-21 21:50:07
---

区就是一组8个页(8K),因此区是64k的块。SQL Server内部有2类区：
* 混合区
* 统一区

<!--more-->

全局分配映射表（GAM: Global Allocation Map Pages） ：GAM页记录哪些些区已被使用分配。对于每个区，GAM都有一个位。如果这个位是1，表示对应的区是空闲可用的。如果这个位是0，表示对应区被统一区或混合区使用。一个GAM页可以保存64000个区的使用信息。这就是说，一个GAM可以保存近4G（64000 * 8 * 8/ 1024)数据文件的使用信息。简单来说，一个7G的数据文件会有2个GAM页。

共享全局分配映射表（SGAM: Shared Global Allocation Map Pages） ：SGAM页记录哪些区已被作为混合区使用并至少有一个可用的空闲页。对于每个区，SGAM都有一个位。如果这个位是1，表示对应的区作为混合区使用并至少有一个可用的空闲页。如果这个位是0，表示这个区既没被混合区使用（作为统一区），或这个区的所有页都作为混合区使用了。一个SGAM页可以保存64000个区的使用信息。这就是说，一个SGAM可以保存近4G（64000 * 8 * 8/ 1024)数据文件的使用信息。简单来说，一个7G的数据文件会有2个SGAM页。

GAM和SGAM页帮助数据库引擎进行区管理。分配一个区，数据库引擎查找标记1的GAM页，然后标记为0。如果那个区是作为混合区分配，它会在SGAM页把对应区的标记为1。如果那个区是作为统一区分配，那就没有必要在SGAM里修改对应位标记。找一个有空页的混合区，数据库引擎在SGAM页查找标记为1的位。如果没找到，数据文件已经满了。解除一个区分配，数据库引擎会把对应GAM页里对应位设置为1，SGAM页里对应标记设置为0。

在每个数据文件里，第3个页（页号2，页号从0开始）是GAM页，第4个页（页号3，页号从0开始）是SGAM页。第1个页（页号0）是文件头（file header），第2个页（页号1）是PFS（Page Free Space）页。我们可以使用DBCC PAGE命令查看GAM和SGAM页。


[存储引擎揭秘](http://www.cnblogs.com/wcyao/archive/2011/06/28/2092241.html)
[SQL Server 存储](http://www.cnblogs.com/woodytu/tag/SQL%20Server%20%E5%AD%98%E5%82%A8/)
[理解GAM和SGAM页](http://www.cnblogs.com/woodytu/p/4487310.html)