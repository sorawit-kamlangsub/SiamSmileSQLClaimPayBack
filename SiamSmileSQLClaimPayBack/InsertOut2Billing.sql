USE [ClaimPayBack]
GO

DECLARE @D DATETIME2; 

SET @D = CAST(CAST(GETDATE() AS DATE) AS DATETIME2);
	
BEGIN TRY
	BEGIN TRANSACTION

    DECLARE @TransactionCodeControlTypeDetail varchar(8) = 'TCB';
    DECLARE @RunningLenght int = 6;
    DECLARE @Result varchar(20);

    EXECUTE [dbo].[usp_GenerateCode] 
       @TransactionCodeControlTypeDetail
      ,@RunningLenght
      ,@Result OUTPUT



    SELECT 
          bi.[BillingRequestItemCode]
          ,bg.[BillingRequestGroupCode]
          ,gi.[InsuranceCompanyId]
          ,gi.[ClaimTypeCode]
          ,@D             [PaymentDate]
          ,bi.PaySS_Total [AmountPayment]
          ,b.[BankName]
          ,b.[BankAccountName]
          ,b.[BankAccountNumber]
          ,bg.BillingDate
          ,gd.ClaimCode
          ,gd.ClaimHeaderGroupImportDetailId
          ,gd.PaySS_Total
          ,gf.[FileName]
    INTO #Tmp
    FROM dbo.ClaimHeaderGroupImportFile gf
	    LEFT JOIN dbo.ClaimHeaderGroupImport gi
		    ON gf.ClaimHeaderGroupImportFileId = gi.ClaimGroupImportFileId
	    LEFT JOIN dbo.ClaimHeaderGroupImportDetail gd
		    ON gi.ClaimHeaderGroupImportId = gd.ClaimHeaderGroupImportId
	    LEFT JOIN dbo.BillingRequestGroup bg
		    ON gi.BillingRequestGroupId = bg.BillingRequestGroupId
	    LEFT JOIN dbo.BillingRequestItem bi
		    ON gd.ClaimHeaderGroupImportDetailId = bi.ClaimHeaderGroupImportDetailId
        CROSS JOIN dbo.BillingBank b 
    WHERE b.BillingBankId = 1
    AND bg.BillingRequestGroupCode = 'BQGPA04B6907001'


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
                @Result             [TmpCode]
               ,[BillingRequestItemCode]
               ,NULL                [PaymentReferenceId]
               ,0                   [CoverAmount]
               ,NULL                [UncoverAmount]
               ,NULL                [UnCoverRemark]
               ,NULL                [DecisionStatus]
               ,NULL                [DecisionStatusId]
               ,NULL                [RejectResult]
               ,NULL                [DecisionDate]
               ,NULL                [EstimatePaymentDate]
               ,NULL                [Remark]
               ,1                   [IsValid]
               ,NULL                [ValidateResult]
               ,[PaymentDate]
               ,[AmountPayment]
               ,[BankName]
               ,[BankAccountName]
               ,[BankAccountNumber]
               ,NULL                [Remark3]
     FROM #Tmp

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
               TOP(1)
               @Result                      [TmpCode]
               ,[BillingDate]
               ,2                           [BillingReceiveStatusId]
               ,[BillingRequestGroupCode]
               ,[InsuranceCompanyId]
               ,[ClaimTypeCode]
               ,1                           [IsActive]
               ,1                           [CreatedByUserId]
               ,@D                          [CreatedDate]
               ,1                           [UpdatedByUserId]
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
    SELECT 
               TOP(1)
               [FileName]
               ,BillingRequestGroupCode    [BillingRequestResultHeaderCode]
               ,1   [IsActive]
               ,@D   [CreatedDate]
               ,1   [CreatedByUserId]
               ,@D  [UpdatedDate]
               ,1   [UpdatedByUserId]
               ,0   [IsManual]
               ,0   [IsManualNPL]
    FROM #Tmp

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
               ,NULL                        [PaymentReferenceId]
               ,NULL                        [CoverAmount]
               ,NULL                        [UncoverAmount]
               ,NULL                        [UnCoverRemark]
               ,NULL                        [DecisionStatus]
               ,NULL                        [DecisionStatusId]
               ,NULL                        [RejectResult]
               ,NULL                        [DecisionDate]
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
    FROM #Tmp

	COMMIT TRANSACTION
END TRY
BEGIN CATCH

	IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH

-----------------------------

IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;