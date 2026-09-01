USE [msdb]
GO

/****** Object:  Job [MockS3]    Script Date: 31/3/2569 14:34:55 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 31/3/2569 14:34:55 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'MockS3', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'DevDBA', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [UpdateS3]    Script Date: 31/3/2569 14:34:55 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'UpdateS3', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE [ClaimPayBack]
GO

DECLARE @D DATETIME = GETDATE();
DECLARE @CutOffDate DATETIME = DATEADD(DAY,-30,@D);

SELECT *
INTO #TmpClaimCodes
FROM 
(
SELECT ccg.ClaimCompensateGroupCode	ClaimHeaderGroup_id
	, cc.ClaimCompensateCode	ClaimHeader_id
FROM sss.dbo.ClaimCompensateGroup ccg
LEFT JOIN sss.dbo.ClaimCompensate cc
	ON ccg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
UNION 
SELECT t.ClaimHeaderGroup_id
	,t.ClaimHeader_id
FROM  sss.dbo.DB_ClaimHeaderGroupItem t
UNION  
SELECT 	 item.ClaimHeaderGroup_id
		,item.ClaimHeader_id
FROM ssspa.dbo.DB_ClaimHeaderGroupItem item
) rs
INNER JOIN ISC_SmileDoc.dbo.DocumentIndexData doc
	ON doc.DocumentIndexData = rs.ClaimHeader_id COLLATE DATABASE_DEFAULT

WHERE doc.DateAction > @CutOffDate AND doc.DateAction <= @D

--SELECT att.*
UPDATE att 
	SET att.S3IsUploaded = 1
FROM ISC_SmileDoc.dbo.Attachment att 
INNER JOIN ISC_SmileDoc.dbo.DocumentIndexData doc 
	ON doc.DocumentID = att.DocumentID
INNER JOIN #TmpClaimCodes tc 
	ON tc.ClaimHeader_id = doc.DocumentIndexData COLLATE DATABASE_DEFAULT
WHERE NOT EXISTS
(
	SELECT 
	1
	FROM [ISC_SmileDoc].[dbo].[ClaimDocument] claimdoc
	WHERE claimdoc.DocumentIndexData = doc.DocumentIndexData
)


INSERT INTO [ISC_SmileDoc].[dbo].[ClaimDocument] ( 
[DocumentId]
, [DocumentStatusId]
, [UpdatedDate]
, [DocumentIndexId]
, [DocumentIndexData]
, [ExtUpdatedDate]
, [IsActive]
, [CreatedDate]
, [DocumentListId]
, [DocumentListName]
, [DocumentTypeId]
, [DocumentTypeName] )
SELECT 
 doc.DocumentID
 ,2						DocumentStatusId
 ,@D					UpdatedDate
 ,doc.DocumentIndexID
 ,tc.ClaimHeader_id		DocumentIndexData
 ,@D					ExtUpdatedDate
 ,1						IsActive
 ,@D					CreatedDate
 ,NULL					DocumentListId
 ,NULL					DocumentListName
 ,NULL					DocumentTypeId
 ,NULL					DocumentTypeName
 FROM #TmpClaimCodes tc 
 INNER JOIN ISC_SmileDoc.dbo.DocumentIndexData doc 
	ON doc.DocumentIndexData = tc.ClaimHeader_id COLLATE DATABASE_DEFAULT
WHERE NOT EXISTS
(
	SELECT 
	1
	FROM [ISC_SmileDoc].[dbo].[ClaimDocument] claimdoc
	WHERE claimdoc.DocumentIndexData = doc.DocumentIndexData
)


IF OBJECT_ID(''tempdb..#Tmplst'') IS NOT NULL  DROP TABLE #Tmplst;
IF OBJECT_ID(''tempdb..#TmpClaimCodes'') IS NOT NULL  DROP TABLE #TmpClaimCodes;', 
		@database_name=N'ISC_SmileDoc', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'RunTimeDay', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=2, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20260331, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'fab9b732-cbc0-44ad-9543-28e6ed6b07c9'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


