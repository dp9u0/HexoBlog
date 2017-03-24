---
title: sql server 锁(1)
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
* [锁资源和兼容性](#锁资源和兼容性)
* [事务隔离级别和锁释放](#事务隔离级别和锁释放)
* [监视锁申请、持有和释放](#监视锁申请、持有和释放)
* [准备](#准备)
* [实际查询中锁的申请与释放](#实际查询中锁的申请与释放)
  * [SELECT](#SELECT)
  * [UPDATE](#UPDATE)
  * [DELETE](#DELETE)
  * [INSERT](#INSERT)

# 锁 阻塞 死锁

事务是关系型数据库的一个基础概念。他是作为单个逻辑工作单元执行的一系列操作一个逻辑工作单元必须有4个属性，称为原子性，
一致性，隔离性，持久性(ACID)只有这样才能成为一个事务.

* 原子性

事务必须是原子工作单元；对于其数据修改，要么全都执行，要么全都不执行。比如一个事务要修改100条记录，要不就100条都修改，要不就都不修改。不能发生只修改了其中50条，另外50条没有改的情况。

* 一致性

事务在完成时，必须使所有的数据都保持一致状态。在相关数据库中，所有规则都必须应用于事务的修改，以保持所有数据的完整性。事务结束时，所有的内部数据结构（如B树索引或双向链表）都必须是正确的。

* 隔离性

由并发事务所做的修改必须与任何其他并发事务所做的修改隔离。事务识别数据所处的状态，要么是另一并发事务修改他之前的状态，要么是第二个事务修改他之后的状态，事务不会识别中间状态的数据。也就是说，虽然用户是在并发操作，但是，事务是串行执行的。对同一个数据对象的操作，事务读写修改是有先后顺序的。不是同一时间什么事情都能同时做的。

* 持久性

事务完成之后，他对于系统的影响是永久性的。哪怕SQL发生了异常终止，机器掉电，只要数据库文件还是完好的，事务做的修改必须还全部存在。


以上事务的定义对所有的关系型数据库都成立，不管是SQLSERVER，还是DB2，ORACLE，都要遵从这些限制。但是，不同的数据库系统在事务的实现机制上有所不同，索引产生的效果在细节上是有差异的。尤其是SQLSERVER和ORACLE，在事务的实现上有很大不同。两者在不同的应用场景上各有优劣，不好讲谁做得更好，谁做得更差。下面讲的是SQLSERVER实现事务的方法。

要实现业务逻辑上的ACID，有两方面任务：

1、数据库程序员要负责启动和结束事务，确定一个事务的范围:程序员要定义数据修改的顺序，将组织的业务规则用TSQL语句表现出来，然后将这些语句包括到一个事务中。换句话说，数据库程序员负责在必要并且合适的时间开启一个事务，将要做的操作以正确的顺序提交给SQLSERVER，然后在合适的时间结束这个事务。

2、SQLSERVER数据库引擎强制该事务的物理完整性:数据库引擎有能力提供一种机制，保证每个逻辑事务的物理完整性SQLSERVER通过下面方法做到：

* 锁定资源，使事务保持隔离

SQLSERVER通过在访问不同资源时需要申请不同类型锁的方式，实现了不同事务之间的隔离。如果两个事务会互相影响，那么在其中一个事务申请到了锁以后，另外一个事务就必须等待，直到前一个事务做完为止。

* 先写入日志方式，保证事务的持久性

SQLSERVER通过先写入日志的方式，保证所有提交了的事务在硬盘上的日志文件里都有记录。即使服务器硬件，操作系统或数据库引擎实例自身出现故障，该实例也可以在重新启动时使用事务日志，将所有未完成的事务自动地回滚到系统出现故障的点，使得数据库进入一个从事务逻辑上来讲一致的状态。

* 事务管理特性，强制保证事务的原子性和一致性

事务启动后，就必须成功完成，否则数据库引擎实例将撤销该事务启动之后对数据所做的所有修改。

如果一个连接没有提交事务，SQL会保持这个事务一直在活动状态，并且不在意这个事务的长短或这个连接是否还在活动，直到这个连接自己提交事务，或登出（logout）SQLSERVER如果在登出的时候还有未提交的事务，SQL会把这个事务范围内所做的所有操作撤销（回滚）。

所以，锁是SQL实现事务隔离的一部分，阻塞正是事务隔离的体现。要实现事务的隔离，阻塞不是SQLSERVER自找的，而是事务对SQLSERVER提出的要求，也是用户使用事务要付出的代价一个数据库开发者和DBA的工作，不是去消除阻塞，而是要把阻塞的时间和范围控制在一个合理的范围之内，使最终用户既能享受事务的ACID，又能享受预期的性能。完全消除阻塞，是不可能的事情。

换句话说，阻塞是实现事务的隔离所带来的不可避免的代价。为了达到良好的性能，数据库开发者和DBA要把阻塞的时间和范围控制在一个合理的范围之内。这不是一件很简单的工作，所以阻塞也将会是SQLSERVER的永恒的话题之一。

阻塞和死锁是两个不同的概念:

* 阻塞是由于资源不足引起的排队等待现象。

* 死锁是由于两个对象在拥有一份资源的情况下申请另一份资源，而另一份资源恰好又是这两对象正持有的，导致两对象无法完成操作，且所持资源无法释放。例如：
  * 事务 A 获取了行 1 的共享锁。
  * 事务 B 获取了行 2 的共享锁。
  * 现在，事务 A 请求行 2 的排他锁，但在事务 B 完成并释放其对行 2 持有的共享锁之前被阻塞。
  * 现在，事务 B 请求行 1 的排他锁，但在事务 A 完成并释放其对行 1 持有的共享锁之前被阻塞。

对于一个多用户数据库系统，尤其是大量用户通过不同应用程序同时访问同一个数据库的系统如果发生一个或多个以下现象，管理员就应该检查是否遇到了阻塞或者死锁了:

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

至于如何才能避免产生严重的阻塞和死锁问题，应该从下面3个方面着手:

* 申请资源的互斥度:如果不同的连接申请的锁都是相互兼容的，那么他们就不会产生阻塞
* 锁的范围和数目的多少:做同样一件事情，SQLSERVER申请的锁的粒度和数目可能会不一样。一个良好设计的程序可以使申请的锁的粒度和数目控制在最小的范围之内。这样，阻塞住别人的可能性就能大大降低
* 事务持有锁资源的时间长短:如果一个锁是大家都需要用的，那么每个人持有他的时间越短，阻塞对性能的影响就会越小。最好是申请得越晚越好，释放得越早越好

为了达到以上3个目的，需要研究一下SQLSERVER的锁资源模式和兼容性，以及他们怎么被申请和释放的。

# 锁资源和兼容性

## 锁粒度和层次结构

下表列出了数据库引擎可以锁定的资源。

| 资源  |      说明     |
| :------------:| :------------: |
|RID|用于锁定堆中的单个行的行标识符。|
|KEY|索引中用于保护可序列化事务中的键范围的行锁。|
|PAGE|数据库中的 8 KB 页，例如数据页或索引页。|
|EXTENT|一组连续的八页，例如数据页或索引页。|
|HoBT|堆或 B 树。 用于保护没有聚集索引的表中的 B 树（索引）或堆数据页的锁。|
|TABLE|包括所有数据和索引的整个表。|
|FILE|数据库文件。|
|APPLICATION|应用程序专用的资源。|
|METADATA|元数据锁。|
|ALLOCATION_UNIT|分配单元。|
|DATABASE|整个数据库。|

## 锁模式

|锁模式|说明|
| :------------:| :------------: |
|共享 (S)|用于不更改或不更新数据的读取操作，如 SELECT 语句。|
|更新 (U)|用于可更新的资源中。 防止当多个会话在读取、锁定以及随后可能进行的资源更新时发生常见形式的死锁。|
|排他 (X)|用于数据修改操作，例如 INSERT、UPDATE 或 DELETE。 确保不会同时对同一资源进行多重更新。|
|意向|用于建立锁的层次结构。 意向锁包含三种类型：意向共享 (IS)、意向排他 (IX) 和意向排他共享 (SIX)。|
|架构|在执行依赖于表架构的操作时使用。 架构锁包含两种类型：架构修改 (Sch-M) 和架构稳定性 (Sch-S)。|
|大容量更新 (BU)|在向表进行大容量数据复制且指定了 TABLOCK 提示时使用。|
|键范围|当使用可序列化事务隔离级别时保护查询读取的行的范围。 确保再次运行查询时其他事务无法插入符合可序列化事务的查询的行。|

### 共享锁
共享锁（S 锁）允许并发事务在封闭式并发控制下读取 (SELECT) 资源。 有关详细信息，请参阅并发控制的类型。 资源上存在共享锁（S 锁）时，任何其他事务都不能修改数据。 读取操作一完成，就立即释放资源上的共享锁（S 锁），除非将事务隔离级别设置为可重复读或更高级别，或者在事务持续时间内用锁定提示保留共享锁（S 锁）。
### 更新锁
更新锁（U 锁）可以防止常见的死锁。 在可重复读或可序列化事务中，此事务读取数据 [获取资源（页或行）的共享锁（S 锁）]，然后修改数据 [此操作要求锁转换为排他锁（X 锁）]。 如果两个事务获得了资源上的共享模式锁，然后试图同时更新数据，则一个事务尝试将锁转换为排他锁（X 锁）。 共享模式到排他锁的转换必须等待一段时间，因为一个事务的排他锁与其他事务的共享模式锁不兼容；发生锁等待。 第二个事务试图获取排他锁（X 锁）以进行更新。 由于两个事务都要转换为排他锁（X 锁），并且每个事务都等待另一个事务释放共享模式锁，因此发生死锁。
若要避免这种潜在的死锁问题，请使用更新锁（U 锁）。 一次只有一个事务可以获得资源的更新锁（U 锁）。 如果事务修改资源，则更新锁（U 锁）转换为排他锁（X 锁）。
### 排他锁
排他锁（X 锁）可以防止并发事务对资源进行访问。 使用排他锁（X 锁）时，任何其他事务都无法修改数据；仅在使用 NOLOCK 提示或未提交读隔离级别时才会进行读取操作。
数据修改语句（如 INSERT、UPDATE 和 DELETE）合并了修改和读取操作。 语句在执行所需的修改操作之前首先执行读取操作以获取数据。 因此，数据修改语句通常请求共享锁和排他锁。 例如，UPDATE 语句可能根据与一个表的联接修改另一个表中的行。 在此情况下，除了请求更新行上的排他锁之外，UPDATE 语句还将请求在联接表中读取的行上的共享锁。
### 意向锁
数据库引擎使用意向锁来保护共享锁（S 锁）或排他锁（X 锁）放置在锁层次结构的底层资源上。 意向锁之所以命名为意向锁，是因为在较低级别锁前可获取它们，因此会通知意向将锁放置在较低级别上。
意向锁有两种用途：
防止其他事务以会使较低级别的锁无效的方式修改较高级别资源。
提高数据库引擎在较高的粒度级别检测锁冲突的效率。
例如，在该表的页或行上请求共享锁（S 锁）之前，在表级请求共享意向锁。 在表级设置意向锁可防止另一个事务随后在包含那一页的表上获取排他锁（X 锁）。 意向锁可以提高性能，因为数据库引擎仅在表级检查意向锁来确定事务是否可以安全地获取该表上的锁。 而不需要检查表中的每行或每页上的锁以确定事务是否可以锁定整个表。
意向锁包括意向共享 (IS)、意向排他 (IX) 以及意向排他共享 (SIX)。

|锁模式|说明|
| :--------------------:| :-----------------: |
|意向共享 (IS)|保护针对层次结构中某些（而并非所有）低层资源请求或获取的共享锁。|
|意向排他 (IX)|保护针对层次结构中某些（而并非所有）低层资源请求或获取的排他锁。 IX 是 IS 的超集，它也保护针对低层级别资源请求的共享锁。
|意向排他共享 (SIX)|保护针对层次结构中某些（而并非所有）低层资源请求或获取的共享锁以及针对某些（而并非所有）低层资源请求或获取的意向排他锁。 顶级资源允许使用并发 IS锁,例如，获取表上的 SIX 锁也将获取正在修改的页上的意向排他锁以及修改的行上的排他锁。 虽然每个资源在一段时间内只能有一个 SIX 锁，以防止其他事务对资源进行更新，但是其他事务可以通过获取表级的 IS 锁来读取层次结构中的低层资源。|
|意向更新 (IU)|保护针对层次结构中所有低层资源请求或获取的更新锁。 仅在页资源上使用 IU 锁。 如果进行了更新操作，IU 锁将转换为 IX 锁。|
|共享意向更新 (SIU)|S 锁和 IU 锁的组合，作为分别获取这些锁并且同时持有两种锁的结果。 例如，事务执行带有 PAGLOCK 提示的查询，然后执行更新操作。 带有 PAGLOCK 提示的查询将获取 S 锁，更新操作将获取 IU 锁。|
|更新意向排他 (UIX)|U 锁和 IX 锁的组合，作为分别获取这些锁并且同时持有两种锁的结果。|

## 锁兼容性

{% asset_img 001.png 锁兼容模式 %}

完整的锁兼容性矩阵

{% asset_img 002.gif 完整的锁兼容性矩阵 %}

## 键范围锁定

[键范围锁定](https://msdn.microsoft.com/zh-cn/library/ms191272.aspx)

# 事务隔离级别和锁释放

数据库有并发操作的时候，修改数据的事务会影响同时要去读取或修改相同数据的其他事务。如果数据存储系统并没有并发控制，则事务可能会看到以下负面影响：
* 丢失更新
* 未提交的依赖关系（脏读）
* 不一致的分析（不可重复读）
* 幻读

上面4种情况的定义可以在SQL联机丛书里找到。当许多人试图同时修改数据库中的数据时，必须实现一个控制系统，使一个人所做的修改不会对他人所做的修改产生负面影响，这就称为并发控制。

需要注意的是，不同性质的应用程序对并发控制会有不一样的需求。例如一个银行ATM系统，可能就不允许不可重复读的出现。而一个报表系统，可能对脏读的敏感度不会那么高。要防止的负面
影响越多，隔离级别就越高，程序的并发性也就越差。并不是每个应用程序都需要将上面4种问题全部避免。

数据库系统通过定义事务的隔离级别来定义使用哪一级的并发控制。SQL-99标准定义了下列隔离级别，SQL数据库引擎支持所有这些隔离级别：
* 未提交读（隔离事务的最低级别，只能保证不读取物理上损坏的数据）
* 已提交读（数据库引擎的默认级别，可以防止脏读）
* 可重复读
* 可序列化（隔离事务的最高级别，可防止幻影，事务之间完全隔离）

表 ：不同隔离级别允许的并发副作用
|隔离级别|               |脏读            |不可重复读                       |幻读|
| :--------------------:| :-----------------: |:-----------------: |:-----------------: |
|未提交读(nolock)        |否                 |是                            |是|  
|已提交读                |否                 |是                            |是|
|可重复读                |否                 |否                            |是|
|可序列化                |否                 |否                            |否|

### 未提交读（read uncommitted）
指定语句可以读取已由其他事务修改但尚未提交的行。也就是说，允许脏读
在read uncommitted级别运行的事务，不会发出共享锁来防止其他事务修改当前事务读取的数据。read committed事务也不会被排他锁阻塞。共享锁会禁止当前事务读取其他事务已修改但尚未提交的行。设置此选项后，此事务可以读取其他事务未提交的修改。在事务结束之前，其他事务可以更改数据中的值。该选项的作用与在事务内所有select语句中的所有表上设置nolock相同。这是隔离级别中限制最少的级别。
换句话说，未提交读的意思也就是：读的时候不申请共享锁。所以他不会被其他人的排他锁阻塞，他也不会阻塞别人申请排他锁

### 已提交读（read committed）
指定语句不能读取已由其他事务修改但尚未提交的数据.这样可以避免脏读。其他事务可以在当前事务的各个语句之间更改数据，从而产生不可重复读取数据和幻象数据。该选项是SQL的默认设置。
数据库引擎会在读的时候使用共享锁防止其他事务在当前事务执行读取操作期间修改行。共享锁还会阻止语句在其他事务完成之前读取由这些事务修改的行。但是，语句运行完毕后便会释放共享锁，而不是等到事务提交的时候但是SQL默认设置是每一语句运行完毕就提交事务。

### 可重复读（repeatable read）
指定语句不能读取已由其他事务修改但尚未提交的行，并且指定，其他任何事务都不能在当前事务完成之前修改由当前事务读取的数据。
在这个隔离级别上，对事务中的每个语句所读取的全部数据都设置了共享锁，并且该共享锁一直保持到事务完成为止。这样可以防止其他事务修改当前事务读取的任何行。其他事务可以插入与当前事务所发出语句的搜索条件相匹配的新行。如果当前事务随后重试执行该语句，他会检索新行，从而产生幻读。
由于共享锁一直保持到事务结束，而不是每个语句结束时释放，所以并发性低于默认的read committed隔离级别。此选项只在必要时使用。

### 可序列化（serializable）
可序列化的要求：
语句不能读取已由其他事务修改但尚未提交的数据。
任何其他事务都不能在当前事务完成之前修改由当前事务读取的数据在当前事务完成之前，其他事务不能使用当前事务中任何语句读取的键值插入新行。
SQL通过加范围锁的方式来实现可序列化。范围锁处于与事务中执行的每个语句的搜索条件相匹配的键值范围之内。这样可以阻止其他事务更新或插入任何行，从而限定当前事务所执行的任何语句。这意味着如果再次执行事务中的任何语句，则这些语句便会读取同一组行。在事务完成之前将一直保持范围锁。
这是限制最多的隔离级别，因为他锁定了键的整个范围，并在事务完成之前一直保持范围锁。因为并发级别最低，所以应只在必要时才使用该选项。该选项的作用与在事务内所有select语句中的所有表上设置holdlock相同。

SQLSERVER其实通过对共享锁申请和释放机制的不同处理，来实现不同事务隔离级别的

不同隔离级别对共享锁的不同处理方式：

|隔离级别            |是否申请共享锁          |何时释放              有无范围锁|
|:--------------------:| :-----------------: |:-----------------: |:-----------------: |
|未提交读                |不申请                |无                    |无|
|已提交读                |申请                  |当前语句做完时         |无|
|可重复读                |申请                  |事务提交时             |无|
|可序列化                |申请                  |事务提交时             |有|

也就是说，事务隔离级别越高，共享锁被持有的时间越长。而可序列化还要申请粒度更高的范围锁，并一直持有到事务结束。所以，如果阻塞发生在共享锁上面，可以通过降低事务隔离级别得到缓解。

需要说明的是，SQL在处理排他锁的时候，4个事务隔离级别都是一样的。都是在修改的时候申请直到事务提交的时候释放（而不是语句结束以后就立即释放）。如果阻塞是发生在排他锁上面，
是不能通过降低事务隔离级别得到缓解的。

# 监视锁申请、持有和释放

{% codeblock lang:sql %}

USE [AdventureWorks2014] --要查询申请锁的数据库
GO
SELECT
[request_session_id],
c.[program_name],
DB_NAME(c.[dbid]) AS dbname,
[resource_type],
[request_status],
[request_mode],
[resource_description],OBJECT_NAME(p.[object_id]) AS objectname,
p.[index_id]
FROM sys.[dm_tran_locks] AS a LEFT JOIN sys.[partitions] AS p
ON a.[resource_associated_entity_id]=p.[hobt_id]
LEFT JOIN sys.[sysprocesses] AS c ON a.[request_session_id]=c.[spid]
WHERE c.[dbid]=DB_ID()
ORDER BY [request_session_id],[resource_type]

{% endcodeblock %}


{% codeblock lang:sql %}
SELECT 
     GETDATE()AS 'current_time', 
     es.session_id, 
     db_name(sp.dbid)AS database_name, 
     es.status, 
     substring((SELECT text
        FROM sys.dm_exec_sql_text(sp.sql_handle)), 1, 128)AS sql_text, 
     es.host_name, 
     es.login_time, 
     es.login_name, 
     es.program_name, 
     Convert(float, Round((IsNull(es.cpu_time, 0.0)/1000.00), 0))AS  cpu_time_in_seconds, 
     Convert(float, Round((IsNull(es.lock_timeout, 0.0)/1000.00), 0))AS lock_timeout_in_seconds, 
     tl.resource_type AS lock_type, 
     tl.request_mode, 
     tl.resource_associated_entity_id, 
     CASE 
       WHEN tl.resource_type = 'OBJECT'
           THEN OBJECT_NAME(tl.resource_associated_entity_id)
       WHEN tl.resource_type IN ('KEY', 'PAGE', 'RID')
            THEN (SELECT object_name(object_id)
                FROM sys.partitions  ps1
                WHERE ps1.hobt_id = tl.resource_associated_entity_id)
       ELSE 'n.a.' 
     END AS object_name, 
     tl.request_status, 
     ec.connect_time, 
     ec.net_transport, 
     ec.client_net_address, 
     er.connection_id, 
     CASE er.blocking_session_id
       WHEN 0  THEN 'Not Blocked'
       WHEN-2 THEN 'Orphaned Distributed Transaction'
       WHEN-3 THEN 'Deferred Recovery Transaction'
       WHEN-4 THEN 'Latch owner not determined'
       ELSE ''
     END AS blocking_type, 
     er.wait_type, 
     Convert(float, Round((IsNull(er.wait_time, 0.0)/1000.00), 0))AS wait_time_in_seconds, 
     er.percent_complete, 
     er.estimated_completion_time, 
     Convert(float, Round((IsNull(er.total_elapsed_time, 0.0)/1000.00), 0))AS total_elapsed_time_in_seconds, 
     CASE er.transaction_isolation_level
       WHEN 0 THEN 'Unspecified'
       WHEN 1 THEN 'ReadUncomitted'
       WHEN 2 THEN 'ReadCommitted'
       WHEN 3 THEN 'Repeatable'
       WHEN 4 THEN 'Serializable'
       WHEN 5 THEN 'Snapshot'
       ELSE ''
     END transaction_isolation_level          
FROM  master.sys.dm_exec_sessions    es
     INNER JOIN master.sys.sysprocesses        sp
        ON sp.spid = es.session_id
      LEFT JOIN master.sys.dm_exec_connections ec
        ON ec.session_id = es.session_id
      LEFT JOIN master.sys.dm_exec_requests    er
        ON er.session_id = es.session_id
      LEFT JOIN master.sys.dm_tran_locks       tl
        ON tl.request_session_id = es.session_id
WHERE  es.session_id <> @@spid
AND es.session_id = es.session_id
AND sp.dbid = db_id()/* CURRENT DB TO MONITOR */
AND tl.resource_type <> 'DATABASE';
{% endcodeblock %}

{% codeblock lang:sql %}
SELECT CASE dtl.request_session_id
		WHEN - 2
			THEN 'orphaned distributed transaction'
		WHEN - 3
			THEN 'deferred recovery transaction'
		ELSE dtl.request_session_id
		END AS spid
	,db_name(dtl.resource_database_id) AS databasename
	,so.NAME AS lockedobjectname
	,dtl.resource_type AS lockedresource
	,dtl.resource_description AS lockedresourceinfo
	,dtl.request_mode AS locktype
	,st.TEXT AS sqlstatementtext
	,es.login_name AS loginname
	,es.host_name AS hostname
	,CASE tst.is_user_transaction
		WHEN 0
			THEN 'system transaction'
		WHEN 1
			THEN 'user transaction'
		END AS user_or_system_transaction
	,at.NAME AS transactionname
	,dtl.request_status
FROM sys.dm_tran_locks dtl
JOIN sys.partitions sp ON sp.hobt_id = dtl.resource_associated_entity_id
JOIN sys.objects so ON so.object_id = sp.object_id
JOIN sys.dm_exec_sessions AS es ON es.session_id = dtl.request_session_id
JOIN sys.dm_tran_session_transactions AS tst ON es.session_id = tst.session_id
JOIN sys.dm_tran_active_transactions at ON tst.transaction_id = at.transaction_id
JOIN sys.dm_exec_connections ec ON ec.session_id = es.session_id
CROSS APPLY sys.dm_exec_sql_text(ec.most_recent_sql_handle) AS st
WHERE resource_database_id = db_id()
ORDER BY dtl.request_session_id
{% endcodeblock %}