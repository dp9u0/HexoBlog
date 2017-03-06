---
title: SQL Server 存储单位:页
categories:
  - knowledge
tags:
  - mssql
  - performance tuning 
date: 2017-03-01 21:53:47
---

SQL Server 基本存储单位是页，一个页大小为8K。
页分为不同的类型。

<!--more-->

{% codeblock lang:sql %}
USE [Test]
GO
if exists (select * from sysobjects where id =  object_id(N'[dbo].[Customers]') and OBJECTPROPERTY(id, N'IsUserTable') = 1 )
DROP TABLE dbo.Customers
CREATE TABLE Customers
(
   FirstName CHAR(50) NOT NULL,
   LastName CHAR(50) NOT NULL,
   Address CHAR(100) NOT NULL,
   ZipCode CHAR(5) NOT NULL,
   Rating INT NOT NULL,
   ModifiedDate DATETIME NOT NULL,
)
GO
INSERT INTO dbo.Customers
        ( FirstName ,
          LastName ,
          Address ,
          ZipCode ,
          Rating ,
          ModifiedDate
        )
VALUES  ( 'Philip' , 
          'Aschenbrenner' ,
          'Pichlagasse 16/6' , 
          '1220' , 
          1 ,
          '2015-03-25 02:22:51' 
        )
GO
{% endcodeblock %}  

DBCC IND 命令用于查询一个存储对象的内部存储结构信息，该命令有4个参数, 前3个参数必须指定。语法如下：
DBCC IND ( { 'dbname' | dbid }, { 'objname' | objid },{ nonclustered indid | 1 | 0 | -1 | -2 } [, partition_number] )
第一个参数是数据库名或数据库ID。
第二个参数是数据库中的对象名或对象ID，对象可以是表或者索引视图。
第三个参数是一个非聚集索引ID或者 1, 0, 1, or 2. 值的含义：
 0: 只显示对象的in-row data页和 in-row IAM 页。
 1: 显示对象的全部页, 包含IAM 页, in-row数据页, LOB 数据页row-overflow 数据页 . 如果请求的对象含有聚集所以则索引页也包括。
 -1: 显示全部IAM页,数据页, 索引页 也包括 LOB 和row-overflow 数据页。
 -2: 显示全部IAM页。
 Nonclustered index ID:显示索引的全部 IAM页, data页和索引页，包含LOB和 row-overflow数据页。
为了兼容sql server 2000,第四个参数是可选的,该参数用于指定一个分区号.如果不给定值或者给定0, 则显示全部分区数据。
和DBCC PAGE不同的是, SQL Server运行DBCC IND不需要开启3604跟踪标志.
结果中 Page type: 1 = data page, 2 = index page, 3 = LOB_MIXED_PAGE, 4 = LOB_TREE_PAGE, 10 = IAM page   

{% codeblock lang:sql %}
DBCC IND('InternalStorageFormat','Customers',-1)
{% endcodeblock %}

DBCC Page 命令读取数据页结构的命令DBCC Page。
该命令为非文档化的命令，具体如下： 
　　DBCC Page ({dbid|dbname},filenum,pagenum[,printopt])
　　具体参数描述如下：
　　dbid 包含页面的数据库ID
　　dbname 包含页面的数据库的名称
　　filenum 包含页面的文件编号
　　pagenum 文件内的页面
　　printopt 可选的输出选项;选用其中一个值：
　　0:默认值，输出缓冲区的标题和页面标题
　　1:输出缓冲区的标题、页面标题(分别输出每一行)，以及行偏移量表
　　2:输出缓冲区的标题、页面标题(整体输出页面)，以及行偏移量表
　　3:输出缓冲区的标题、页面标题(分别输出每一行)，以及行偏移量表;每一行
　　后跟分别列出的它的列值
　　要想看到这些输出的结果，还需要设置DBCC TRACEON(3604)。
可以使用 WITH TABLERESULTS 显示成表格化的数据形式

{% codeblock lang:sql %}
DBCC TRACEON(3604)
DBCC PAGE(InternalStorageFormat,1,41,3) 
GO    
{% endcodeblock %}

查看空间占用情况
free_space_in_bytes 表示在指定页面当前有多少空间是可用的。

{% codeblock lang:sql %}
SELECT * FROM sys.dm_os_buffer_descriptors
{% endcodeblock %}

下面这个查询可以告诉你在你的数据库实例里每个数据有多少空间被浪费，可以找出哪个数据库有糟糕的表设计。
{% codeblock lang:sql %}
SELECT
DB_NAME(database_id),
SUM(free_space_in_bytes) / 1024 AS 'Free_KB'
FROM sys.dm_os_buffer_descriptors
WHERE database_id <> 32767
GROUP BY database_id
ORDER BY SUM(free_space_in_bytes) DESC
GO
{% endcodeblock %}