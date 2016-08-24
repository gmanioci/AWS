/*

-- curl methid:
	curl -X POST -d 'json={"field1":"Text1"}' http://chelmonnco013.karmalab.net:8888/azure.http.controlm

-- powershell method
	Invoke-WebRequest -UseBasicParsing http://eaxmple.com/service -ContentType "application/json" -Method POST -Body "{ 'ItemID':3661515, 'Name':'test'}"

	Example format needed by fluentD:

		{"Source":"ExpedbaHist",
		 "Host":"CHCXSQLOPS002",
		 "NetworkDevice":"",
		 "EventType":"37",
		 "Summary":"",
		 "Severity":2,
		 "ExtraDetails":", DB:[InventorySystemDW], FileGroup:PRIMARY, PctFree:0",
		 "Instance":""}

	Example EventHist record from expedba:
*/

set nocount on
go

declare @sql				varchar(8000)
declare @srv				sysname
declare @i					int				= 1
declare @json				varchar(max)	= ''
declare @t					table 
	(
	 MyTimeStamp			datetime
	,EventID				int
	,MsgDetail				varchar(max)
	,idx					int identity(1,1)
	)

if object_id('tempdb.dbo.EventHist_json') is not null
	drop table tempdb.dbo.EventHist_json
create table tempdb.dbo.EventHist_json
	(
	 json					varchar(max)
	,idx					int identity(1,1)
	)
	
declare @tmpMyTimeStamp		datetime
declare @tmpEventID			int
declare @tmpMsgDetail		nvarchar(max)
declare @tmpSev				tinyint
declare @tmpEventDesc		varchar(255)

-- get the servernmae
	set @srv = (select @@servername)


-- grab the events (1 day's example)
	insert into @t (MyTimeStamp,EventID,MsgDetail)
	select MyTimeStamp,EventID,MsgDetail
	from expedba.evt.EventHist with(nolock)
	where MyTImeStamp > dateadd(hh,-2,getdate())

-- create a .json document for each one in the format that the tools team needs
-- Ref:  https://confluence/display/EEM/1.+Format+data+for+EMF+ingestion

while @i <= (select max(idx) from @t)
  begin
	-- header	
	if @i = 1 set @json = '{'  

	select 
		 @tmpMyTimeStamp	=t.MyTimeStamp
	    ,@tmpEventID		=t.EventID
		,@tmpMsgDetail		=t.MsgDetail
		,@tmpSev			=et.ErrorLevel
		,@tmpEventDesc		=et.EventDesc
	from
		@t t
	inner join
		expedba.evt.EventType et on et.EventID = t.EventID
	where
		idx = @i
	



-- get the correspon
	-- source
		set @json=@json+'"Source":"evt.EventHist",'
	-- host
		set @json=@json+'"Host":"'+@srv+'",'
	-- network device
		set @json=@json+'"NetworkDevice":"",'
	-- EventType
		set @json=@json+'"EventType":"'+cast(@tmpEventID as varchar(8))+'",'
	-- Summary
		set @json=@json+'"Summary":"'+@tmpEventDesc+'",'
	-- Severity
		set @json=@json+'"Severity":"'+cast(@tmpSev as varchar(8))+'",'
	-- ExtraDetails
		set @json=@json+'"ExtraDetails":"'+@tmpMsgDetail+'",'
	-- Instance
		set @json=@json+'"Instance":""}'

	-- increment the loop counter
		set @i = @i + 1
		
		-- add to output table
			insert into tempdb.dbo.EventHist_json (json)
			select @json
			  
			set @sql = 'powershell.exe ''Invoke-WebRequest -UseBasicParsing http://chelmonnco013.karmalab.net:8888/azure.http.controlm -ContentType "application/json" -Method POST -Body "'+@json+'"'''
			select @sql
			exec master..xp_cmdshell @sql

	-- reset the json variable for the next row
		set @json = ''
		
  end

-- create a file from the output table
	exec master..xp_cmdshell 'bcp "SELECT json FROM tempdb.dbo.EventHist_json" queryout d:\File1\EventHist.json -t, -c -S . -T'

-- clean up
	
if object_id('tempdb.dbo.EventHist_json') is not null
	drop table tempdb.dbo.EventHist_json

set nocount off
go