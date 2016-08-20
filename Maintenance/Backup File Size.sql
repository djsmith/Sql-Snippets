/*
This script will query msdb to determine the size of data and log files 
for all databases, along with the average sizes of full and transaction 
log backups. Results are averaged over the past two weeks, but this is 
easily changed.
*/
Create Table #Backupsizes (
	dbname varchar(64), 
	filedate datetime, 
	DataSize real NULL, 
	LogSize real NULL, 
	FullBackupSize real NULL,
	LogBackupCount int NULL,
	LogBackupTotal real NULL, 
	LogBackupAvg real NULL
)

Insert Into #Backupsizes (filedate, dbname, DataSize, LogSize, FullBackupSize)
	select filedate=bs.backup_finish_date, dbname=bs.database_name, 
		SUM(CASE file_type WHEN 'D' THEN file_size ELSE 0 END) / (1024 * 1024.0)as Dsize,
		SUM(CASE file_type WHEN 'L' THEN file_size ELSE 0 END) / (1024 * 1024.0)as Lsize,
		max(bs.backup_size / (1024 * 1024.0))
	from msdb..backupset bs, msdb..backupfile bf
	where bf.backup_set_id = bs.backup_set_id
		and bs.type in('D') and bs.backup_finish_date > dateadd(ww,-2,getdate())
	group by bs.database_name, bs.backup_finish_date
	having bs.backup_finish_date = ( select max(bs2.backup_finish_date)
from msdb..backupset bs2
where bs.database_name = bs2.database_name and bs2.type = 'D')
order by bs.database_name

select bs.database_name as DBName,
sum(bs.backup_size) / (1024 * 1024.0) as LogBackupTotal ,
count(bs.backup_size) as LogBackupCount,
avg(bs.backup_size / (1024.0)) as LogBackupAvg 
into #logsizes
from msdb..backupset bs, msdb..backupfile bf
where bf.backup_set_id = bs.backup_set_id
and bs.type in('L') and bs.backup_finish_date > dateadd(ww,-2,getdate())
group by bs.database_name

update #backupsizes 
set LogBackupTotal = ls.LogBackupTotal,
LogBackupcount = ls.LogBackupCount, 
LogBackupAvg = ls.LogBackupAvg
from #logsizes ls
where #backupsizes.dbname = ls.dbname

select * from #backupsizes where dbname not in ('master', 'tempdb', 'msdb', 'pubs', 'northwinds', 'model', 'distribution')
order by 1

drop table #backupsizes
drop table #logsizes
