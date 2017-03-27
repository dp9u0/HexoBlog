---
title: sql server 锁(2)
categories:
  - knowledge
tags:
  - mssql
  - lock
date: 2017-03-24 14:23:54
---

继续学习锁。

<!--more-->


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


# 监视锁申请、持有和释放

该语句可以查看当前锁申请、持有等情况：

{% codeblock lang:sql %}

SELECT 
     GETDATE()AS 'current_time' 
	 --回话id
	 ,CASE es.session_id
        WHEN -2 THEN 'Orphaned Distributed Transaction'
        WHEN -3 THEN 'Deferred Recovery Transaction'
		ELSE es.session_id
	 END AS spid
	 --锁资源情况
     ,db_name(sp.dbid)AS database_name 
	 ,CASE 
       WHEN tl.resource_type = 'OBJECT'
           THEN OBJECT_NAME(tl.resource_associated_entity_id)
       WHEN tl.resource_type IN ('KEY', 'PAGE', 'RID')
            THEN (SELECT object_name(object_id)
                FROM sys.partitions AS ps1
                WHERE ps1.hobt_id = tl.resource_associated_entity_id)
       ELSE '' 
     END AS lock_object_name
	 ,tl.resource_type AS lock_resource 
     ,tl.request_mode AS lock_mode 
     ,tl.resource_associated_entity_id AS lock_resource_id
	 ,tl.resource_description AS lock_resource_info
	 ,tl.request_status AS lock_status 
	 --回话信息
	 --,es.status AS session_status     
     --,es.host_name
     --,es.login_time
     --,es.login_name
     --,es.program_name
	 --,CONVERT(float, ROUND((ISNULL(es.cpu_time, 0.0)/1000.00), 0))AS  cpu_time
     --,CONVERT(float, ROUND((ISNULL(es.lock_timeout, 0.0)/1000.00), 0))AS lock_timeout
	 --事务信息
	 ,tat.name AS trans_name
	 ,CASE tst.is_user_transaction
		WHEN 0
			THEN 'system'
		WHEN 1
			THEN 'user'
		END AS trans_type
	 ,substring((SELECT text
        FROM sys.dm_exec_sql_text(sp.sql_handle)), 1, 128) AS sql_text 
	 ,CASE er.transaction_isolation_level
       WHEN 0 THEN 'Unspecified'
       WHEN 1 THEN 'Read Uncomitted'
       WHEN 2 THEN 'Read Committed'
       WHEN 3 THEN 'Repeatable'
       WHEN 4 THEN 'Serializable'
       WHEN 5 THEN 'Snapshot'
       ELSE ''
     END transaction_isolation_level
	 --连接信息
     --,er.connection_id
     ,CASE er.blocking_session_id
       WHEN -2 THEN 'Orphaned Distributed Transaction'
       WHEN -3 THEN 'Deferred Recovery Transaction'
       WHEN -4 THEN 'Latch Owner Not Determined'
       ELSE er.blocking_session_id
     END AS blocking_by
     ,er.wait_type
     --,CONVERT(float, ROUND((ISNULL(er.wait_time, 0.0)/1000.00), 0))AS wait_time
     --,er.percent_complete
     --,er.estimated_completion_time
     --,CONVERT(float, ROUND((ISNULL(er.total_elapsed_time, 0.0)/1000.00), 0))AS total_elapsed_time
     --,ec.connect_time
     --,ec.net_transport
     --,ec.client_net_address
FROM  master.sys.dm_exec_sessions AS es
INNER JOIN master.sys.sysprocesses AS sp 
ON sp.spid = es.session_id
LEFT JOIN master.sys.dm_exec_connections AS ec 
ON ec.session_id = es.session_id
LEFT JOIN master.sys.dm_exec_requests AS er 
ON er.session_id = es.session_id
LEFT JOIN master.sys.dm_tran_locks AS tl 
ON tl.request_session_id = es.session_id		
LEFT JOIN master.sys.dm_tran_session_transactions AS tst 
ON es.session_id = tst.session_id
LEFT JOIN master.sys.dm_tran_active_transactions AS tat 
ON tst.transaction_id = tat.transaction_id
WHERE spid <> @@spid/* IGNORE CURRENT SESSION */
AND sp.dbid = db_id()/* CURRENT DB TO MONITOR */
ORDER BY spid,database_name,lock_object_name,lock_resource


{% endcodeblock %}

# 实际查询中锁的申请与释放

## SELECT

### 实验1

{% codeblocl lang:sql%}

--select动作要申请的锁(1)
--聚集表

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ 
--REPEATABLE READ  会一直持有S锁 直到事务结束
GO
SET STATISTICS PROFILE ON
GO

BEGIN TRAN select_from_btree_1
SELECT
[EmployeeID],
[LoginID],
[Title]
FROM [dbo].[Employee_Demo_BTree]
WHERE [EmployeeID]=3

--COMMIT TRAN
--ROLLBACK

--1-- DATABASE,,S,	
--2-- Employee_Demo_BTree,OBJECT,IS  
--3-- Employee_Demo_BTree,KEY,S,(98ec012aa510)
--4-- Employee_Demo_BTree,PAGE,IS,1:24345 

--1.因为连接正在访问数据库[AdventureWorks],所以在数据库一级加了一个共享锁,以防止别人将数据库删除
--2.因为正在访问表格[Employee_Demo_BTree]，所以在表格上加了一个意向共享锁,以防止别人修改表的定义
--3.查询有1条记录返回,所以在这1条记录所在的聚集索引键上,持有一个共享锁。
--4.在这个聚集索引键所在的页(因为是聚集索引,因此键所在的叶子是数据页)上持有一个意向共享锁

{% endcodeblock %}

### 实验2

{% codeblocl lang:sql%}

--select动作要申请的锁(2)
--堆表

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ 
--REPEATABLE READ  会一直持有S锁 直到事务结束
GO
SET STATISTICS PROFILE ON
GO

BEGIN TRAN select_from_heap_2
SELECT
[EmployeeID],
[LoginID],
[Title]
FROM [dbo].[Employee_Demo_Heap]
WHERE [EmployeeID]=3

--COMMIT TRAN
--ROLLBACK

--1-- ,DATABASE,S,
--2-- Employee_Demo_Heap,OBJECT,IS,
--3-- Employee_Demo_Heap,KEY,S,(99944d58347a) 
--4-- Employee_Demo_Heap,RID,S,1:24344:2
--5-- Employee_Demo_Heap,PAGE,IS,1:24353 
--6-- Employee_Demo_Heap,PAGE,IS,1:24344 

--1.因为连接正在访问数据库[AdventureWorks],所以在数据库一级加了一个共享锁,以防止别人将数据库删除
--2.因为正在访问表格[Employee_Demo_Heap]，所以在表格上加了一个意向共享锁,以防止别人修改表的定义
--3-4.通过非聚集键找到数据RID,再通过RID查找到数据（即书签查找  bookmark lookup）,因此对这个非聚集索引键和数据的RID分别持有一个共享锁
--5-6.Key和RID(数据页)所在的页面上分别持有一个IS锁。   

{% endcodeblock %}

### 实验3

{% codeblocl lang:sql%}

--select动作要申请的锁(3)
--聚集表

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
--REPEATABLE READ  会一直持有S锁 直到事务结束
GO
SET STATISTICS PROFILE ON
GO

BEGIN TRAN select_from_btree_3

SELECT [EmployeeID],[LoginID],[Title]
FROM [dbo].[Employee_Demo_BTree] 
WHERE [EmployeeID] IN(3,30,200)

--COMMIT TRAN
--ROLLBACK

--1-- ,DATABASE,S,
--2-- Employee_Demo_BTree,OBJECT,IS,    
--3-- Employee_Demo_BTree,KEY,S,(98ec012aa510)   
--4-- Employee_Demo_BTree,KEY,S,(af5579654878)    
--5-- Employee_Demo_BTree,KEY,S,(8034b699f2c9)    
--6-- Employee_Demo_BTree,PAGE,IS,1:24183           
--7-- Employee_Demo_BTree,PAGE,IS,1:24345 

--1.因为连接正在访问数据库[AdventureWorks],所以在数据库一级加了一个共享锁,以防止别人将数据库删除
--2.因为正在访问表格[Employee_Demo_BTree]，所以在表格上加了一个意向共享锁,以防止别人修改表的定义
--3-5.查询有3条记录返回,所以在这3条记录所在的聚集索引键上,分别持有一个共享锁。
--6-7.在这3个数据分布在2个页上,在两个页上分别持有一个意向共享锁  

{% endcodeblock %}

### 实验4

{% codeblocl lang:sql%}
--select动作要申请的锁(4)
--堆表

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
--REPEATABLE READ  会一直持有S锁 直到事务结束
GO
SET STATISTICS PROFILE ON
GO
SET STATISTICS IO ON
GO

BEGIN TRAN select_from_heap_4

SELECT [EmployeeID],[LoginID],[Title]
FROM [dbo].[Employee_Demo_Heap] --with (index (PK_Employee_EmployeeID_Demo_Heap))
WHERE [EmployeeID] IN(3,30,200)

--COMMIT TRAN
--ROLLBACK

--1-- ,DATABASE,S,                 
--2-- Employee_Demo_Heap,OBJECT,IS,                 
--3-- Employee_Demo_Heap,PAGE,IS,1:24360           
--4-- Employee_Demo_Heap,PAGE,IS,1:24359         
--5-- Employee_Demo_Heap,PAGE,IS,1:24358          
--6-- Employee_Demo_Heap,PAGE,IS,1:24357          
--7-- Employee_Demo_Heap,PAGE,IS,1:24356          
--8-- Employee_Demo_Heap,PAGE,IS,1:24355          
--9-- Employee_Demo_Heap,PAGE,IS,1:24344          
--10--Employee_Demo_Heap,RID,S,1:24344:29         
--11--Employee_Demo_Heap,RID,S,1:24358:16       
--12--Employee_Demo_Heap,RID,S,1:24344:2       

--1.因为连接正在访问数据库[AdventureWorks],所以在数据库一级加了一个共享锁,以防止别人将数据库删除
--2-9.查询计划分析后发现 Index Seek（9次逻辑读 --with (index (PK_Employee_EmployeeID_Demo_Heap))）开销比 Table Scan(7次逻辑读) 大,因此决定使用 Table Scan,因此在所有页面上添加IS
--10-12 读取到的数据RID加S锁

{% endcodeblock %}

### 实验5

{% codeblocl lang:sql%}

--会话1

BEGIN TRAN update_heap_5

UPDATE [dbo].[Employee_Demo_Heap]
SET [Title]='aaa'
WHERE [EmployeeID]=70

--COMMIT TRAN
--ROLLBACK

--会话2
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ 
--REPEATABLE READ  会一直持有S锁 直到事务结束
GO
SET STATISTICS PROFILE ON
GO
SET STATISTICS IO ON
GO

BEGIN TRAN select_from_heap_5

SELECT [EmployeeID],[LoginID],[Title]
FROM [dbo].[Employee_Demo_Heap] 
WHERE [EmployeeID] IN(3,80,200)

--COMMIT TRAN
--ROLLBACK

--,DATABASE,S,                  
--Employee_Demo_Heap,OBJECT,IS,                
--Employee_Demo_Heap,PAGE,IS,1:24344           
--Employee_Demo_Heap,PAGE,IS,1:24360           
--Employee_Demo_Heap,PAGE,IS,1:24359           
--Employee_Demo_Heap,PAGE,IS,1:24358           
--Employee_Demo_Heap,PAGE,IS,1:24357           
--Employee_Demo_Heap,PAGE,IS,1:24356            
--Employee_Demo_Heap,PAGE,IS,1:24355            
--Employee_Demo_Heap,RID,S,1:24355:32        
--Employee_Demo_Heap,RID,S,1:24358:16        
--Employee_Demo_Heap,RID,S,1:24344:2   

--Table Scan 时候会逐个获取 RID 的 S 锁 但是 Update 持有了 ID=70的 X锁
--因此select 会被阻塞
--但是当获取到ID=70的锁后 发现不需要返回该数据 
--因此会释放ID-70的数据的S锁

{% endcodeblock %}

### 实验6

{% codeblocl lang:sql%}

--会话1
BEGIN TRAN update_heap_6

UPDATE [dbo].[Employee_Demo_BTree]
SET [Title]='aaa'
WHERE [EmployeeID]=70

--COMMIT TRAN
--ROLLBACK

--会话2

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ 
--REPEATABLE READ  会一直持有S锁 直到事务结束
GO
SET STATISTICS PROFILE ON
GO
SET STATISTICS IO ON
GO

BEGIN TRAN select_from_beetree_6

SELECT [EmployeeID],[LoginID],[Title]
FROM [dbo].[Employee_Demo_BTree] 
WHERE [EmployeeID] IN(3,80,200)

--COMMIT TRAN
--ROLLBACK

--使用Clustered Index Seek 不会扫描到 不需要的数据（例如ID=70） 因此不会被Update 阻塞

--,DATABASE,S,                  
--Employee_Demo_BTree,KEY,S,(98ec012aa510)    
--Employee_Demo_BTree,KEY,S,(af5579654878)    
--Employee_Demo_BTree,KEY,S,(d2e40430031e)  
--Employee_Demo_BTree,OBJECT,IS,                 
--Employee_Demo_BTree,PAGE,IS,1:24183          
--Employee_Demo_BTree,PAGE,IS,1:24178          
--Employee_Demo_BTree,PAGE,IS,1:24345          

{% endcodeblock %}

### 总结

* 查询在运行过程中，会对每一条读到的记录或键值加共享锁。如果记录不用返回。那锁就会被释放。如果记录需要被返回，则视隔离级别而定，如果是“已提交读”，则也释放否则，不释放
* 对每一个使用到的索引，SQL也会对上面的键值加共享锁
* 对每个读过的页面，SQL会加一个意向锁
* 查询需要扫描页面和记录越多，锁的数目也会越多。查询用到的索引越多，锁的数目也会越多

当然，这些对于“已提交读”以上隔离级别而言。如果使用“未提交读”，SQL就不会申请这些共享锁阻塞也不会发生

避免阻塞采取的方法
* 尽量返回少的记录集，返回的结果越多，需要的锁也就越多
* 如果返回结果集只是表格所有记录的一小部分，要尽量使用index seek，避免全表扫描这种执行计划
* 可能的话，设计好合适的索引，避免SQL通过多个索引才找到数据

## UPDATE

### 实验1

{% codeblocl lang:sql%}
--UPDATE动作要申请的锁(1)

USE [AdventureWorks] 
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
GO

BEGIN TRAN update_1
UPDATE [dbo].[Employee_Demo_Heap]
SET [Title]='changehea1213412p'
WHERE [EmployeeID] IN(3,30,200)

--COMMIT TRAN
--ROLLBACK

--从这个例子可以看出，如果update借助了哪个索引，这个索引的键值上就会有U锁,没有用到的索引上没有锁。

--,DATABASE,S, 
--Employee_Demo_Heap,OBJECT,IX,                   
--Employee_Demo_Heap,KEY,U,(76bc6173e51d)   
--Employee_Demo_Heap,KEY,U,(ec8f0458157e)    
--Employee_Demo_Heap,KEY,U,(8d9ce4e03eca) 
--Employee_Demo_Heap,PAGE,IU,1:24190          
--Employee_Demo_Heap,RID,X,1:24188:29       
--Employee_Demo_Heap,RID,X,1:24374:16        
--Employee_Demo_Heap,RID,X,1:24188:2                                               
--Employee_Demo_Heap,PAGE,IX,1:24188            
--Employee_Demo_Heap,PAGE,IX,1:24374 

--在非聚集索引上申请了3个U锁这 通过非聚集索引PK_Employee_EmployeeID_Demo_Heap（index_id是2）找到了这3条记录
--在RID上申请了3个X锁。数据RID上有了修改，所以RID上加的是X锁，其他索引上没有加锁
--对于查询涉及的页面，SQL加了IU锁意向更新锁，修改发生的页面，SQL加了IX锁 意向排他锁 （先查询再修改）锁key 锁索引键值 因为修改的列没有被索引  

{% endcodeblock %}

### 实验2

{% codeblocl lang:sql%}

--UPDATE动作要申请的锁(2)

--DROP INDEX [Employee_Demo_BTree_Title]  ON [AdventureWorks].[dbo].[Employee_Demo_BTree]

USE [AdventureWorks]
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
GO
BEGIN TRAN update_2
UPDATE [dbo].[Employee_Demo_BTree]
SET [Title]='changeheap'
WHERE [EmployeeID] IN(3,30,200)

--COMMIT TRAN
--ROLLBACK

--,DATABASE,S,                 
--Employee_Demo_BTree,KEY,X,(98ec012aa510)   
--Employee_Demo_BTree,KEY,X,(af5579654878)   
--Employee_Demo_BTree,KEY,X,(8034b699f2c9)    
--Employee_Demo_BTree,OBJECT,IX,                 
--Employee_Demo_BTree,PAGE,IX,1:24183           
--Employee_Demo_BTree,PAGE,IX,1:24361 

{% endcodeblock %}

### 实验3

{% codeblocl lang:sql%}

--UPDATE动作要申请的锁(3)

--如果修改的列被一个索引使用到了，会是什么情况呢？为了完成这个测试，先在Employee_Demo_BTree
--上建一个会被修改的索引
--CREATE NONCLUSTERED INDEX [Employee_Demo_BTree_Title] ON [AdventureWorks].[dbo].[Employee_Demo_BTree]([Title] ASC)

--再运行下面语句
USE [AdventureWorks]
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
GO
BEGIN TRAN update_3
UPDATE [dbo].[Employee_Demo_BTree]
SET [Title]='changeheap'
WHERE [EmployeeID] IN(3,30,200)

--COMMIT TRAN
--ROLLBACK

--,DATABASE,S,    
--Employee_Demo_BTree,OBJECT,IX,               
--Employee_Demo_BTree,KEY,X,(e1ec96b5ebdf)   
--Employee_Demo_BTree,KEY,X,(3257b8d72bb6)    
--Employee_Demo_BTree,KEY,X,(dfeed147c0d9)   
--Employee_Demo_BTree,KEY,X,(7cf149949204)    
--Employee_Demo_BTree,KEY,X,(e857a9082db1)   
--Employee_Demo_BTree,KEY,X,(c73666f49700)   
--Employee_Demo_BTree,KEY,X,(98ec012aa510)   
--Employee_Demo_BTree,KEY,X,(af5579654878)  
--Employee_Demo_BTree,KEY,X,(8034b699f2c9)
--Employee_Demo_BTree,PAGE,IX,1:24183           
--Employee_Demo_BTree,PAGE,IX,1:24361          
--Employee_Demo_BTree,PAGE,IX,1:24382           
--Employee_Demo_BTree,PAGE,IX,1:24379           
--Employee_Demo_BTree,PAGE,IX,1:24377       

--语句利用聚集索引找到要修改的3条记录.但是我们看到有9个键上有X锁。
--很有意思：PK_Employee_EmployeeID_Demo_BTree（index_id=1）聚集索引，也是数据存放的地方。
--UPDATE_2做的update语句没有改到他的索引列，他只需把Title这个列的值改掉。所以在index1上，只申请3个X锁，每条记录一个
--但是表格在Title上面有一个非聚集索引IX_Employee_ManagerID_Demo_BTree（index_id=5）,并且Title是第一列。他被修改后，原来的索引键值就要被删除掉，并且插入新的键值。
--所以在index_id=5 上要申请6个X锁，老的键值3个，新的键值3个

{% endcodeblock %}

### 总结

对于update语句，可以简单理解为SQL先做查询，把需要修改的记录给找到，然后在这个记录上做修改。找记录的动作要加S锁，找到修改的记录后加U锁，再将U锁升级为X锁。加锁的位置是 RID(堆表)或者CLUSTER_INDEX(聚集表)

想降低一个update语句被别人阻塞住的几率，除了注意他的查询部分之外，还要做的事情有：

* 尽量修改少的记录集。修改的记录越多，需要的锁也就越多
* 尽量减少无谓的索引。索引的数目越多，需要的锁也可能越多
* 但是也要严格避免表扫描的发生。如果只是修改表格记录的一小部分，要尽量使用index seek索引查找避免全表扫描这种执行计划

## DELETE

### 实验1

{% codeblocl lang:sql%}

--delete动作要申请的锁（1）

USE [AdventureWorks]
BEGIN TRAN delete_1
DELETE [dbo].[Employee_Demo_BTree]
WHERE [LoginID]='adventure-works\kim1'

--COMMIT TRAN
--ROLLBACK

--,DATABASE,S,                                                                                                        
--Employee_Demo_BTree,OBJECT,IX,                
--Employee_Demo_BTree,KEY,X,(a8fc9de67ccb)   
--Employee_Demo_BTree,KEY,X,(ad818e966dc0)   
--Employee_Demo_BTree,KEY,X,(38fd2d9689b5)            
--Employee_Demo_BTree,PAGE,IX,1:24361           
--Employee_Demo_BTree,PAGE,IX,1:24365  

--可以看到delete语句在聚集索引（index_id=1）和两个非聚集索引（index_id=2和3）上各申请了一个X锁在
--所在的页面上申请了一个IX锁

{% endcodeblock %}

### 实验2

{% codeblocl lang:sql%}

--delete动作要申请的锁（2）

USE [AdventureWorks]
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
GO

BEGIN TRAN  delete_2
DELETE [dbo].[Employee_Demo_Heap]
WHERE [LoginID]='adventure-works\tete0'

--COMMIT TRAN
--ROLLBACK

--,DATABASE,S,                 
--Employee_Demo_Heap,KEY,X,(a9c8ddfb091b)    
--Employee_Demo_Heap,KEY,X,(85b6a54957a8)    
--Employee_Demo_Heap,KEY,X,(c8fabd8e786b)     
--Employee_Demo_Heap,OBJECT,IX,                 
--Employee_Demo_Heap,PAGE,IX,1:24360           
--Employee_Demo_Heap,PAGE,IX,1:24369           
--Employee_Demo_Heap,PAGE,IU,1:24188          
--Employee_Demo_Heap,PAGE,IX,1:24376          
--Employee_Demo_Heap,PAGE,IU,1:24375            
--Employee_Demo_Heap,PAGE,IU,1:24374           
--Employee_Demo_Heap,PAGE,IU,1:24373          
--Employee_Demo_Heap,PAGE,IU,1:24372           
--Employee_Demo_Heap,PAGE,IU,1:24371          
--Employee_Demo_Heap,PAGE,IX,1:24190          
--Employee_Demo_Heap,RID,X,1:24376:2

--可以看到delete语句在3个非聚集索引（index_id=2、3、4）上各申请了一个X锁。
--在所在的页面上申请了一个IX锁。
--在修改发生的heap数据页面上，申请了一个IX锁，相应的RID上（真正的数据记录）申请了一个X锁。

--如果使用repeatable read这个级别运行上面的delete命令，就能看出好像做select的时候一样，做delete的时候SQL也需要先找到要删除的记录。
--在找的过程中也会加锁,描过的页面申请IU锁

{% endcodeblock %}

### 总结

* delete的过程是先找到记录，然后做删除。可以理解为先是一个select,然后是delete.所以,如果有合适的索引,第一步申请的锁就会比较少,不用表扫描
* delete不但是把数据行本身删除,还要删除所有相关的索引键.所以一张表上索引数目越多锁的数目就会越多,也就越容易发生阻塞

为了防止阻塞,我们既不能绝对地不建索引,也不能随随便便地建立很多索引,而是要建立对查找有利的索引.对于没有使用到的索引,还是去掉比较好

## INSERT

### 实验1

{% codeblocl lang:sql%}

--INSERT 要申请的锁（1）

USE [AdventureWorks]
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
GO
BEGIN TRAN
INSERT INTO [dbo].[Employee_Demo_Heap]
        ( [EmployeeID] ,
          [NationalIDNumber] ,
          [ContactID] ,
          [LoginID] ,
          [ManagerID] ,
          [Title] ,
          [BirthDate] ,
          [MaritalStatus] ,
          [Gender] ,
          [HireDate] ,
          [ModifiedDate]
        )
SELECT
501,
480168528,
1009,
'adventure-works\thierry0',
263,
'Tool Desinger',
'1949-08-29 00:00:00.000',
'M',
'M',
'1998-01-11 00:00:00.000',
'2004-07-31 00:00:00.000'

--COMMIT TRAN
--ROLLBACK

--,DATABASE,S,    
--Employee_Demo_Heap,OBJECT,IX,                 
--Employee_Demo_Heap,KEY,X,(2b4f69bdcc15)   
--Employee_Demo_Heap,KEY,X,(82704d2b820e)    
--Employee_Demo_Heap,KEY,X,(6317a951a3c2)            
--Employee_Demo_Heap,PAGE,IX,1:24190           
--Employee_Demo_Heap,PAGE,IX,1:24360          
--Employee_Demo_Heap,PAGE,IX,1:24369            
--Employee_Demo_Heap,RID,X,1:24376:9
--Employee_Demo_Heap,PAGE,IX,1:24376   

--（1）数据库上的S锁（resource_type=DATABASE）
--（2）表上的IX锁（resource_type=OBJECT）
--（3）每个索引上都要插入一条新数据，所以有一个key上的X锁
--（4）在每个索引上发生变化的那个页面，申请了一个IX锁（resource_type=PAGE）
--（5）RID锁。因为真正的数据不是放在索引上，而是放在heap数据页面上
-- (6) RID 所在页面（24376）：IX锁

{% endcodeblock %}

### 实验2

{% codeblocl lang:sql%}

--INSERT 要申请的锁（2）

USE [AdventureWorks]
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
GO
BEGIN TRAN
INSERT INTO [dbo].[Employee_Demo_BTree]
        ( [EmployeeID] ,
          [NationalIDNumber] ,
          [ContactID] ,
          [LoginID] ,
          [ManagerID] ,
          [Title] ,
          [BirthDate] ,
          [MaritalStatus] ,
          [Gender] ,
          [HireDate] ,
          [ModifiedDate]
        )
SELECT
501,
480168528,
1009,
'adventure-works\thierry0',
263,
'Tool Desinger',
'1949-08-29 00:00:00.000',
'M',
'M',
'1998-01-11 00:00:00.000',
'2004-07-31 00:00:00.000'

--COMMIT TRAN
--ROLLBACK

--,DATABASE,S,
--Employee_Demo_BTree,OBJECT,IX,           
--Employee_Demo_BTree,KEY,X,(3937e7935c85)   
--Employee_Demo_BTree,KEY,X,(fa64829c6a59)   
--Employee_Demo_BTree,KEY,X,(7e98e1db48bd)                 
--Employee_Demo_BTree,PAGE,IX,1:24365           
--Employee_Demo_BTree,PAGE,IX,1:24187          
--Employee_Demo_BTree,PAGE,IX,1:24363

--（1）数据库上的S锁（resource_type=DATABASE）
--（2）表上的IX锁（resource_type=OBJECT）
--（3）每个索引上都要插入一条新数据，所以有一个key上的X锁
--（4）在每个索引上发生变化的那个页面，申请了一个IX锁（resource_type=PAGE）

{% endcodeblock %}

### 总结

相对于select,update,delete，单条记录的insert操作对锁的申请比较简单。SQL会为新插入的数据本身申请一个X锁，在发生变化的页面上申请一个IX锁。由于这条记录是新插入的，被其他连接引用到的概率会相对小一些，所以出现阻塞的几率也要小