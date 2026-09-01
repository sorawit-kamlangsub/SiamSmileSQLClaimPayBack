USE [ClaimPayBack]
GO
    DECLARE @UserId INT;
    DECLARE @IsActive BIT;
	DECLARE @D2	DATETIME2(7);

/* Setup Data*/

	SET @D2 = GETDATE();
    SET @UserId = 1;
    SET @IsActive = 0;

    SELECT
        t.ClaimHeaderGroupCode,
        bi.BillingRequestItemId
    INTO #Tmp
    FROM DataImportExcel.dbo.[20260826_1458_ImportBOHO] t
    LEFT JOIN (
        SELECT
            ClaimHeaderGroupCode,
            IsActive
        FROM dbo.ClaimHeaderGroupImport
        WHERE IsActive = 1
    ) i
        ON t.ClaimHeaderGroupCode = i.ClaimHeaderGroupCode
    LEFT JOIN (
        SELECT
            ClaimHeaderGroupCode,
            ClaimHeaderGroupImportDetailId,
            IsActive
        FROM dbo.ClaimHeaderGroupImportDetail
        WHERE IsActive = 1
    ) id
        ON t.ClaimHeaderGroupCode = id.ClaimHeaderGroupCode
    LEFT JOIN (
        SELECT
            BillingRequestItemId,
            ClaimHeaderGroupImportDetailId,
            IsActive
        FROM dbo.BillingRequestItem
        WHERE IsActive = 1
    ) bi
        ON id.ClaimHeaderGroupImportDetailId = bi.ClaimHeaderGroupImportDetailId;

BEGIN TRY
	BEGIN TRANSACTION

    SELECT i.ClaimHeaderGroupCode,i.IsActive
    --UPDATE i 
    --    SET i.IsActive = @IsActive
    --        ,i.UpdatedByUserId = @UserId
    --        ,i.UpdatedDate = @D2
    FROM dbo.ClaimHeaderGroupImport i
    INNER JOIN #Tmp t
        ON i.ClaimHeaderGroupCode = t.ClaimHeaderGroupCode;

    SELECT id.ClaimHeaderGroupCode,id.IsActive
    --UPDATE id 
    --    SET id.IsActive = @IsActive
    --        ,id.UpdatedByUserId = @UserId
    --        ,id.UpdatedDate = @D2
    FROM dbo.ClaimHeaderGroupImportDetail id
    INNER JOIN #Tmp t
        ON id.ClaimHeaderGroupCode = t.ClaimHeaderGroupCode;

    SELECT bi.BillingRequestItemCode,bi.IsActive
    --UPDATE bi 
    --    SET bi.IsActive = @IsActive
    --        ,bi.UpdatedByUserId = @UserId
    --        ,bi.UpdatedDate = @D2
    FROM dbo.BillingRequestItem bi
    INNER JOIN #Tmp t
        ON bi.BillingRequestItemId = t.BillingRequestItemId;

    SELECT x.*
    --UPDATE bg
    --SET
    --    bg.CoverAmount = bg.CoverAmount - x.CoverAmount,
    --    bg.PaySS_Total = bg.PaySS_Total - x.PaySS_Total,
    --    bg.TotalAmount = bg.TotalAmount - x.TotalAmount,
    --    bg.UpdatedByUserId = 1,
    --    bg.UpdatedDate = @D2
    FROM dbo.BillingRequestGroup bg
    INNER JOIN (
        SELECT
            bi.BillingRequestGroupId,
            SUM(CASE WHEN bi.IsActive = 0 THEN bi.CoverAmount ELSE 0 END) AS CoverAmount,
            SUM(CASE WHEN bi.IsActive = 0 THEN bi.PaySS_Total ELSE 0 END) AS PaySS_Total,
            SUM(CASE WHEN bi.IsActive = 0 THEN bi.AmountTotal ELSE 0 END) AS TotalAmount
        FROM dbo.BillingRequestItem bi
        INNER JOIN #Tmp t
            ON bi.BillingRequestItemId = t.BillingRequestItemId
        GROUP BY bi.BillingRequestGroupId
    ) x
        ON bg.BillingRequestGroupId = x.BillingRequestGroupId;

	COMMIT TRANSACTION
END TRY
BEGIN CATCH
    SELECT @@ERROR
	IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH

IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;