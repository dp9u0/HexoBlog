---
title: sql server 锁
categories:
  - knowledge
tags:
  - mssql
  - lock
date: 2017-03-21 22:12:11
---

介绍 SQL Server 的锁，阻塞以及死锁等问题。

<!-- more -->

# 目录

* [锁产生的背景](#锁产生的背景)
* [准备](#准备)
* [关于阻塞与死锁](#关于阻塞与死锁)
* [锁资源和兼容性](#锁资源和兼容性)
* [sqlserver事务隔离级别](#sqlserver事务隔离级别)
* [事务隔离级别和锁释放](#事务隔离级别和锁释放)
* [监视锁释放](#监视锁释放)
* [实际查询中锁的申请与释放](#实际查询中锁的申请与释放)
  * [SELECT](#SELECT)
  * [UPDATE](#UPDATE)
  * [DELETE](#DELETE)
  * [INSERT](#INSERT)

# 准备

下载巨硬提供的[AdventureWorks](https://msftdbprodsamples.codeplex.com/),下载的是[2014版本](https://msftdbprodsamples.codeplex.com/releases/view/125550).是bak文件，直接恢复数据库就可以了.

如果比较旧的版本，例如2008R2，提供的是下载的是 mdf和ldf.可以用CRTEATE DATABASE 命令，从文件创建：

{% codeblock lang:sql %}
CREATE DATABASE AdventureWorks
ON (FILENAME = 'C:\Data\AdventureWorks2008R2_Data.mdf'), (FILENAME = 'C:\Data\AdventureWorks2008R2_Log.ldf') FOR ATTACH;
{% endcodeblock %}

创建完成后，创建需要的表：

{% codeblock lang:sql %}
----------------------------------------------B树表聚集索引表-------------------------------------------
USE [AdventureWorks]
GO
IF EXISTS ( SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Employee_Demo_BTree')
  DROP TABLE Employee_Demo_BTree
GO
CREATE TABLE Employee_Demo_BTree(
  EmployeeID INT NOT NULL PRIMARY KEY,
  NationalIDNumber NVARCHAR(15) NOT NULL,
  ContactID INT NOT NULL,
  LoginID NVARCHAR(256) NOT NULL,
  ManagerID INT NULL,
  Title NVARCHAR(50) NOT NULL,
  BirthDate DATETIME NOT NULL,
  MaritalStatus NCHAR(1) NOT NULL,
  Gender NCHAR(1) NOT NULL,
  HireDate DATETIME NOT NULL,
  ModifiedDate DATETIME NOT NULL DEFAULT GETDATE()
)
GO
--主键就已经是聚集索引了,无需再指定
--CREATE CLUSTERED INDEX PK_Employee_EmployeeID_Demo_BTree ON Employee_Demo_BTree(EmployeeID ASC)
--添加非聚集索引
CREATE NONCLUSTERED INDEX IX_Employee_ManagerID_Demo_BTree ON Employee_Demo_BTree([ManagerID] ASC)
CREATE NONCLUSTERED INDEX IX_Employee_ModifiedDate_Demo_BTree ON Employee_Demo_BTree( [ModifiedDate] ASC)
--插入数据
INSERT [dbo].[Employee_Demo_BTree]
  SELECT [BusinessEntityID],
    [NationalIDNumber],
    [BusinessEntityID]+100,
    [LoginID],
    [BusinessEntityID]%50,
    [JobTitle],
    [BirthDate],
    [MaritalStatus],
    [Gender],
    [HireDate],
    [ModifiedDate]
  FROM [HumanResources].[Employee]
GO
----------------------------------------------堆表非聚集索引表-------------------------------------------
USE [AdventureWorks]
GO
IF EXISTS(SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Employee_Demo_Heap')
  DROP TABLE Employee_Demo_Heap
GO
CREATE TABLE Employee_Demo_Heap(
  EmployeeID INT NOT NULL,
  NationalIDNumber NVARCHAR(15) NOT NULL,
  ContactID INT NOT NULL,
  LoginID NVARCHAR(256) NOT NULL,
  ManagerID INT NULL,
  Title NVARCHAR(50) NOT NULL,
  BirthDate DATETIME NOT NULL,
  MaritalStatus NCHAR(1) NOT NULL,
  Gender NCHAR(1) NOT NULL,
  HireDate DATETIME NOT NULL,
  ModifiedDate DATETIME NOT NULL DEFAULT GETDATE()
)
GO
--因为没有主键所以要指定非聚集索引
CREATE NONCLUSTERED INDEX PK_Employee_EmployeeID_Demo_Heap ON Employee_Demo_Heap( [EmployeeID] ASC)
--添加非聚集索引
CREATE NONCLUSTERED INDEX IX_Employee_ManagerID_Demo_Heap ON Employee_Demo_BTree([ManagerID] ASC)
CREATE NONCLUSTERED INDEX IX_Employee_ModifiedDate_Demo_Heap ON Employee_Demo_BTree( [ModifiedDate] ASC)
--插入数据
INSERT [dbo].[Employee_Demo_Heap]
  SELECT [BusinessEntityID],
    [NationalIDNumber],
    [BusinessEntityID]+100,
    [LoginID],
    [BusinessEntityID]%50,
    [JobTitle],
    [BirthDate],
    [MaritalStatus],
    [Gender],
    [HireDate],
    [ModifiedDate]
  FROM [HumanResources].[Employee]
GO
{% endcodeblock %}

# 锁产生的背景

事务是关系型数据库的一个基础概念。他是作为单个逻辑工作单元执行的一系列操作一个逻辑工作单元必须有4个属性，称为原子性，
一致性，隔离性，持久性(ACID)只有这样才能成为一个事务.

* 原子性

--事务必须是原子工作单元；对于其数据修改，要么全都执行，要么全都不执行。
比如一个事务要修改100条记录，要不就100条都修改，要不就都不修改。不能
发生只修改了其中50条，另外50条没有改的情况.

* 一致性

事务在完成时，必须使所有的数据都保持一致状态。在相关数据库中，所有规则都必须应用于事务的修改，
以保持所有数据的完整性。事务结束时，所有的内部数据结构（如B树索引或双向链表）都必须是正确的

* 隔离性

由并发事务所做的修改必须与任何其他并发事务所做的修改隔离。事务识别数据所处的状态，
要么是另一并发事务修改他之前的状态，要么是第二个事务修改他之后的状态，事务不会
识别中间状态的数据。也就是说，虽然用户是在并发操作，但是，事务是串行执行的。
对同一个数据对象的操作，事务读写修改是有先后顺序的。不是同一时间什么事情都能同时做的

* 持久性

事务完成之后，他对于系统的影响是永久性的。哪怕SQL发生了异常终止，机器掉电，只要数据库文件还是完好的，
事务做的修改必须还全部存在.

以上事务的定义对所有的关系型数据库都成立，不管是SQLSERVER，还是DB2，ORACLE，都要
遵从这些限制。但是，不同的数据库系统在事务的实现机制上有所不同，索引产生的效果在
细节上是有差异的。尤其是SQLSERVER和ORACLE，在事务的实现上有很大不同。两者在不同的
应用场景上各有优劣，不好讲谁做得更好，谁做得更差。下面讲的是SQLSERVER实现事务
的方法

要实现业务逻辑上的ACID，有两方面任务

1、数据库程序员要负责启动和结束事务，确定一个事务的范围
程序员要定义数据修改的顺序，将组织的业务规则用TSQL语句表现出来，然后将这些语句包括到
一个事务中。换句话说，数据库程序员负责在必要并且合适的时间开启一个事务，将要做的操作
以正确的顺序提交给SQLSERVER，然后在合适的时间结束这个事务

2、SQLSERVER数据库引擎强制该事务的物理完整性
数据库引擎有能力提供一种机制，保证每个逻辑事务的物理完整性
SQLSERVER通过下面方法做到：

（1）锁定资源，使事务保持隔离
SQLSERVER通过在访问不同资源时需要申请不同类型锁的方式，实现了不同事务之间的隔离。
如果两个事务会互相影响，那么在其中一个事务申请到了锁以后，另外一个事务就必须等待，
直到前一个事务做完为止

（2）先写入日志方式，保证事务的持久性
SQLSERVER通过先写入日志的方式，保证所有提交了的事务在硬盘上的日志文件里都有记录。
即使服务器硬件，操作系统或数据库引擎实例自身出现故障，该实例也可以在重新启动时使用
事务日志，将所有未完成的事务自动地回滚到系统出现故障的点，使得数据库进入一个从事务
逻辑上来讲一致的状态


（3）事务管理特性，强制保证事务的原子性和一致性
事务启动后，就必须成功完成，否则数据库引擎实例将撤销该事务启动之后对数据所做的所有
修改

如果一个连接没有提交事务，SQL会保持这个事务一直在活动状态，并且不在意这个事务
的长短或这个连接是否还在活动，直到这个连接自己提交事务，或登出（logout）SQLSERVER
如果在登出的时候还有未提交的事务，SQL会把这个事务范围内所做的所有操作撤销（回滚）

所以，锁是SQL实现事务隔离的一部分，阻塞正是事务隔离的体现。要实现事务的隔离，阻塞
不是SQLSERVER自找的，而是事务对SQLSERVER提出的要求，也是用户使用事务要付出的代价
一个数据库开发者和DBA的工作，不是去消除阻塞，而是要把阻塞的时间和范围控制在一个
合理的范围之内，使最终用户既能享受事务的ACID，又能享受预期的性能。完全消除阻塞，
是不可能的事情


换句话说，阻塞是实现事务的隔离所带来的不可避免的代价。为了达到良好的性能，数据库
开发者和DBA要把阻塞的时间和范围控制在一个合理的范围之内。这不是一件很简单的工作，
所以阻塞也将会是SQLSERVER的永恒的话题之一。做同样的事情，怎麽才能比较不容易产生
大范围的阻塞呢？

从下面3个方面着手

* 申请资源的互斥度:如果不同的连接申请的锁都是相互兼容的，那么他们就不会产生阻塞
* 锁的范围和数目的多少:做同样一件事情，SQLSERVER申请的锁的粒度和数目可能会不一样。一个良好设计的程序可以使申请的锁的粒度和数目控制在最小的范围之内。这样，阻塞住别人的可能性就能大大降低
* 事务持有锁资源的时间长短:如果一个锁是大家都需要用的，那么每个人持有他的时间越短，阻塞对性能的影响就会越小。最好是申请得越晚越好，释放得越早越好

为了达到以上3个目的，需要研究一下SQLSERVER的锁资源模式和兼容性，以及他们怎麽被申请和释放的

# 关于阻塞与死锁

对于一个多用户数据库系统，尤其是大量用户通过不同应用程序同时访问同一个数据库的系统
如果发生一个或多个以下现象，管理员就应该检查是否遇到了阻塞或者死锁了

* 并发用户少的时候，一切正常。但是随着并发用户的增加，性能越来越慢

* 客户端经常收到以下错误

  * 错误1222:已经超过了锁请求超时时段

  * 错误1205:事务（进程ID XXX）与另一个进程被死锁在XX资源上，并且已被选作死锁牺牲品。请重新运行该事务

  * 超时错误:timeout expired.the timeout period elapsed prior to completion of the operation orthe server is not responding

* 应用程序运行很慢，但是SQL这里CPU和硬盘利用率很低。DBA运行sp_who或sp_who2这样的短小命令很快返回

* 有些查询能够进行，但是有些特定的查询或修改总是不能返回

* 重启SQL就能解决。但是有可能跑一段时间以后又会出问题

锁在一个连接里的生命周期是和事务的生命周期紧密相连的，数据结构不同，SQLSERVER需要申请的锁
的数量也会不同

造成阻塞和死锁的3大原因：

* 连接持有锁时间过长
* 锁数目过多
* 锁粒度过大

# 锁资源和兼容性

# sqlserver事务隔离级别

# 事务隔离级别和锁释放

# 监视锁释放

# 实际查询中锁的申请与释放

## SELECT

## UPDATE

## DELETE

## INSERT