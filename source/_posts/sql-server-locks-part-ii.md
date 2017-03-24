---
title: sql server 锁(2)
categories:
  - knowledge
tags:
  - mssql
  - lock
date: 2017-03-24 14:23:54
---

继续学习sql server锁.

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

# 实际查询中锁的申请与释放

## SELECT

## UPDATE

## DELETE

## INSERT