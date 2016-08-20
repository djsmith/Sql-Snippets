/*
This query looks for the top 30 processes ordered by how much CPU resources
are used over their connection time (PScore).

The query also shows the name of the process, the host for the connection,
and if it is blocked or not. If the blocked column is non-zero the number 
indicates the spid of the blocking process.
*/
Select Top 30 spid, Blocked, open_tran Trans, last_batch LastBatch,
	convert(varchar(100), db_name(dbid)) as DbName, DbId, 
	cpu as CPU,
	datediff(second, login_time, getdate()) as Seconds,
	datediff(second, login_time, getdate())/3600 as Hours,
	convert(float, cpu / datediff(second, login_time, getdate())) as PScore,
	convert(varchar(12), hostname) as Host,
	convert(varchar(50), program_name) as Program,
	convert(varchar(30), loginame) as Login, 
	status as Status, 
	cmd as Command
from master..sysprocesses
--prevent divide by zero errors
where datediff(second, login_time, getdate()) > 0 
-- filter out internal processes which shouldn't have a netlibrary value
	and len(isnull(net_library,''))>0
order by blocked desc, pscore desc

/*
This query will list what resources are being used by the different processes.
This is done by combining various statistics across the processes used by 
the same program.

The SuckFactor column attempts to quantify the relative drain on resources for the
various programs.  
*/
select
	convert(varchar(50), program_name) as Program,
	count(*) as Connections,
	sum(cpu) as TotalCPU,
	sum(datediff(second, login_time, getdate())) as TotalSec,
	convert(float, sum(cpu)) / convert(float, sum(datediff(second, login_time, getdate()))) as PScore,
	convert(float, sum(cpu)) / convert(float, sum(datediff(second, login_time, getdate()))) / count(*) as SuckFactor
from master..sysprocesses
-- filter out internal processes which shouldn't have a netlibrary value
where len(isnull(net_library,''))>0
group by convert(varchar(50), program_name)
order by PScore desc
