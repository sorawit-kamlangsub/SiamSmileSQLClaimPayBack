USE [ClaimPayBack]
GO

DECLARE @BillingRequestGroupCode NVARCHAR(50) = 'BQGPH05H6811048'
,@NewBillingDate			DATE			= '2025-11-19'
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
DELETE be
FROM dbo.BillingExport AS be
WHERE be.BillingRequestGroupCode = @BillingRequestGroupCode;

--SELECT *
DELETE bg
FROM dbo.BillingRequestGroup AS bg
WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode;

--SELECT *
DELETE bi
FROM dbo.BillingRequestItem AS bi
WHERE bi.BillingRequestGroupId = @BillingRequestGroupId;

--SELECT *
DELETE cover
FROM dbo.BillingRequestGroupXResultDetail AS cover
WHERE cover.BillingRequestGroupId = @BillingRequestGroupId;

--SELECT *
DELETE gc
FROM dbo.ClaimHeaderGroupImportCancel AS gc
WHERE gc.ClaimHeaderGroupImportId = @ClaimHeaderGroupImportId;