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

## UPDATE

## DELETE

## INSERT