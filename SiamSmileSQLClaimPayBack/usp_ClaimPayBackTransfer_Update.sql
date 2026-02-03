USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackTransfer_Update]    Script Date: 3/2/2569 13:29:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Prattana Phiwkaew
-- Create date: 2021-10-06 15:52
-- Update date: 2024-02-28 Kittisak.Ph เพิ่มบันทึกตัดรับชำระใน ClaimOnlineV2
--				2024-11-11 Wetpisit.P ดักเงื่อนไขไม่ให้ตัดรายการของบริษัท SMI ออกจากรายงานเคลมคงค้าง
-- Description:	ClaimPayBackTransfer Update
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackTransfer_Update] 
	-- Add the parameters for the stored procedure here
	 @ClaimBayBackTransferId		INT
	,@TransferAmount				DECIMAL(16,2)
	,@TransferDate					DATETIME
	,@UpdatedByUserId				INT

AS	
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--------------------------------------------------------

DECLARE @IsResult			BIT			 = 1;
DECLARE @Result				VARCHAR(100) = '';
DECLARE @Msg				NVARCHAR(500)= 'Not allowed to use';

DECLARE @D		DATETIME = GETDATE();
DECLARE @ClaimPayBackStatusId	INT = 4;		-- 4 จ่ายแล้ว
DECLARE @ClaimPayBackTransferStatusId	INT = 3; --3 จ่ายแล้ว 
DECLARE @InsuranceCompanyId INT = 699804; --บริษัท SMI

---------------------------------------------------------

DECLARE @Count_Transfer INT = 0;

SELECT @Count_Transfer = COUNT(ClaimPayBackTransferId)
FROM dbo.ClaimPayBackTransfer
WHERE ClaimPayBackTransferId = @ClaimBayBackTransferId
AND ClaimPayBackTransferStatusId = @ClaimPayBackTransferStatusId
AND IsActive = 1;


--Get listClaimPayBack
SELECT b.ClaimPayBackId
	   ,b.Amount
INTO #TmplstClaimPayback	
FROM dbo.ClaimPayBack b
	INNER JOIN dbo.ClaimPayBackTransfer t
		ON b.ClaimPayBackTransferId = t.ClaimPayBackTransferId
WHERE b.ClaimPayBackTransferId = @ClaimBayBackTransferId
AND b.IsActive = 1;


--Get listClaimPayBackDetail
SELECT c.ClaimPayBackXClaimId
		,c.ClaimPay
INTO #TmpUpdateClaimTransfer
FROM dbo.ClaimPayBackDetail d
	INNER JOIN #TmplstClaimPayback b
		ON d.ClaimPayBackId = b.ClaimPayBackId
	INNER JOIN dbo.ClaimPayBackXClaim c
		ON d.ClaimPayBackDetailId = c.ClaimPayBackDetailId
WHERE d.IsActive = 1
AND c.IsActive = 1;

DECLARE @Sum_AmountClaimPayBack		DECIMAL(16,2)
DECLARE @Sum_ClaimPay				DECIMAL(16,2)

SELECT @Sum_AmountClaimPayBack = SUM(Amount)
FROM #TmplstClaimPayback


SELECT @Sum_ClaimPay = SUM(ClaimPay)
FROM #TmpUpdateClaimTransfer

-- Validate Group Transfer ,TransferAmount = Amount in Amount (Payback,detail)
IF @IsResult = 1
BEGIN
    
	--Chk Group Transfer
	IF @Count_Transfer > 0
	BEGIN
	    SET @IsResult = 0;
		SET @Msg = 'กรุณาตรวจสอบ เนื่องจากมีการโอนเงินเรียบร้อยแล้ว';
	END
	ELSE IF (@TransferAmount <> @Sum_AmountClaimPayBack OR @TransferAmount <> @Sum_ClaimPay)
	BEGIN

		    SET @IsResult = 0;
			SET @Msg = 'กรุณาตรวจสอบ จำนวนเงินที่โอน เนื่องจากยอดเงินไม่ตรงกับในระบบ';

	END
	ELSE IF cast(@TransferDate AS TIME) = '00:00:00.0000000'
	BEGIN
	     SET @IsResult = 0;
		 SET @Msg = 'กรุณาตรวจสอบ เวลาโอนเงิน';
	END
	
END


IF @IsResult = 1
BEGIN

    DECLARE @countSubGroup INT = 0;

	SELECT @countSubGroup = COUNT(*)  
	FROM dbo.ClaimPayBackSubGroup
	WHERE ClaimPayBackTransferId = @ClaimBayBackTransferId

    BEGIN TRY	
		BEGIN TRANSACTION;

		--Update ClaimPayBackTransfer TransferAmount,TransferDate,Status
		UPDATE dbo.ClaimPayBackTransfer
			SET TransferAmount = IIF(ClaimGroupTypeId = 4,NULL,@TransferAmount)
				,TransferDate= IIF(ClaimGroupTypeId = 4,NULL,@TransferDate)
				,ClaimPayBackTransferStatusId = IIF(ClaimGroupTypeId = 4,2,@ClaimPayBackTransferStatusId)
				,UpdatedByUserId = @UpdatedByUserId
				,UpdatedDate = @D
				,OutOfPocketStatus = IIF(ClaimGroupTypeId = 4,3,NULL)
				,OutOfPocketAmount = IIF(ClaimGroupTypeId = 4,@TransferAmount,NULL)
				,OutOfPocketDate = IIF(ClaimGroupTypeId = 4,@TransferDate,NULL)
		FROM dbo.ClaimPayBackTransfer
		WHERE ClaimPayBackTransferId = @ClaimBayBackTransferId;


		--Update Status ClaimPayBack
		UPDATE dbo.ClaimPayBack
			SET ClaimPayBackStatusId = @ClaimPayBackStatusId
				,UpdatedByUserId = @UpdatedByUserId
				,UpdatedDate = @D 
		FROM dbo.ClaimPayBack b
			INNER JOIN #TmplstClaimPayback t
				ON b.ClaimPayBackId = t.ClaimPayBackId


		--Update ClaimTransfer in ClaimPayBackXClaim
		UPDATE dbo.ClaimPayBackXClaim
			SET ClaimTransfer = m.ClaimPay
				,UpdatedByUserId = @UpdatedByUserId
				,UpdatedDate = @D
		FROM dbo.ClaimPayBackXClaim m
			INNER JOIN #TmpUpdateClaimTransfer u
				ON m.ClaimPayBackXClaimId = u.ClaimPayBackXClaimId
		
		--Update เฉพาะเคลมที่มี SubGroup
		IF @countSubGroup > 0 
			BEGIN
			    UPDATE dbo.ClaimPayBackSubGroup
				SET BillingTransferDate = @TransferDate
					,UpdatedByUserId = @UpdatedByUserId
					,UpdatedDate = @D 
				WHERE ClaimPayBackTransferId = @ClaimBayBackTransferId;
			END

		SET @IsResult = 1;
        SET @Msg = 'บันทึกข้อมูล สำเร็จ';
        COMMIT TRANSACTION;

	END TRY
	BEGIN CATCH
       SET @IsResult = 0;
       SET @Msg = 'บันทึกข้อมูล ไม่สำเร็จ';
       IF @@TRANCOUNT > 0
           ROLLBACK;
    END CATCH;
END

DROP TABLE #TmplstClaimPayback;
DROP TABLE #TmpUpdateClaimTransfer;

IF @IsResult = 1 BEGIN	SET @Result = 'Success' END	
ELSE BEGIN				SET @Result = 'Failure' END;	

--SELECT @IsResult IsResult
--		,@Result Result
--		,@Msg	 Msg;
SELECT distinct @IsResult IsResult
		,@Result Result
		,@Msg	 Msg
		,vcol.ClaimOnLineId
		,vcol.ClaimOnLineItemId
		,cpb.ClaimPayBackCode
		,cpd.ClaimGroupCode
		,cpx.ClaimPayBackXClaimId
		,cpx.ClaimCode
		,cpx.ClaimPay
		,5 AS ReceiveTypeId
		,4 AS TransferTypeId
		,@UpdatedByUserId AS UpdatedByUserId		
		,@D AS UpdatedDate FROM dbo.ClaimPayBack cpb
LEFT JOIN dbo.ClaimPayBackDetail cpd ON cpd.ClaimPayBackId = cpb.ClaimPayBackId AND cpd.InsuranceCompanyId <> @InsuranceCompanyId
LEFT JOIN dbo.ClaimPayBackXClaim cpx ON cpx.ClaimPayBackDetailId = cpd.ClaimPayBackDetailId
INNER JOIN vw_ClaimOnlineItem vcol ON vcol.ClaimCode =cpx.ClaimCode
WHERE ClaimPayBackTransferId=@ClaimBayBackTransferId AND cpd.IsActive=1 AND cpx.IsActive =1 

   
END




