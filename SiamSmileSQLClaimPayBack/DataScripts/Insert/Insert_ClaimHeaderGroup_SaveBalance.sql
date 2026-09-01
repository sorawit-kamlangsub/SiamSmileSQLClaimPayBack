USE [ClaimPayBack]
GO
	DECLARE @D2	DATETIME2(7);

/* Setup Data*/
    SELECT DISTINCT
        t.ClaimHeaderGroupCode
        ,oId.ClaimHeaderGroupImportDetailId OldImportDetailId
    FROM DataImportExcel.dbo.[20260826_1458_ImportBOHO] t
    INNER JOIN dbo.ClaimHeaderGroupImportDetail id
        ON t.ClaimHeaderGroupCode = id.ClaimHeaderGroupCode
    INNER JOIN dbo.BillingRequestItem bi
        ON id.ClaimHeaderGroupImportDetailId = id.ClaimHeaderGroupImportDetailId
    LEFT JOIN 
    (
        SELECT ClaimHeaderGroupCode
            ,ClaimHeaderGroupImportDetailId
        FROM dbo.ClaimHeaderGroupImportDetail
        WHERE IsActive = 0
    ) oId
        ON t.ClaimHeaderGroupCode = oId.ClaimHeaderGroupCode
    WHERE id.IsActive = 1
   
	

	SET @D2 = GETDATE();
--BEGIN TRY
--	BEGIN TRANSACTION

--	SELECT	1;

--	COMMIT TRANSACTION
--END TRY
--BEGIN CATCH

--	IF @@TRANCOUNT > 0 ROLLBACK;
--END CATCH

-----------------------------

IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;