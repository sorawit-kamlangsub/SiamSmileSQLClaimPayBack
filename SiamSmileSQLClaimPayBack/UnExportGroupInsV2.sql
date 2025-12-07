USE [ClaimPayBack]
GO

DECLARE @BillingRequestGroupCode NVARCHAR(50) = 'BQGPH05B6811012'
,@NewBillingDate			DATE			= '2025-11-24'
,@UpdatedByUserId			INT				= 1

DECLARE @D2							DATETIME2	= SYSDATETIME();
DECLARE @Date						DATE		= @D2;
DECLARE @UserId						INT			= @UpdatedByUserId;
DECLARE @BillingRequestGroupId		INT			= 0;
DECLARE @ClaimHeaderGroupImportId	INT			= 0;

--SELECT *
UPDATE	m 
	SET m.ClaimHeaderGroupImportStatusId	= 2
	,BillingRequestGroupId					= NULL
	,m.UpdatedDate							= @D2
	,m.UpdatedByUserId						= @UserId
	,m.BillingDate							= @NewBillingDate
FROM dbo.ClaimHeaderGroupImport m
	INNER JOIN dbo.BillingRequestGroup bg
		ON bg.BillingRequestGroupId = m.BillingRequestGroupId	
WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode

SELECT @BillingRequestGroupId = bg.BillingRequestGroupId
FROM dbo.BillingRequestGroup AS bg
WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode;

SELECT @ClaimHeaderGroupImportId = h.ClaimHeaderGroupImportId
FROM dbo.ClaimHeaderGroupImport h
	INNER JOIN dbo.BillingRequestGroup bg
		ON bg.BillingRequestGroupId = h.BillingRequestGroupId	
WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode

--SELECT *
UPDATE bg
	SET bg.IsActive = 0
		,bg.UpdatedByUserId = @UserId
		,bg.UpdatedDate = @D2
FROM dbo.BillingRequestGroup AS bg
WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode;

--SELECT *
UPDATE bi
	SET bi.IsActive = 0
		,bi.UpdatedByUserId = @UpdatedByUserId
		,bi.UpdatedDate = @D2
FROM dbo.BillingRequestItem AS bi
WHERE bi.BillingRequestGroupId = @BillingRequestGroupId;

--SELECT *
UPDATE gc
	SET gc.IsActive = 0
FROM dbo.ClaimHeaderGroupImportCancel AS gc
WHERE gc.ClaimHeaderGroupImportId = @ClaimHeaderGroupImportId;