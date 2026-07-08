USE [ClaimPayBack]
GO

/****** Object:  StoredProcedure [dbo].[usp_BillingRequestResultImportGroup_Insert]    Script Date: 8/7/2569 17:07:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Sorawit kamlangsub
-- Create date: 2026-07-04 16:30
-- Description:	Insert Tmp Out2
-- =============================================
CREATE PROCEDURE [dbo].[usp_BillingRequestResultImportGroup_Insert]
	-- Add the parameters for the stored procedure here
	@TmpCode VARCHAR(20),
	@PaymentDate DATETIME2,
	@UserId INT,
    @BillingRequestGroupCode VARCHAR(20)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @IsResult			BIT				= 1;
	DECLARE @Result				VARCHAR(100)	= '';
	DECLARE @Msg				NVARCHAR(500)	= '';
	DECLARE @IsActive			BIT = 1;

    -- Insert statements for procedure here
	DECLARE @D DATETIME2;
    DECLARE @InsId INT;
    DECLARE @InsIdReject INT;
    DECLARE @CountBqgApprove INT;

    DECLARE @_TmpCode VARCHAR(20) = @TmpCode;
	DECLARE @_BillingRequestGroupCode NVARCHAR(MAX) = @BillingRequestGroupCode ;

    DECLARE @_PaymentDate DATETIME2 = @PaymentDate;
    DECLARE @_UserId INT = @UserId;

	SET @D = CAST(GETDATE() AS DATE);

	IF (@IsResult = 0) SET @Msg = N'ปิดใช้งาน';

	SELECT
	*
	INTO #tmplist
	FROM dbo.func_SplitStringToTable(@_BillingRequestGroupCode,',')

	SELECT DISTINCT
	 a.BillingRequestGroupCode
     ,a.InsuranceCompanyId
	 INTO #temp
	FROM dbo.BillingExport a 
	 LEFT JOIN dbo.BillingRequestResultImport bri
	  ON a.BillingRequestItemCode = bri.BillingRequestItemCode
	 LEFT JOIN #tmplist t
	  ON t.Element = a.BillingRequestGroupCode
	WHERE	(bri.tmpCode = @_TmpCode AND @_BillingRequestGroupCode IS NULL)
	OR (
		@_TmpCode IS NULL 
		AND 
		EXISTS 
			(
				SELECT 1
				FROM #tmplist t
				WHERE t.Element = a.BillingRequestGroupCode
			)
		)

-- Validate
    SELECT @InsId = InsuranceCompanyId FROM #temp
    SELECT @InsIdReject = InsuranceId FROM dbo.BillingRequestResultImport WHERE IsActive = 1 AND tmpCode = @TmpCode   

    SELECT 
     @CountBqgApprove = COUNT(trh.BillingReceiveStatusId)
    FROM #temp t
    INNER JOIN dbo.TmpBillingReceiveResultHeader trh
        ON trh.BillingRequestGroupCode = t.BillingRequestGroupCode
    WHERE trh.BillingReceiveStatusId IN (2,3)

    IF (@InsIdReject <> @InsIdReject) SET @IsResult = 0 SET @Msg = N'บริษัทไม่ตรงกับไฟล์';
    IF (@CountBqgApprove > 0) SET @IsResult = 0 SET @Msg = N'รายการ ซ้ำกับในระบบ';

    SELECT
    rs.*
    ,ds.DecisionStatusName
    INTO #Tmp
    FROM
    (
        SELECT
        *
        ,IIF(IsSomeRejectAmount = 1,Pay_Total - RejectedAmount, Pay_Total)  AmountPayment
        ,CASE 
             WHEN CoverAmount IS NOT NULL THEN CoverAmount
             WHEN IsAproved = 1 THEN PaySS_Total
             WHEN IsSomeRejectAmount = 1 THEN RejectedAmount
             ELSE 0
         END                                                                [CalCoverAmount]
        ,CASE 
             WHEN IsAproved = 1 THEN 2
             WHEN IsSomeRejectAmount = 1 THEN 3
             WHEN IsReject = 1 THEN 4
             ELSE 1
         END                                                                [DecisionStatusId]
         ,CASE 
                WHEN IsSomeRejectAmount = 1 THEN Pay_Total - RejectedAmount
                WHEN IsAproved = 1 THEN 0
                WHEN IsReject = 1 THEN RejectedAmount
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
		             BillingRequestItemCode
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

	/*Process*/
	IF (@IsResult = 1)
	BEGIN

		BEGIN TRY
			BEGIN TRANSACTION

                INSERT INTO [dbo].[TmpBillingRequestResult]
                           (
                           [TmpCode]
                           ,[BillingRequestItemCode]
                           ,[PaymentReferenceId]
                           ,[CoverAmount]
                           ,[UncoverAmount]
                           ,[UnCoverRemark]
                           ,[DecisionStatus]
                           ,[DecisionStatusId]
                           ,[RejectResult]
                           ,[DecisionDate]
                           ,[EstimatePaymentDate]
                           ,[Remark]
                           ,[IsValid]
                           ,[ValidateResult]
                           ,[PaymentDate]
                           ,[AmountPayment]
                           ,[BankName]
                           ,[BankAccountName]
                           ,[BankAccountNumber]
                           ,[Remark3]
                           )
                 SELECT             
                            @_TmpCode                    [TmpCode]
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
                           ,@_PaymentDate                [PaymentDate]
                           ,[AmountPayment]
                           ,[BankName]
                           ,[BankAccountName]
                           ,[BankAccountNumber]
                           ,[RejectedRemark]            [Remark3]
                 FROM #Tmp
                 WHERE DecisionStatusId <> 4

                INSERT INTO [dbo].[TmpBillingReceiveResultHeader]
                           (
                           [TmpCode]
                           ,[BillingDate]
                           ,[BillingReceiveStatusId]
                           ,[BillingRequestGroupCode]
                           ,[InsuranceCompanyId]
                           ,[ClaimTypeCode]
                           ,[IsActive]
                           ,[CreatedByUserId]
                           ,[CreatedDate]
                           ,[UpdatedByUserId]
                           ,[UpdatedDate]
                           )
                SELECT 
                           DISTINCT
                           @_TmpCode                     [TmpCode]
                           ,BillingDate                 [BillingDate]
                           ,2                           [BillingReceiveStatusId]
                           ,[BillingRequestGroupCode]
                           ,[InsuranceCompanyId]
                           ,[ClaimTypeCode]
                           ,1                           [IsActive]
                           ,@_UserId                     [CreatedByUserId]
                           ,@D                          [CreatedDate]
                           ,@_UserId                     [UpdatedByUserId]
                           ,@D                          [UpdatedDate]
                FROM #Tmp

                INSERT INTO [dbo].[BillingRequestResultHeader]
                           (
                           [FileName]
                           ,[BillingRequestResultHeaderCode]
                           ,[IsActive]
                           ,[CreatedDate]
                           ,[CreatedByUserId]
                           ,[UpdatedDate]
                           ,[UpdatedByUserId]
                           ,[IsManual]
                           ,[IsManualNPL]
                           )
                SELECT     DISTINCT
                           [FileName]
                           ,BillingRequestGroupCode    [BillingRequestResultHeaderCode]
                           ,1   [IsActive]
                           ,@D   [CreatedDate]
                           ,1   [CreatedByUserId]
                           ,@D  [UpdatedDate]
                           ,1   [UpdatedByUserId]
                           ,0   [IsManual]
                           ,0   [IsManualNPL]
                FROM #Tmp t
                WHERE NOT EXISTS 
                (
                    SELECT 1 FROM dbo.BillingRequestResultDetail rd
                    WHERE rd.BillingRequestItemCode = t.BillingRequestResultDetailItemCode
                )

                DECLARE @TmpBillingRequestResultId INT = SCOPE_IDENTITY();

                INSERT INTO [dbo].[BillingRequestResultDetail]
                           (
                           [BillingRequestResultHeaderId]
                           ,[BillingRequestItemCode]
                           ,[PaymentReferenceId]
                           ,[CoverAmount]
                           ,[UncoverAmount]
                           ,[UnCoverRemark]
                           ,[DecisionStatus]
                           ,[DecisionStatusId]
                           ,[RejectResult]
                           ,[DecisionDate]
                           ,[EstimatePaymentDate]
                           ,[Remark]
                           ,[ClaimCode]
                           ,[IsActive]
                           ,[CreatedDate]
                           ,[CreatedByUserId]
                           ,[UpdatedDate]
                           ,[UpdatedByUserId]
                           ,[ClaimHeaderGroupImportDetailId]
                           ,[PaySS_Total]
                           )
                SELECT
                           @TmpBillingRequestResultId   [BillingRequestResultHeaderId]
                           ,[BillingRequestItemCode]
                           ,'-'                         [PaymentReferenceId]
                           ,[CalCoverAmount]            [CoverAmount]
                           ,[UnCoverAmount]             [UncoverAmount]
                           ,[UnCoverRemark]             [UnCoverRemark]
                           ,[DecisionStatusName]        [DecisionStatus]
                           ,[DecisionStatusId]          [DecisionStatusId]
                           ,[RejectedRemark]            [RejectResult]
                           ,@D                          [DecisionDate]
                           ,NULL                        [EstimatePaymentDate]
                           ,NULL                        [Remark]
                           ,[ClaimCode]
                           ,1                           [IsActive]
                           ,@D                          [CreatedDate]
                           ,1                           [CreatedByUserId]
                           ,@D                          [UpdatedDate]
                           ,1                           [UpdatedByUserId]
                           ,[ClaimHeaderGroupImportDetailId]
                           ,[PaySS_Total]
                FROM #Tmp t
                WHERE NOT EXISTS 
                (
                    SELECT 1 FROM dbo.BillingRequestResultDetail rd
                    WHERE rd.BillingRequestItemCode = t.BillingRequestResultDetailItemCode
                )

                /* Clean Bill import Temp */
                --SELECT *
                UPDATE m 
                    SET m.IsActive = 0
                FROM dbo.BillingRequestResultImport m
                INNER JOIN #Tmp t
                    ON t.BillingRequestItemCode = m.BillingRequestItemCode

			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH

			IF @@TRANCOUNT > 0 ROLLBACK;
		END CATCH

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

END
GO

