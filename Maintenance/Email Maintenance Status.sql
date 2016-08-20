CREATE PROCEDURE sp_SendEmailMaintenanceStatus
/***********************************************************************
* Purpose: 	Sends an email report of the maintenance plan results
* Inputs:   @EmailTo; Destination email address
* 				@EmailFrom; Return email address
*				@EmailServer; Relay server or MX server for the destination
*				@PastDays; Number of days to include in report
* Returns: 	@Return; Result code for email; 0=Fail, 1=Success
* Outputs: 	SMTP email to destination address
* Errors: 	
* Notes:	   This procedure uses the xp_smtp_sendmail extended procedure
*				that connects to xpsmtp80.dll. See SQLDev.Net for more info
*				http://www.sqldev.net/xp/xpsmtp.htm
* Usage: 	Useful in a Sql Agent Job to send out a daily report
* 				to a specific address. Example:
	Declare @RC int
	Declare @EmailTo varchar(100)
	Declare @EmailFrom varchar(100)
	Declare @EmailServer varchar(100)
	Declare @PastDays int
	Declare @ErrorCodeInt int
	Declare @ErrorMsgVChr varchar(100)
	Declare @Debug bit
	-- Set parameter values
	Set @EmailTo = 'dan.smith@djsmith.net'
	Set @EmailFrom = 'sql@djsmith.net'
	Set @EmailServer = 'mail.djsmith.net'
	Set @PastDays = 1
	Set @Debug = 0
	EXEC @RC = [master].[dbo].[sp_SendEmailMaintenanceStatus] @EmailTo, @EmailFrom, @EmailServer, @PastDays, @ErrorCodeInt, @ErrorMsgVChr, @Debug
* Revision: DSmith, 2/10/04. Created procedure
***********************************************************************/
(
	@EmailTo varchar(100),
	@EmailFrom varchar(100),
	@EmailServer varchar(100),
	@PastDays int,
	
		-- Error return values
	@ErrorCodeInt int = 0 OUTPUT,
	@ErrorMsgVChr varchar(100) = '' OUTPUT,
	
	@Debug int = 0
)

AS
 
Declare 
	@PlanName varchar(300),
	@PreviousPlanName varchar(300),
	@DataBaseName varchar(300),
	@Activity varchar(300),
	@EndTime datetime,
	@Message varchar(8000),
	@CrLf char(2),
	@EmailMessage varchar(8000),
	@TableHeader varchar(1000),
	@TableRow varchar(8000),
	@ErrorRow varchar(8000),
	@TableFooter varchar(50),
	@Return int

-- Improves performance
Set nocount on

-- Initialize Error Message
If @ErrorMsgVChr Is Null
	Set @ErrorMsgVChr = ''

-- Capture any error on procedure load
Set @ErrorCodeInt = @@Error

-- Get this Stored Procedure's name for later use
Declare @ProcedureVChr sysname
Set @ProcedureVChr = Object_Name(@@ProcID)

If @Debug <> 0
Begin
	Select '**** ' + @ProcedureVChr + ' START ****'
	Select '****** Input Parameters ******'
	Select @EmailTo as EmailTo, @EmailFrom as EmailFrom, @EmailServer as EmailServer, @PastDays as PastDays
End

If @ErrorCodeInt = 0
	Begin
	--Setup HTML strings for message
	Set @CrLf = CHAR(13) + CHAR(10) 
	Set @EmailMessage = '<html><body><h3>' + @@ServerName + ' Maintenance Plan Status Report</h3>'
	--Setup TableHeader and TableRow with tags that can be replaced later
	Set @TableHeader = '<table border="1" cellpadding="4" cellspacing="0"><tr align="center"><td colspan="3">StatusTag</td></tr><tr align="center"><td>Plan Name</td><td>Database</td><td>Activity</td></tr>'
	--Place a crlf at the end of the row to prevent overruns in xp_smtp_sendmail
	Set @TableRow = '<tr><td>PlanNameTag</td><td>DatabaseNameTag</td><td>ActivityTag</td></tr>' + @CrLf
	Set @ErrorRow = '<tr><td colspan="3">MessageTag</td></tr>' + @CrLf
	Set @TableFooter = '</table>'
	--Make sure PastDays input parameter isn't negitive, will be made negitive in select statements.
	Set @PastDays = Abs(@PastDays)

	--Get activities that didn't succeed   
	Declare FailedPlans Cursor For 
	Select plan_name, database_name, activity, end_time, message From msdb.dbo.sysdbmaintplan_history 
	Where start_time > DateAdd ( dd , (@PastDays * -1), GetDate() ) And succeeded = 0
	Order By plan_name, database_name, end_time

	Open FailedPlans

	Fetch Next From FailedPlans 
	Into @PlanName, @DataBaseName, @Activity, @EndTime, @Message

	If @@Fetch_Status <> 0
		Begin
		Set @EmailMessage = @EmailMessage + '<p>No failed maintenance plan activities over the last ' + convert(varchar(4),@PastDays) + ' days</p>'
		End
	Else
		Begin
		Set @EmailMessage = @EmailMessage + Replace(@TableHeader,'StatusTag','<font color="red">Failed Maintenance Plan Activities over the last ' + convert(varchar(4),@PastDays) + ' days</font>')

		While @@Fetch_Status = 0
			Begin
			Set @EmailMessage = @EmailMessage + @TableRow + @ErrorRow
			If @PreviousPlanName = @PlanName
				Begin
				Set @EmailMessage = Replace(@EmailMessage,'PlanNameTag','.')
				End
			Else
				Begin
				Set @EmailMessage = Replace(@EmailMessage,'PlanNameTag',Replace(@PlanName,'Maintenance Plan',''))
				End
			Set @PreviousPlanName = @PlanName
			Set @EmailMessage = Replace(@EmailMessage,'DatabaseNameTag',@DatabaseName)
			Set @EmailMessage = Replace(@EmailMessage,'ActivityTag',@Activity)
			Set @EmailMessage = Replace(@EmailMessage,'MessageTag',@Message)
	
			Fetch Next From FailedPlans 
			Into @PlanName, @DataBaseName, @Activity, @EndTime, @Message
			End
	
		Set @EmailMessage = @EmailMessage + @TableFooter
		End

	Close FailedPlans
	Deallocate FailedPlans

	Declare SuccededPlans Cursor For 
	Select plan_name, database_name, activity, end_time, message From msdb.dbo.sysdbmaintplan_history 
	Where start_time > DateAdd ( dd , (@PastDays * -1), GetDate() ) And succeeded = 1
	Order By plan_name, database_name, end_time

   Open SuccededPlans

	Fetch Next From SuccededPlans 
	Into @PlanName, @DataBaseName, @Activity, @EndTime, @Message

	If @@Fetch_Status <> 0
		Begin
		Set @EmailMessage = @EmailMessage + '<p><font color="red">No successful maintenance plan activities over the last ' + convert(varchar(4),@PastDays) + ' days</font></p>'
		End
	Else
		Begin
		Set @EmailMessage = @EmailMessage + Replace(@TableHeader,'StatusTag','Successful Maintenance Plan Activities over the last ' + convert(varchar(4),@PastDays) + ' days')

		While @@Fetch_Status = 0
			Begin
			Set @EmailMessage = @EmailMessage + @TableRow
			If @PreviousPlanName = @PlanName
				Begin
				Set @EmailMessage = Replace(@EmailMessage,'PlanNameTag','.')
				End
			Else
				Begin
				Set @EmailMessage = Replace(@EmailMessage,'PlanNameTag',Replace(@PlanName,'Maintenance Plan',''))
				End
	
			Set @PreviousPlanName = @PlanName
			Set @EmailMessage = Replace(@EmailMessage,'DatabaseNameTag',@DatabaseName)
			Set @EmailMessage = Replace(@EmailMessage,'ActivityTag',@Activity)
			--Don't insert the message on successful activities
	
			Fetch Next From SuccededPlans 
			Into @PlanName, @DataBaseName, @Activity, @EndTime, @Message
			End
	
		Set @EmailMessage = @EmailMessage + @TableFooter  
		End

	Set @EmailMessage = @EmailMessage + '</body></html>'

	Close SuccededPlans
	Deallocate SuccededPlans

	Declare @SubjectLine nvarchar(50)
	Set @SubjectLine = @@ServerName + N' Maintenence Plan Status Report'
	Exec @Return = master.dbo.xp_smtp_sendmail
		@To       = @EmailTo,
		@From     = @EmailFrom,
		@Subject  = @SubjectLine,
		@Message  = @EmailMessage,
		@Type     = N'text/html',
		@Server   = @EmailServer
	End
Else
	Begin
	-- Procedure didn't load properly
	Set @ErrorMsgVChr = @ProcedureVChr + ': Stored Procedure did not initialize properly.'
	End

If @Debug <> 0
	Select '**** ' + @ProcedureVChr + ' END ****'

Return @Return
 