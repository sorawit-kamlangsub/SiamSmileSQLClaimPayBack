USE [ClaimPayBack]
GO

DECLARE @BillingRequestGroupCode NVARCHAR(50) = 'BQGPH19H6900004'
,@NewBillingDate			DATE			= '2026-01-20'
,@UpdatedByUserId			INT				= 6772

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
	,m.CreatedDate							= @D2
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
--UPDATE be
--	SET be.IsActive = 0
--FROM dbo.BillingExport AS be
--WHERE be.BillingRequestGroupCode = @BillingRequestGroupCode; -- <= None IsActive

--SELECT *
UPDATE bg
	SET bg.IsActive = 0
FROM dbo.BillingRequestGroup AS bg
WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode;

--SELECT *
Update bi
	SET bi.IsActive = 0
FROM dbo.BillingRequestItem AS bi
WHERE bi.BillingRequestGroupId = @BillingRequestGroupId;

--SELECT *
--UPDATE cover
--	SET cover.IsActive = 0
--FROM dbo.BillingRequestGroupXResultDetail AS cover
--WHERE cover.BillingRequestGroupId = @BillingRequestGroupId; -- <= None IsActive

--SELECT *
UPDATE gc
	SET gc.IsActive = 0
FROM dbo.ClaimHeaderGroupImportCancel AS gc
WHERE gc.ClaimHeaderGroupImportId = @ClaimHeaderGroupImportId;