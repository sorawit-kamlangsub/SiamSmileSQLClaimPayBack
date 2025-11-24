USE [ClaimPayBack]
GO

DECLARE @BillingRequestGroupCode NVARCHAR(50) = 'BQGPA05B6811002'
,@NewBillingDate			DATE			= '2025-11-24'
,@CreatedByUserId			INT				= 6772

DECLARE @D2						DATETIME2		= SYSDATETIME();
DECLARE @Date					DATE = @D2;
DECLARE @UserId					INT				= @CreatedByUserId;

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
--WHERE m.CreatedDate >= @NewBillingDate

--SELECT *
DELETE be
FROM dbo.BillingExport AS be
WHERE be.BillingRequestGroupCode = @BillingRequestGroupCode;

--SELECT *
DELETE bg
FROM dbo.BillingRequestGroup AS bg
WHERE bg.BillingRequestGroupCode = @BillingRequestGroupCode;