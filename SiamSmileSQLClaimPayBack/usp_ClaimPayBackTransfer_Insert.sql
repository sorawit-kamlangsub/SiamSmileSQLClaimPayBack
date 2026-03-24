USE [ClaimPayBack]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Prattana Phiwkaew
-- Create date: 2021-10-06 15:52
-- Description:	ClaimPayBackTransfer Insert
-- Update By:	Krekpon Mind 06588
-- Update Date:	2024-08-09
-- Update Date:	2026-01-27 14:38 Sorawit 
--				Add OutOfPocket status set to 7
-- Description:	Add Status Hospital When Add
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackTransfer_Insert] 
	-- Add the parameters for the stored procedure here
	 @ClaimPayBackIdList		NVARCHAR(MAX)
	,@ClaimGroupTypeId			INT
	,@UpdatedByUserId			INT

AS	
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

---------------------------------------------------------

DECLARE @IsResult			BIT			 = 1;
DECLARE @Result				VARCHAR(100) = '';
DECLARE @Msg				NVARCHAR(500)= 'Not allowed to use';

DECLARE @D		DATETIME = GETDATE();
DECLARE @ClaimPayBackStatusId	INT = 3;
DECLARE @ClaimPayBackTransferStatusId	INT = 2;
--------------------------------------------------------------
DECLARE @SumAmount	DECIMAL(16,2)

--Add Status Hospital When Add 2024-08-09
IF @ClaimGroupTypeId = 4
	BEGIN
		SET @ClaimPayBackTransferStatusId = 5
	END

SELECT Element ClaimPayBackId
INTO #TmplstClaimPayBack
FROM dbo.func_SplitStringToTable(@ClaimPayBackIdList,',')

DECLARE @Count INT = 0;
DECLARE @Count_Group INT = 0;

SELECT @Count = COUNT(ClaimPayBackId) 
FROM #TmplstClaimPayBack
WHERE ClaimPayBackId = '';

SELECT @Count_Group = COUNT(b.ClaimPayBackId)
FROM dbo.ClaimPayBack b
	INNER JOIN #TmplstClaimPayBack t
		ON b.ClaimPayBackId = t.ClaimPayBackId
WHERE b.ClaimPayBackTransferId IS NOT NULL
AND b.IsActive = 1;


--validate Split ClaimPayBack
--Chk Group 
IF @IsResult = 1
BEGIN
	--Chk null in claimpaybackIdlist
	IF @Count > 0
		BEGIN
		    SET @IsResult = 0;
			SET @Msg = 'กรุณาตรวจสอบ รายการที่ส่งมา เนื่องจากไม่มีข้อมูลในระบบ';
		END
	ELSE
		BEGIN
		    --Chk Group in claimPayback
			IF @Count_Group > 0
			BEGIN
			    SET @IsResult = 0;
				SET @Msg = 'กรุณาตรวจสอบรายการ เนื่องจากมีบางรายการโอนเงินเรียบร้อยแล้ว';
			END
		END
		
END


-- Insert Tmplst ClaimPayBackId
SELECT b.ClaimPayBackId	
	   ,b.Amount		ClaimPayBackAmount
INTO #Tmplist 
FROM dbo.ClaimPayBack b
	INNER JOIN #TmplstClaimPayBack l
		ON b.ClaimPayBackId = l.ClaimPayBackId;


--Get SumAmount 
SELECT  @SumAmount = SUM(ClaimPayBackAmount)
FROM #Tmplist;


IF @IsResult = 1
BEGIN
	
	--Gen ClaimPayBackTransferCode
	DECLARE @ClaimPayBackTransferCode	VARCHAR(20)
	EXEC dbo.usp_GenerateCode 'CPBT',8,@ClaimPayBackTransferCode  OUTPUT

    BEGIN TRY	
		BEGIN TRANSACTION;

		--Create ClaimPayBackTransfer
		INSERT INTO dbo.ClaimPayBackTransfer
					(ClaimPayBackTransferCode
					,ClaimGroupTypeId
					,Amount
					,TransferAmount
					,ClaimPayBackTransferStatusId
					,IsActive
					,CreatedByUserId
					,CreatedDate
					,UpdatedByUserId
					,UpdatedDate
					,OutOfPocketStatus)
			SELECT @ClaimPayBackTransferCode
				   ,@ClaimGroupTypeId
				   ,@SumAmount
				   ,0
				   ,@ClaimPayBackTransferStatusId
				   ,1
				   ,@UpdatedByUserId
				   ,@D
				   ,@UpdatedByUserId
				   ,@D
				   ,7

		DECLARE @ClaimPayBackTransferId INT = SCOPE_IDENTITY();

		--Update ClaimPayBack
		UPDATE dbo.ClaimPayBack
			SET ClaimPayBackStatusId = @ClaimPayBackStatusId
			   ,ClaimPayBackTransferId = @ClaimPayBackTransferId
			   ,UpdatedByUserId = @UpdatedByUserId
			   ,UpdatedDate = @D
		FROM dbo.ClaimPayBack b
			INNER JOIN #Tmplist l
				ON b.ClaimPayBackId = l.ClaimPayBackId

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

DROP TABLE #TmplstClaimPayBack;
DROP TABLE #Tmplist;

IF @IsResult = 1 BEGIN	SET @Result = 'Success' END	
ELSE BEGIN				SET @Result = 'Failure' END;	

SELECT @IsResult IsResult
		,@Result Result
		,@Msg	 Msg;


   
END



