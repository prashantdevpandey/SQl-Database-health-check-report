#################################################################################  

## MSSQL Database Health Check Status Report

## Created by Prashant Dev Pandey  

## Date : 25 OCT 2016  

## Version : 1.0  

## Email: pdppandey@hotmail.com    

## This scripts check the SQL Services ,No of Users,Buffer cache hit ratio  

## SQL Services ,No of Users,Buffer cache hit ratio in a HTML format at C:\scripts folder. 

################################################################################ 

$htmlreport += "<style>TABLE{ border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;align:center;margin-left:auto; margin-right:auto;width:100%}
TH{border-width: 1px;bgcolor=#FF0000;padding: 3px;border-style: solid;border-color: black;background-color:darkgray;}
TD{border-width: 1px;padding: 3px;border-style: solid;border-color: black;} 
h1{text-shadow: 1px 1px 1px #000,3px 3px 5px blue; text-align: center;font-style: calibri;font-family: Calibri;}
</style>"


$hostname=hostname


$services=Get-Service -Exclude "*ysql*","*esql*" -Include "*SQL*"| Where-Object{$_.DisplayName -like "*SQL*"}| select Status, Name, DisplayName |ConvertTo-Html -fragment 



$reportbuffer=""

$reportbuffer +="<table border=1 width=100%>"
$reportbuffer +="<tr bgcolor=gray><th>DB NAME</th><th>DB_BUFFER_PAGES</th><th>DB_BUFFER_MB</th><th>DB_BUFFER_PERCENT</th></tr>"
$buffer=sqlcmd -E -S .\SQLTEST -dmaster -Q "set nocount on;DECLARE @total_buffer INT;SELECT @total_buffer = cntr_value FROM sys.dm_os_performance_counters WHERE RTRIM([object_name]) LIKE '%Buffer Manager'
AND counter_name = 'Database Pages';;WITH src AS (SELECT database_id, db_buffer_pages = COUNT_BIG(*) FROM sys.dm_os_buffer_descriptors
GROUP BY database_id )SELECT[db_name] = CASE [database_id] WHEN 32767 THEN 'Resource DB' ELSE DB_NAME([database_id]) END,db_buffer_pages,db_buffer_MB = db_buffer_pages / 128,
db_buffer_percent = CONVERT(DECIMAL(6,3), db_buffer_pages * 100.0 / @total_buffer) FROM src ORDER BY db_buffer_MB DESC;" -h -1 -s"*" -W
foreach ($i in $buffer) {$reportbuffer+="<tr><td>"+$i.split("*")[0]+"</td><td>"+$i.split("*")[1]+"</td><td>"+$i.split("*")[2]+"</td><td>"+$i.split("*")[3]+"</td></tr>" }
$reportbuffer+="</table>"


$reporlogin=""
#$reportbuffer +="<h1 align=center><B><U>SQL ERROR LOG STATUS</U></B></H1>"
$reporlogin +="<table border=1 width=100%>"
$reporlogin +="<tr bgcolor=gray><th>LOGIN NAME</th><th>ACCOUNT TYPE</th></tr>"
$login=sqlcmd -E -S .\SQLTEST -dmaster -Q "set nocount on;SELECT name AS Login_Name, type_desc AS Account_Type FROM sys.server_principals WHERE TYPE IN ('U', 'S', 'G') and name not like '%##%' ORDER BY name, type_desc;" -h -1 -s"*" -W
foreach ($i in $login) {$reporlogin+="<tr><td>"+$i.split("*")[0]+"</td><td>"+$i.split("*")[1]+"</td></tr>" }
$reporlogin+="</table>"

$dbsize=""
#$dbsize +="<h1 align=center><B><U>SQL ERROR LOG STATUS</U></B></H1>"
$dbsize +="<table border=1>"
$dbsize +="<tr bgcolor=gray><th>DB NAME</th><th>DB STATUS</th><th>RECOVERY MODEL</th><th>TOTAL SIZE</th><th>DATA SIZE</th><th>DATA USED SIZE</th><th>LOG SIZE</th><th>LOG USED SIZE</th></tr>"
$d=sqlcmd -E -S .\SQLTEST -dmaster -Q "set nocount on;SET QUOTED_IDENTIFIER ON;IF OBJECT_ID('tempdb.dbo.#space') IS NOT NULL DROP TABLE #space
CREATE TABLE #space (database_id INT PRIMARY KEY, data_used_size DECIMAL(18,2), log_used_size DECIMAL(18,2))
DECLARE @SQL NVARCHAR(MAX)
SELECT @SQL = STUFF((
    SELECT '
    USE [' + d.name + ']
    INSERT INTO #space (database_id, data_used_size, log_used_size)
    SELECT DB_ID() , SUM(CASE WHEN [type] = 0 THEN space_used END) , SUM(CASE WHEN [type] = 1 THEN space_used END)
    FROM (SELECT s.[type], space_used = SUM(FILEPROPERTY(s.name, ''SpaceUsed'') * 8. / 1024) FROM sys.database_files s GROUP BY s.[type]
    ) t;'FROM sys.databases d WHERE d.[state] = 0 FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
EXEC sys.sp_executesql @SQL
SELECT d.name, d.state_desc, d.recovery_model_desc, t.total_size, t.data_size, s.data_used_size, t.log_size, s.log_used_size FROM (SELECT database_id , log_size = CAST(SUM(CASE WHEN [type] = 1 THEN size END) * 8. / 1024 AS DECIMAL(18,2)), data_size = CAST(SUM(CASE WHEN [type] = 0 THEN size END) * 8. / 1024 AS DECIMAL(18,2))
, total_size = CAST(SUM(size) * 8. / 1024 AS DECIMAL(18,2)) FROM sys.master_files GROUP BY database_id) t JOIN sys.databases d ON d.database_id = t.database_id LEFT JOIN #space s ON d.database_id = s.database_id LEFT JOIN (SELECT database_name, full_last_date = MAX(CASE WHEN [type] = 'D' THEN backup_finish_date END), full_size = MAX(CASE WHEN [type] = 'D' THEN backup_size END)
, log_last_date = MAX(CASE WHEN [type] = 'L' THEN backup_finish_date END), log_size = MAX(CASE WHEN [type] = 'L' THEN backup_size END)FROM (SELECT s.database_name , s.[type] , s.backup_finish_date, backup_size = CAST(CASE WHEN s.backup_size = s.compressed_backup_size THEN s.backup_size ELSE s.compressed_backup_size END / 1048576.0 AS DECIMAL(18,2)) , RowNum = ROW_NUMBER() OVER (PARTITION BY s.database_name, s.[type] ORDER BY s.backup_finish_date DESC) FROM msdb.dbo.backupset s WHERE s.[type] IN ('D', 'L')) f WHERE f.RowNum = 1 GROUP BY f.database_name) bu ON d.name = bu.database_name ORDER BY t.total_size DESC" -h -1 -s"*" -W 

new-alias grep findstr
$size=$d|grep -v "Warning:"
foreach ($i in $size) {$dbsize+="<tr><td>"+$i.split("*")[0]+"</td><td>"+$i.split("*")[1]+"</td><td>"+$i.split("*")[2]+"</td><td>"+$i.split("*")[3]+"</td><td>"+$i.split("*")[4]+"</td><td>"+$i.split("*")[5]+"</td><td>"+$i.split("*")[6]+"</td><td>"+$i.split("*")[7]+"</td></tr>" }
$dbsize+="</table>"





$htmlreport +="<table border=1>"
$htmlreport +="<tr><th>HOSTNAME</th><td>"+$hostname+"</td></tr>"
$htmlreport +="<tr><th>SERVICES</th><td>"+$services+"</td></tr>"
$htmlreport +="<tr><th>DB SIZE</th><td>"+$dbsize+"</td></tr>"
$htmlreport +="<tr><th>BUFFER RATIO</th><td>"+$reportbuffer+"</td></tr>"
$htmlreport +="<tr><th>USER DETAILS</th><td>"+$reporlogin+"</td></tr>"
$htmlreport +="</table>"
Remove-Item alias:\grep
$htmlreport|out-file "c:\scripts\dbhealth.html"


