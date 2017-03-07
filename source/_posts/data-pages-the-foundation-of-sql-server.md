---
title: SQL Server存储单位:页
categories:
  - knowledge
tags:
  - mssql
  - performance tuning 
date: 2017-03-01 21:53:53            
---

SQL Server 基本存储单位是页，一个页大小为8K。
页分为不同的类型：

<!--more-->

1 Data page 堆表和聚集索引的叶子节点数据
2 Index page	聚集索引的非叶子节点和非聚集索引的所有索引记录
3 Text mixed page	A text page that holds small chunks of LOB values plus internal parts of text tree. These can be shared between LOB values in the same partition of an index or heap.
4 Text tree page	A text page that holds large chunks of LOB values from a single column value.
7 Sort page	排序时所用到的临时页，排序中间操作存储数据用的。
8 GAM page 全局分配映射（Global Allocation Map，GAM）页面 这些页面记录了哪些区已经被分配并用作何种用途。
9 SGAM page	共享全局分配映射（Shared Global Allocation Map，GAM）页面 这些页面记录了哪些区当前被用作混合类型的区，并且这些区需含有至少一个未使用的页面。
10 IAM page  有关每个分配单元中表或索引所使用的区的信息
11 PFS page  有关页分配和页的可用空间的信息
13 boot page 记录了关于数据库的信息，仅存于每个数据库的第9页
15 file header page 记录了关于数据库文件的信息，存于每个数据库文件的第0页
16 DCM page	记录自从上次全备以来的数据改变的页面，以备差异备份
17 BCM page 有关每个分配单元中自最后一条 BACKUP LOG 语句之后的大容量操作所修改的区的信息


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

结果如下：

| PageFID | PagePID | IAMFID | IAMPID | ObjectID  |
| :-----: | :-----: | :----: | :----: | :-------: |
|    1    |   150   |  NULL  |  NULL  | 261575970 |
|    1    |   147   |   1    |  150   | 261575970 |

| IndexID | PartitionNumber |    PartitionID    | iam_chain_type | PageType |
| :-----: | :-------------: | :---------------: | :------------: | :------: |
|    0    |        1        | 72057594040614912 |  In-row data   |    10    |
|    0    |        1        | 72057594040614912 |  In-row data   |    1     |

| IndexLevel | NextPageFID | NextPagePID | PrevPageFID | PrevPagePID |
| :--------: | :---------: | :---------: | :---------: | :---------: |
|    NULL    |      0      |      0      |      0      |      0      |
|     0      |      0      |      0      |      0      |      0      |

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
　　3:输出缓冲区的标题、页面标题(分别输出每一行)，以及行偏移量表;每一行后跟分别列出的它的列值
　　要想看到这些输出的结果，还需要设置DBCC TRACEON(3604)。
可以使用 WITH TABLERESULTS 显示成表格化的数据形式

{% codeblock lang:sql %}
DBCC TRACEON(3604)
DBCC PAGE(InternalStorageFormat,1,41,1) 
GO    
{% endcodeblock %}

结果如下：
{% codeblock lang:sql %}
DBCC 执行完毕。如果 DBCC 输出了错误信息，请与系统管理员联系。
PAGE: (1:147)

BUFFER:
BUF @0x00000001FEEBDEC0
bpage = 0x0000000184E2E000          bhash = 0x0000000000000000          bpageno = (1:147)
bdbid = 16                          breferences = 0                     bcputicks = 0
bsampleCount = 0                    bUse1 = 36342                       bstat = 0xb
blog = 0x215acccc                   bnext = 0x0000000000000000     

PAGE HEADER:
Page @0x0000000184E2E000
m_pageId = (1:147)                  m_headerVersion = 1                 m_type = 1
m_typeFlagBits = 0x0                m_level = 0                         m_flagBits = 0x8000
m_objId (AllocUnitId.idObj) = 121   m_indexId (AllocUnitId.idInd) = 256 
Metadata: AllocUnitId = 72057594045857792                                
Metadata: PartitionId = 72057594040614912                                Metadata: IndexId = 0
Metadata: ObjectId = 261575970      m_prevPage = (0:0)                  m_nextPage = (0:0)
pminlen = 221                       m_slotCnt = 1                       m_freeCnt = 7870
m_freeData = 320                    m_reservedCnt = 0                   m_lsn = (34:364:23)
m_xactReserved = 0                  m_xdesId = (0:0)                    m_ghostRecCnt = 0
m_tornBits = 0                      DB Frag ID = 1                      

Allocation Status
GAM (1:2) = ALLOCATED               SGAM (1:3) = ALLOCATED              
PFS (1:1) = 0x61 MIXED_EXT ALLOCATED  50_PCT_FULL                        DIFF (1:6) = CHANGED
ML (1:7) = NOT MIN_LOGGED           

Slot 0 Offset 0x60 Length 224
Record Type = PRIMARY_RECORD        Record Attributes =  NULL_BITMAP    Record Size = 224
Memory Dump @0x0000000011C7A060
0000000000000000:   1000dd00 576f6f64 79202020 20202020 20202020  ....Woody           
0000000000000014:   20202020 20202020 20202020 20202020 20202020                      
0000000000000028:   20202020 20202020 20202020 20205475 20202020                Tu    
000000000000003C:   20202020 20202020 20202020 20202020 20202020                      
0000000000000050:   20202020 20202020 20202020 20202020 20202020                      
0000000000000064:   20202020 5a554f51 49414f20 594f5558 4920544f      ZUOQIAO YOUXI TO
0000000000000078:   574e204c 494e4841 49204349 54592020 20202020  WN LINHAI CITY      
000000000000008C:   20202020 20202020 20202020 20202020 20202020                      
00000000000000A0:   20202020 20202020 20202020 20202020 20202020                      
00000000000000B4:   20202020 20202020 20202020 20202020 20202020                      
00000000000000C8:   20202020 30303030 20010000 001480a7 0091a400      0000 ...........
00000000000000DC:   00060000                                      ....   
Slot 0 Column 1 Offset 0x4 Length 50 Length (physical) 50
FirstName = Woody
Slot 0 Column 2 Offset 0x36 Length 50 Length (physical) 50
LastName = Tu 
Slot 0 Column 3 Offset 0x68 Length 100 Length (physical) 100
Address = ZUOQIAO YOUXI TOWN LINHAI CITY  
Slot 0 Column 4 Offset 0xcc Length 5 Length (physical) 5
ZipCode = 0000 
Slot 0 Column 5 Offset 0xd1 Length 4 Length (physical) 4
Rating = 1   
Slot 0 Column 6 Offset 0xd5 Length 8 Length (physical) 8
ModifiedDate = 2015-05-07 10:09:51.000  

OFFSET TABLE:
Row - Offset                        
0 (0x0) - 96 (0x60)  

DBCC 执行完毕。如果 DBCC 输出了错误信息，请与系统管理员联系。

{% endcodeblock %}


Page @0x08F84000            同BUFFER中的bpage地址
m_pageId = (1:79)              数据页号     
m_headerVersion = 1         头文件版本号，一直为1          
m_type = 1                          页面类型，1为数据页面
m_typeFlagBits = 0x4         数据页和索引页为4，其他页为0        
m_level = 0                         该页在索引页（B树）中的级数
m_flagBits = 0x8000          页面标志
m_objId (AllocUnitId.idObj) = 46                       同Metadata: ObjectId             
m_indexId (AllocUnitId.idInd) = 256                  同Metadata: IndexId
Metadata: AllocUnitId = 72057594040942592  存储单元的ID,sys.allocation_units.allocation_unit_id   
Metadata: PartitionId = 72057594039304192   数据页所在的分区号，sys.partitions.partition_id                             
Metadata: IndexId = 0                                        页面的索引号，sys.objects.object_id&sys.indexes.index_id
Metadata: ObjectId = 277576027                      该页面所属的对象的id，sys.objects.object_id
m_prevPage = (0:0)                  该数据页的前一页面；主要用在数据页、索引页和IAM页
m_nextPage = (0:0)                  该数据页的后一页面；主要用在数据页、索引页和IAM页
pminlen = 221                          定长数据所占的字节数
m_slotCnt = 2                           页面中的数据的行数
m_freeCnt = 7644                    页面中剩余的空间
m_freeData = 544                    从第一个字节到最后一个字节的空间字节数
m_reservedCnt = 0                   活动事务释放的字节数
m_lsn = (255:8406:2)                日志记录号
m_xactReserved = 0                 最新加入到m_reservedCnt领域的字节数
m_xdesId = (0:0)                       添加到m_reservedCnt的最近的事务id
m_ghostRecCnt = 0                 幻影数据的行数
m_tornBits = 0                         页的校验位或者被由数据库页面保护形式决定分页保护位取代


GAM (1:2) = ALLOCATED                                                   在GAM页上的分配情况
SGAM (1:3) = ALLOCATED                                                 在SGAM页上的分配情况
PFS (1:1) = 0x61 MIXED_EXT ALLOCATED  50_PCT_FULL 在PFS页上的分配情况，该页为50%满，                       
DIFF (1:6) = CHANGED
ML (1:7) = NOT MIN_LOGGED   

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