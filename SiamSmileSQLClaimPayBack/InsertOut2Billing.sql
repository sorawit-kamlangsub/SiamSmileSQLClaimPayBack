USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequestResultImportGroup_Insert]    Script Date: 15/7/2569 11:29:53 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
-- =============================================
-- Author:		Sorawit kamlangsub
-- Create date: 2026-07-04 16:30
-- Update date: 2026-07-15 10:00 Insert data in Column EstimatePaymentDate 
--              table [BillingRequestResultDetail]  with PaymentDate
--              Add Upsert BillingRequestResultDetail
-- Description:	Insert Tmp Out2
-- =============================================
--ALTER PROCEDURE [dbo].[usp_BillingRequestResultImportGroup_Insert]
	-- Add the parameters for the stored procedure here
DECLARE
    @TmpCode VARCHAR(MAX),
	@PaymentDate DATETIME2,
	@UserId INT,
    @BillingRequestGroupCode VARCHAR(MAX) = 'BQGCM04H6900002,BQGSP04H6900002';
--AS
--BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	--SET NOCOUNT ON;

	DECLARE @IsResult			BIT				= 1;
	DECLARE @Result				VARCHAR(100)	= '';
	DECLARE @Msg				NVARCHAR(500)	= '';
	DECLARE @IsActive			BIT = 1;

    -- Insert statements for procedure here
    DECLARE @InsId INT;
	DECLARE @D DATETIME2;
    DECLARE @D2 DATETIME2;
    DECLARE @InsIdReject INT;
    DECLARE @CountForInsert INT;
    DECLARE @CountBqgApprove INT;
    DECLARE @_TmpCode VARCHAR(MAX) = @TmpCode;
    DECLARE @TransactionCodeControlTypeDetail VARCHAR(20) = 'TCB';
	DECLARE @_BillingRequestGroupCode NVARCHAR(MAX) = @BillingRequestGroupCode;

    DECLARE @_PaymentDate DATETIME2 = @PaymentDate;
    DECLARE @_UserId INT = @UserId;
    
    SET @D = GETDATE();
    SET @D2 = CAST(GETDATE() AS DATE);

	IF (@IsResult = 0) SET @Msg = N'ปิดใช้งาน';

	SELECT
	*
	INTO #tmpTmplist
	FROM dbo.func_SplitStringToTable(@TmpCode,',')

	SELECT
	*
	INTO #tmplist
	FROM dbo.func_SplitStringToTable(@_BillingRequestGroupCode,',')

	SELECT DISTINCT
	 bg.BillingRequestGroupCode
     ,bg.InsuranceCompanyId
     ,bri.tmpCode
	 INTO #temp
	FROM dbo.BillingRequestItem bi 
     LEFT JOIN dbo.BillingRequestGroup bg
        ON bg.BillingRequestGroupId = bi.BillingRequestGroupId
	 LEFT JOIN 
     (
      SELECT 
       BillingRequestItemCode
       ,tmpCode
      FROM dbo.BillingRequestResultImport
      WHERE IsActive = 1   
     ) bri
	  ON bi.BillingRequestItemCode = bri.BillingRequestItemCode
	 LEFT JOIN dbo.BillingRequestResultDetail brd
	  ON brd.BillingRequestItemCode = bi.BillingRequestItemCode
	 LEFT JOIN #tmplist t
	  ON t.Element = bg.BillingRequestGroupCode
	WHERE 
        (   
         EXISTS 
         (
            SELECT 1 
            FROM #tmpTmplist t
            WHERE t.Element = bri.tmpCode 
         )
            AND @_BillingRequestGroupCode IS NULL
         )
	    OR (
		    @_TmpCode IS NULL 
		    AND 
		    EXISTS 
			    (
				    SELECT 1
				    FROM #tmplist t
				    WHERE t.Element = bg.BillingRequestGroupCode
			    )
	 )

    SELECT
    rs.*
    ,ds.DecisionStatusName
    ,ROW_NUMBER() OVER(ORDER BY rs.BillingRequestGroupCode) AS rwId 
    INTO #Tmp
    FROM
    (
        SELECT
        *
        ,IIF(IsSomeRejectAmount = 1,Pay_Total - RejectedAmount, Pay_Total)  AmountPayment
        ,CASE 
             WHEN IsAproved = 1 THEN PaySS_Total
             WHEN IsReject = 1 THEN PaySS_Total - RejectedAmount
             WHEN IsSomeRejectAmount = 1 THEN PaySS_Total 
             ELSE 0
         END                                                                [CalCoverAmount]
        ,CASE 
             WHEN IsAproved = 1 THEN 2
             WHEN IsSomeRejectAmount = 1 THEN 3
             WHEN IsReject = 1 THEN 4
             ELSE 1
         END                                                                [DecisionStatusId]
         ,CASE 
                WHEN IsAproved = 1 THEN 0
                WHEN IsReject = 1 THEN RejectedAmount
                WHEN IsSomeRejectAmount = 1 THEN RejectedAmount
                ELSE 0 
          END                                                                [UnCoverAmount]
         ,IIF(RejectedRemark IS NOT NULL,RejectedRemark,NULL)                [UnCoverRemark]
        FROM
        (
            SELECT 
                  bi.[BillingRequestItemCode]
                  ,bg.[BillingRequestGroupCode]
                  ,gi.[InsuranceCompanyId]
                  ,gi.[ClaimTypeCode]
                  ,@D                                       [PaymentDate]
                  ,bi.PaySS_Total 
                  ,bi.AmountTotal                           [Pay_Total]
                  ,brd.CoverAmount
                  ,b.[BankName]
                  ,b.[BankAccountName]
                  ,b.[BankAccountNumber]
                  ,bg.BillingDate
                  ,gd.ClaimCode
                  ,gd.ClaimHeaderGroupImportDetailId
                  ,gf.[FileName]
                  ,brd.BillingRequestItemCode                   BillingRequestResultDetailItemCode
                  ,rj.RejectedAmount
                  ,rj.BillingRequestItemCode                    BillingRequestResultImportItemCode
                  ,rj.RejectedRemark
                  ,rj.tmpCode                                   IptmpCode
                  ,IIF(rj.BillingRequestItemCode IS NULL ,1,0)  IsAproved
                  ,IIF(
                    (ISNULL(bi.AmountTotal , 0) - ISNULL(rj.RejectedAmount, 0) <> ISNULL(bi.AmountTotal , 0)) 
                    AND 
                    (ISNULL(bi.AmountTotal , 0) - ISNULL(rj.RejectedAmount, 0)) > 0, 
                    1, 
                    0
                )                                                   IsSomeRejectAmount
                ,IIF(rj.BillingRequestItemCode IS NOT NULL ,1,0)    IsReject
            FROM dbo.ClaimHeaderGroupImportFile gf
                LEFT JOIN dbo.ClaimHeaderGroupImport gi
	                ON gf.ClaimHeaderGroupImportFileId = gi.ClaimGroupImportFileId
                LEFT JOIN dbo.ClaimHeaderGroupImportDetail gd
	                ON gi.ClaimHeaderGroupImportId = gd.ClaimHeaderGroupImportId
                LEFT JOIN dbo.BillingRequestGroup bg
	                ON gi.BillingRequestGroupId = bg.BillingRequestGroupId
                LEFT JOIN dbo.BillingRequestItem bi
	                ON gd.ClaimHeaderGroupImportDetailId = bi.ClaimHeaderGroupImportDetailId
                LEFT JOIN 
                    (
                        SELECT
                         BillingRequestItemCode
                         ,CoverAmount
                        FROM dbo.BillingRequestResultDetail
                        WHERE IsActive = 1
                    ) brd
                    ON brd.BillingRequestItemCode = bi.BillingRequestItemCode
                INNER JOIN #temp t 
                    ON t.BillingRequestGroupCode = bg.BillingRequestGroupCode
	             LEFT JOIN 
	             (
		            SELECT 
		             tmpCode
                     ,BillingRequestItemCode
		             ,RejectedAmount
                     ,RejectedRemark
		             ,IsActive 
		            FROM dbo.BillingRequestResultImport 
		            WHERE IsActive = 1
	             ) rj
		            ON rj.BillingRequestItemCode = bi.BillingRequestItemCode
                CROSS JOIN dbo.BillingBank b 
            WHERE b.BillingBankId = 1
            AND bg.IsActive = 1
        ) x
    ) rs
    LEFT JOIN [dbo].[DecisionStatus] ds
            ON rs.DecisionStatusId = ds.DecisionStatusId

    DECLARE @Total int
    DECLARE @YY varchar(2)
    DECLARE @MM varchar(2)
    DECLARE @RunningFrom int
    DECLARE @RunningTo int

    SET @Total = (SELECT MAX(rwId) FROM #Tmp);
    
    IF @_TmpCode IS NULL
    BEGIN
        EXECUTE [dbo].[usp_GenerateCode_FromTo] 
           @TransactionCodeControlTypeDetail
          ,@Total
          ,@YY OUTPUT
          ,@MM OUTPUT
          ,@RunningFrom OUTPUT
          ,@RunningTo OUTPUT  
    END

    SELECT *
    ,IIF( tl.tmpCodeTmp IS NULL
        ,CONCAT(@TransactionCodeControlTypeDetail ,@YY,@MM ,dbo.func_ConvertIntToString((@RunningFrom + rwId - 1),6)) 
        ,tl.tmpCodeTmp)   
                        [TmpCode]
    INTO #TmpWithRuningCode
    FROM #Tmp t
    LEFT JOIN 
     (
        SELECT 
         BillingRequestGroupCode BillingRequestGroupCodeTmp
         ,tmpCode tmpCodeTmp
        FROM #temp
     ) tl
     ON t.BillingRequestGroupCode = tl.BillingRequestGroupCodeTmp

-- Validate
    SELECT 
     @CountBqgApprove = COUNT(trh.BillingReceiveStatusId)
    FROM #temp t
    INNER JOIN dbo.TmpBillingReceiveResultHeader trh
        ON trh.BillingRequestGroupCode = t.BillingRequestGroupCode
    WHERE trh.BillingReceiveStatusId IN (2,3)

    IF (@CountBqgApprove > 0) 
    BEGIN 
        SET @IsResult = 0;
        SET @Msg = N'รายการ ซ้ำกับในระบบ';
    END

    SELECT 
     @CountForInsert = COUNT(*)
    FROM #TmpWithRuningCode

    IF (@CountForInsert = 0) 
    BEGIN 
        SET @IsResult = 0;
        SET @Msg = N'ไม่มีข้อมูล';
    END
--End Validate
           
	/*Process*/
	IF (@IsResult = 1)
	BEGIN

		--BEGIN TRY
		--	BEGIN TRANSACTION                            
                
                --INSERT INTO [dbo].[TmpBillingRequestResult]
                --           (
                --           [TmpCode]
                --           ,[BillingRequestItemCode]
                --           ,[PaymentReferenceId]
                --           ,[CoverAmount]
                --           ,[UncoverAmount]
                --           ,[UnCoverRemark]
                --           ,[DecisionStatus]
                --           ,[DecisionStatusId]
                --           ,[RejectResult]
                --           ,[DecisionDate]
                --           ,[EstimatePaymentDate]
                --           ,[Remark]
                --           ,[IsValid]
                --           ,[ValidateResult]
                --           ,[PaymentDate]
                --           ,[AmountPayment]
                --           ,[BankName]
                --           ,[BankAccountName]
                --           ,[BankAccountNumber]
                --           ,[Remark3]
                --           )
                 SELECT             
                            [TmpCode]
                           ,[BillingRequestItemCode]
                           ,NULL                        [PaymentReferenceId]
                           ,[CalCoverAmount]            [CoverAmount]
                           ,[UnCoverAmount]             [UncoverAmount]
                           ,[UnCoverRemark]             [UnCoverRemark]
                           ,[DecisionStatusName]        [DecisionStatus]
                           ,[DecisionStatusId]          [DecisionStatusId]
                           ,[RejectedRemark]            [RejectResult]
                           ,@D                          [DecisionDate]
                           ,NULL                        [EstimatePaymentDate]
                           ,[RejectedRemark]            [Remark]
                           ,1                           [IsValid]
                           ,NULL                        [ValidateResult]
                           ,@_PaymentDate               [PaymentDate]
                           ,[AmountPayment]
                           ,[BankName]
                           ,[BankAccountName]
                           ,[BankAccountNumber]
                           ,[RejectedRemark]            [Remark3]
                 FROM #TmpWithRuningCode
                 WHERE DecisionStatusId <> 4

                --INSERT INTO [dbo].[TmpBillingReceiveResultHeader]
                --           (
                --           [TmpCode]
                --           ,[BillingDate]
                --           ,[BillingReceiveStatusId]
                --           ,[BillingRequestGroupCode]
                --           ,[InsuranceCompanyId]
                --           ,[ClaimTypeCode]
                --           ,[IsActive]
                --           ,[CreatedByUserId]
                --           ,[CreatedDate]
                --           ,[UpdatedByUserId]
                --           ,[UpdatedDate]
                --           )
                SELECT 
                           DISTINCT
                           [TmpCode]
                           ,BillingDate                 [BillingDate]
                           ,2                           [BillingReceiveStatusId]
                           ,[BillingRequestGroupCode]
                           ,[InsuranceCompanyId]
                           ,[ClaimTypeCode]
                           ,1                            [IsActive]
                           ,@_UserId                     [CreatedByUserId]
                           ,@D2                          [CreatedDate]
                           ,@_UserId                     [UpdatedByUserId]
                           ,@D2                          [UpdatedDate]
                FROM #TmpWithRuningCode
                WHERE DecisionStatusId <> 4

                DECLARE @TmpBillingRequestResultHeader TABLE
                (
                    BillingRequestResultHeaderId INT
                    ,BillingRequestResultHeaderCode VARCHAR(20)
                );

                --INSERT INTO [dbo].[BillingRequestResultHeader]
                --           (
                --           [FileName]
                --           ,[BillingRequestResultHeaderCode]
                --           ,[IsActive]
                --           ,[CreatedDate]
                --           ,[CreatedByUserId]
                --           ,[UpdatedDate]
                --           ,[UpdatedByUserId]
                --           ,[IsManual]
                --           ,[IsManualNPL]
                --           )
                --OUTPUT
                --    INSERTED.BillingRequestResultHeaderId
                --    ,INSERTED.BillingRequestResultHeaderCode
                --INTO @TmpBillingRequestResultHeader
                SELECT     DISTINCT
                           [FileName]
                           ,BillingRequestGroupCode    [BillingRequestResultHeaderCode]
                           ,1           [IsActive]
                           ,@D          [CreatedDate]
                           ,@_UserId    [CreatedByUserId]
                           ,@D          [UpdatedDate]
                           ,@_UserId    [UpdatedByUserId]
                           ,0           [IsManual]
                           ,0           [IsManualNPL]
                FROM #Tmp t
                WHERE NOT EXISTS 
                (
                    SELECT 1 FROM dbo.BillingRequestResultDetail rd
                    WHERE rd.BillingRequestItemCode = t.BillingRequestResultDetailItemCode
                )

                --INSERT INTO [dbo].[BillingRequestResultDetail]
                --           (
                --           [BillingRequestResultHeaderId]
                --           ,[BillingRequestItemCode]
                --           ,[PaymentReferenceId]
                --           ,[CoverAmount]
                --           ,[UncoverAmount]
                --           ,[UnCoverRemark]
                --           ,[DecisionStatus]
                --           ,[DecisionStatusId]
                --           ,[RejectResult]
                --           ,[DecisionDate]
                --           ,[EstimatePaymentDate]
                --           ,[Remark]
                --           ,[ClaimCode]
                --           ,[IsActive]
                --           ,[CreatedDate]
                --           ,[CreatedByUserId]
                --           ,[UpdatedDate]
                --           ,[UpdatedByUserId]
                --           ,[ClaimHeaderGroupImportDetailId]
                --           ,[PaySS_Total]
                --           )
                SELECT
                           th.BillingRequestResultHeaderId   [BillingRequestResultHeaderId]
                           ,[BillingRequestItemCode]
                           ,'-'                         [PaymentReferenceId]
                           ,[CalCoverAmount]            [CoverAmount]
                           ,[UnCoverAmount]             [UncoverAmount]
                           ,[UnCoverRemark]             [UnCoverRemark]
                           ,[DecisionStatusName]        [DecisionStatus]
                           ,[DecisionStatusId]          [DecisionStatusId]
                           ,[RejectedRemark]            [RejectResult]
                           ,@D                          [DecisionDate]
                           ,@_PaymentDate               [EstimatePaymentDate]
                           ,NULL                        [Remark]
                           ,[ClaimCode]
                           ,1                           [IsActive]
                           ,@D                          [CreatedDate]
                           ,@_UserId                    [CreatedByUserId]
                           ,@D                          [UpdatedDate]
                           ,@_UserId                    [UpdatedByUserId]
                           ,[ClaimHeaderGroupImportDetailId]
                           ,[PaySS_Total]
                FROM #Tmp t
                INNER JOIN @TmpBillingRequestResultHeader th
                    ON th.BillingRequestResultHeaderCode = t.BillingRequestGroupCode
                WHERE NOT EXISTS 
                (
                    SELECT 1 FROM dbo.BillingRequestResultDetail rd
                    WHERE rd.BillingRequestItemCode = t.BillingRequestResultDetailItemCode
                )

                IF @_TmpCode IS NOT NULL 
                BEGIN

                    SELECT *
                    --UPDATE m 
                    --    SET m.CoverAmount = t.CalCoverAmount
                    --    ,m.UncoverAmount = t.UnCoverAmount
                    --    ,m.DecisionStatusId = t.DecisionStatusId
                    --    ,m.DecisionStatus = t.DecisionStatusName
                    --    ,m.DecisionDate = @D
                    --    ,UpdatedByUserId = @_UserId
                    --    ,UpdatedDate = @D
                    FROM [dbo].[BillingRequestResultDetail] m
                    INNER JOIN [dbo].[BillingRequestResultImport] bri
                        ON bri.BillingRequestItemCode = m.BillingRequestItemCode
                    INNER JOIN #TmpWithRuningCode t 
                        ON t.IptmpCode = bri.tmpCode
                    WHERE m.IsActive = 1

                /* Clean Bill import Temp */
                SELECT *
                --UPDATE m 
                --    SET m.IsActive = 0
                FROM dbo.BillingRequestResultImport m
                INNER JOIN #Tmp t
                    ON t.BillingRequestItemCode = m.BillingRequestItemCode

                END

		--	COMMIT TRANSACTION
		--END TRY
		--BEGIN CATCH

		--	IF @@TRANCOUNT > 0 ROLLBACK;

		--END CATCH

	END;

	IF (@IsResult = 1)
	BEGIN
		SET @Result = 'Success';
	END
	ELSE
	BEGIN
		SET @Result = 'Failure';
	END;

	SELECT	@IsResult	AS IsResult
			,@Result	AS Result
			,@Msg		AS Msg;

	-----------------------------

    IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL DROP TABLE #Tmp;
	IF OBJECT_ID('tempdb..#temp') IS NOT NULL DROP TABLE #temp;
	IF OBJECT_ID('tempdb..#rawData') IS NOT NULL DROP TABLE #rawData;
    IF OBJECT_ID('tempdb..#tmplist') IS NOT NULL DROP TABLE #tmplist;
    IF OBJECT_ID('tempdb..#tmpTmplist') IS NOT NULL DROP TABLE #tmpTmplist;
    IF OBJECT_ID('tempdb..#TmpWithRuningCode') IS NOT NULL DROP TABLE #TmpWithRuningCode;

--END
