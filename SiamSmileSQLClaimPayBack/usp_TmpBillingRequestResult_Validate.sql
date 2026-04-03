USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_TmpBillingRequestResult_Validate]    Script Date: 3/4/2569 9:35:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Napaporn Saarnwong
-- Create date: 2022-11-15  11:29
-- Update date: 
-- Description:	
-- =============================================
ALTER PROCEDURE [dbo].[usp_TmpBillingRequestResult_Validate]
	@TmpCode VARCHAR(20)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @IsResult			BIT				= 1;
	DECLARE @Result				VARCHAR(100)	= '0';
	DECLARE @Msg				NVARCHAR(500)	= '';

	DECLARE	@Count				INT;
	DECLARE @CountIsError		INT;
	DECLARE @ApproveStatus		NVARCHAR(20)	= N'อนุมัติ';
	DECLARE @DenyStatus			NVARCHAR(20)	= N'ปฏิเสธ';

	--Select 0r other process
	SELECT	TmpBillingRequestResultId
			,TmpCode
			,BillingRequestItemCode
			,PaymentReferenceId
			,CoverAmount
			,UncoverAmount
			,UnCoverRemark
			,DecisionStatus
			,RejectResult
			,DecisionDate
			,EstimatePaymentDate
			,Remark
			,IsValid
			,ValidateResult
	INTO	#TmpReceive
	FROM	dbo.TmpBillingRequestResult
	WHERE	TmpCode = @TmpCode;

	SELECT	@Count	= COUNT(TmpCode)
	FROM	#TmpReceive;

	IF(@Count IS NULL) SET @Count = 0;

	IF (@Count = 0)
	BEGIN
	    SET @IsResult	= 0;
		SET @Msg		= N'ไม่พบข้อมูล';
	END;

	IF (@IsResult = 0) SET @Msg = N'ปิดใช้งาน';
	
	--Process
	IF (@IsResult = 1)
	BEGIN

		SELECT	r.TmpBillingRequestResultId
				,r.TmpCode
				,r.BillingRequestItemCode
				,r.PaymentReferenceId
				,r.CoverAmount
				,r.UncoverAmount
				,r.UnCoverRemark
				,r.DecisionStatus
				,r.RejectResult
				,r.DecisionDate
				,r.EstimatePaymentDate
				,r.Remark
				,r.IsValid
				,CONCAT(	IIF(r.DecisionStatus IN (@ApproveStatus, @DenyStatus) , '', N'สถานะไม่ถูกต้อง ')
							,IIF(c.BillingRequestItemCode IS NOT NULL, N'ซ้ำกันในไฟล์ ' , '')
							,IIF(bd.BillingRequestItemCode IS NOT NULL, N'ข้อมูลนี้นำส่งแล้ว ', '')
							,IIF(bi.BillingRequestItemCode IS NULL, N'ไม่พบรหัสนี้ในระบบ', '')
						) AS ValidateResult
		INTO	#TmpUpdate
		FROM	#TmpReceive AS r
				LEFT JOIN 
					(	SELECT	BillingRequestItemCode
						FROM	#TmpReceive AS r
						GROUP BY BillingRequestItemCode
						HAVING COUNT(TmpBillingRequestResultId) > 1
					) AS c
					ON r.BillingRequestItemCode = c.BillingRequestItemCode
				LEFT JOIN dbo.BillingRequestResultDetail AS bd
					ON r.BillingRequestItemCode = bd.BillingRequestItemCode
				LEFT JOIN 
					(	SELECT	BillingRequestItemId
								,BillingRequestItemCode
								,BillingRequestGroupId
								,ClaimHeaderGroupImportDetailId
								,PaySS_Total
								,CoverAmount
								,AmountTotal
								,IsActive
								,CreatedDate
								,CreatedByUserId
								,UpdatedDate
								,UpdatedByUserId
						FROM	dbo.BillingRequestItem
						WHERE	IsActive = 1
					) AS bi
					ON r.BillingRequestItemCode = bi.BillingRequestItemCode;
		

		SELECT	@CountIsError = COUNT(ValidateResult)
		FROM	#TmpUpdate
		WHERE	TmpCode = @TmpCode
		AND		ValidateResult <> '';

		-----------------------------------
		BEGIN TRY
			BEGIN TRANSACTION

			--Update
			UPDATE	m
			SET		m.IsValid			= IIF(u.ValidateResult <> '', 0, 1)
					,m.ValidateResult	= u.ValidateResult
			FROM	dbo.TmpBillingRequestResult AS m
					INNER JOIN #TmpUpdate AS u
						ON m.TmpBillingRequestResultId = u.TmpBillingRequestResultId;

			SET @IsResult   = 1;
			SET @Msg        = 'บันทึก สำเร็จ';

			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH

			SET @IsResult   = 0;
			SET @Msg        = 'บันทึก ไม่สำเร็จ';

			IF (@@Trancount > 0) ROLLBACK;
		END CATCH
		-----------------------------------

		--Drop 
		IF OBJECT_ID('tempdb..#TmpReceive') IS NOT NULL  DROP TABLE #TmpReceive;	
		IF OBJECT_ID('tempdb..#TmpUpdate') IS NOT NULL  DROP TABLE #TmpUpdate;

	END;

	IF (@IsResult = 1) 
	BEGIN	
		SET @Result = IIF(@CountIsError = 0, 1, 0);
	END
	ELSE 
	BEGIN				
		SET @Result = 'Failure';
	END;

	SELECT	@IsResult	AS IsResult
			,@Result	AS Result
			,@Msg		AS Msg;

	--DECLARE @x bit
	--	SELECT @x AS IsResult
	--,'' AS Result
	--,'' AS Msg
END;