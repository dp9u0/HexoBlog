---
title: 01.SQL SERVER如何执行一个查询
categories:
  - knowledge
tags:
  - mssql
  - performance tuning 
date: 2017-03-01 20:35:53
---
根据SQLpassion推送的 SQLpassion Performance Tuning Training Plan - Week 1: How SQL Server executes a Query。记录一下对查询执行的了解。
<!--more-->

# 提交查询

客户端提交给数据库的查询通过SQL Server网络接口等协议层(Protocol Layer)传给命令解析器。

# 命令解析器(Command Parser)处理

命令解释器接收到查询会做以下工作：
* 检查
  * 语法正确
  * 数据库表存在
  * 查询列存在
* 生成查询树(Query Tree)：重现查询
* 查询树提交给查询优化器

# 查询优化器(Query Optimizer)处理

* 查询优化器将查询树编译为查询计划(Execution Plan)
* 将查询计划缓存到缓冲池(Buffer Pool)中的执行计划缓存区(Plan Cache)
* 将查询计划提交给查询执行器

# 查询执行器(Query Executor)处理

* 查询分析器根据查询计划向存取方法(Access Methods)拿指定的读取页,存取方法会向缓冲区管理器读取想要指定页。
* 缓存区管理器(Buffer Manager)检查它是否已在数据缓存(data cache)，如果没找到的话就从磁盘加载到缓存。
  * 当请求的页面已经被存在缓冲池时,页会被立即读取,称为逻辑读。
  * 如果请求的页没存在缓冲池,缓冲区管理器会发起异步I/O操作把请求的页存储子系统中读到缓冲池,称为物理读。
# 修改数据

当修改数据(INSERT,DELETE,UPDATE)时，需要与事务管理器进行交互，事务管理器把执行事务中描述的改变通过事务日志写到事务文件。

{% asset_img mssqlarch.png sql server 核心架构图 %}


# 数据缓存(Data Cache)


查看每个数据库占用了多大数据缓存(sys.dm_os_buffer_descriptors)

{% codeblock lang:sql %}
SELECT count(*)*8/1024 AS 'Cached Size (MB)'
	,CASE database_id
		WHEN 32767 THEN 'ResourceDb'
		ELSE db_name(database_id)
		END AS 'Database'
FROM sys.dm_os_buffer_descriptors
GROUP BY db_name(database_id),database_id
ORDER BY 'Cached Size (MB)' DESC
{% endcodeblock %}

# 干净页和脏页

清除干净页

{% codeblock lang:sql %}
DBCC DROPCLEANBUFFERS
{% endcodeblock}

查询脏页

{% codeblock lang:sql %}
SELECT db_name(database_id) AS 'Database',count(page_id) AS 'Dirty Pages'
FROM sys.dm_os_buffer_descriptors
WHERE is_modified =1
GROUP BY db_name(database_id)
ORDER BY count(page_id) DESC
{% endcodeblock}

# 参考文献

[understanding-how-sql-server-executes-a-query](http://rusanu.com/2013/08/01/understanding-how-sql-server-executes-a-query)
[第1/24周 SQL Server 如何执行一个查询](http://www.cnblogs.com/woodytu/p/4465649.html)
[SQL Server 2012：SQL Server体系结构——一个查询的生命周期(1)](http://www.cnblogs.com/woodytu/p/4471386.html)
[SQL Server 2012：SQL Server体系结构——一个查询的生命周期(2)](http://www.cnblogs.com/woodytu/p/4472315.html)
[SQL Server 2012：SQL Server体系结构——一个查询的生命周期(3)](http://www.cnblogs.com/woodytu/p/4474652.html)
