USE [ClaimPayBack]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Sorawit.k 08719
-- Create date: 20260128
-- Update date: 
-- Description:	Group CPT โอนเงินสำรองจ่าย
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackTransferOutPocket_Insert]
 --Add the parameters for the stored procedure here
	@ClaimPayBackTransferId		INT
	,@CreatedByUserId			INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- For Test
	--DECLARE @ClaimPayBackTransferId NVARCHAR(MAX) = '4147';--'4141,4148' 4147
	--DECLARE @CreatedByUserId INT = 1

	-- Add the parameters for the stored procedure here
	DECLARE @IsResult			BIT				= 1;
	DECLARE @Result				VARCHAR(100)	= '';
	DECLARE @Msg				NVARCHAR(500)	= '';

	DECLARE @CreatedDate				DATETIME2 = GETDATE();
	DECLARE @ClaimPayBackSubGroupCount	INT = 0;
	DECLARE @ClaimGroupTypeId			INT;
	DECLARE @OutOfPocketAmountLimit		DECIMAL(16,2);
	DECLARE @TransactionDetail			NVARCHAR(500)	= ''; 
	
	SELECT @TransactionDetail = OutOfPocketStatusName FROM dbo.ClaimPayBackOutOfPocketStatus WHERE OutOfPocketStatusId = 2;
	SELECT @OutOfPocketAmountLimit = ValueNumber FROM dbo.ProgramConfig WHERE ParameterName = 'OutOfPocketAmountLimit'

	SELECT DISTINCT Element
	INTO #Tmplst
	from dbo.func_SplitStringToTable(@ClaimPayBackTransferId,',');

	IF (@IsResult = 1)
		BEGIN

			SELECT cd.ClaimPayBackDetailId
					,c.ClaimPayBackCode				CPGCode
					,c.ClaimPayBackId
					, cd.ClaimPayBackDetailCode		
					, cpt.ClaimPayBackTransferCode
					, cd.ItemCount					ItemCountDetail
					, cd.Amount
					, cd.CreatedDate
					, c.ClaimPayBackTransferId					
			INTO #TmpD
			FROM dbo.ClaimPayBackDetail cd
			INNER JOIN dbo.ClaimPayBack c
				ON cd.ClaimPayBackId = c.ClaimPayBackId
			INNER JOIN dbo.ClaimPayBackTransfer cpt
				ON cpt.ClaimPayBackTransferId = c.ClaimPayBackTransferId
			INNER JOIN #Tmplst tl
				ON tl.Element = c.ClaimPayBackTransferId
			WHERE cd.IsActive = 1	
			AND c.IsActive = 1
			AND cpt.IsActive = 1
			AND cpt.OutOfPocketStatus = 2

			SELECT 
					ROW_NUMBER() OVER(ORDER BY (ClaimPayBackTransferId) asc ) AS rwId
					, COUNT(ClaimPayBackDetailId)		ItemCountDetail
					, SUM(Amount)					SumAmount 
					, ClaimPayBackId
					, ClaimPayBackTransferId
			INTO #TmpSubGroupDetail
			FROM #TmpD
			GROUP BY ClaimPayBackId,ClaimPayBackTransferId;

			SELECT
				ROW_NUMBER() OVER (ORDER BY ClaimPayBackTransferId ASC) AS rwId,				
				ClaimPayBackTransferId,
				SumAmount,                                  
				ClaimPayBackId
			INTO #TmpGroup
			FROM #TmpSubGroupDetail
			ORDER BY ClaimPayBackTransferId; 
			
			SELECT
				ROW_NUMBER() OVER (ORDER BY ClaimPayBackTransferId) AS rn
				,ClaimPayBackTransferId
				,SumAmount
				,ClaimPayBackId
			INTO #Src
			FROM #TmpGroup;

			DECLARE @SumResult TABLE (
				ClaimPayBackTransferId INT,
				ClaimPayBackId INT,
				SumAmountTotal DECIMAL(18,2),
				GroupNo INT
			);

			DECLARE 
				@i INT = 1,
				@max INT,
				@runningSum DECIMAL(18,2) = 0,
				@groupNo INT = 1,
				@amount DECIMAL(18,2),
				@ClaimPayBackTransferId2 INT,
				@ClaimPayBackId INT;

			SELECT @max = MAX(rn) FROM #Src;

			WHILE @i <= @max
			BEGIN
				SELECT 
					@amount = SumAmount
					,@ClaimPayBackTransferId2   = ClaimPayBackTransferId
					,@ClaimPayBackId = ClaimPayBackId
				FROM #Src
				WHERE rn = @i;

				IF @runningSum + @amount > @OutOfPocketAmountLimit
				BEGIN
					SET @groupNo = @groupNo + 1;
					SET @runningSum = 0;
				END

				SET @runningSum = @runningSum + @amount;

				INSERT INTO @SumResult
				VALUES (@ClaimPayBackTransferId2,@ClaimPayBackId, @amount, @groupNo);

				SET @i = @i + 1;
			END

			SELECT
				ClaimPayBackTransferId,
				GroupNo,
				SUM(SumAmountTotal) AS SumAmountTotal
			INTO #TmpSumResult
			FROM @SumResult
			GROUP BY ClaimPayBackTransferId, GroupNo
			ORDER BY GroupNo;			

			SELECT 
				ROW_NUMBER() OVER (ORDER BY ClaimPayBackTransferId ASC) AS rwId
				,ClaimPayBackTransferId
				,SumAmountTotal
				,GroupNo
			INTO #TmpGroupTotalRunNo
			FROM #TmpSumResult

			SELECT ClaimPayBackTransferId
				,COUNT(GroupNo) AS ItemCount
				,GroupNo
			INTO #TmpItemCount
			FROM @SumResult
			GROUP BY ClaimPayBackTransferId, GroupNo

			DECLARE @TT          VARCHAR(6) = 'OCG'
				  , @Total		 INT 
				  , @YY          VARCHAR(2)
				  , @MM          VARCHAR(2)
				  , @RunningFrom INT
				  , @RunningTo   INT;

			SELECT @Total = MAX(rwId) FROM #TmpGroupTotalRunNo;

			EXECUTE dbo.usp_GenerateCode_FromTo @TT -- varchar(6)
										   , @Total -- int
										   , @YY OUTPUT -- varchar(2)
										   , @MM OUTPUT -- varchar(2)
										   , @RunningFrom OUTPUT -- int
										   , @RunningTo OUTPUT -- int

	
			-- สร้าง ClaimPayBackSubGroup และเก็บ ClaimPayBackSubGroupId ที่สร้างขึ้นใหม่
			DECLARE @GeneratedIds TABLE (ClaimPayBackSubGroupId INT,ClaimPayBackTransferId INT)

			-----------------------------------
			BEGIN TRY
				BEGIN TRANSACTION
	

				INSERT INTO dbo.ClaimPayBackSubGroup
				(
					ClaimPayBackSubGroupCode
					, Amount
					, ItemCount
					, HospitalCode
					, HospitalName
					, ClaimPayBackTransferId
					, IsActive
					, CreatedDate
					, CreatedByUserId
					, UpdatedDate
					, UpdatedByUserId
					, ContactEmail
				)
				OUTPUT INSERTED.ClaimPayBackSubGroupId, INSERTED.ClaimPayBackTransferId INTO @GeneratedIds (ClaimPayBackSubGroupId, ClaimPayBackTransferId)
				SELECT 
					CONCAT(@TT,@YY,@MM ,FORMAT(@RunningFrom + t.rwId - 1,'000000')) ClaimPayBackSubGroupCode
					, t.SumAmountTotal
					, ic.ItemCount				ItemCount
					, NULL						HospitalCode
					, NULL						HospitalName
					, t.ClaimPayBackTransferId
					, 1							IsActive						 
					, @CreatedDate				CreatedDate
					, @CreatedByUserId			CreatedByUserId
					, @CreatedDate				UpdatedDate
					, @CreatedByUserId			UpdatedByUserId
					, NULL						ContactEmail
				FROM #TmpGroupTotalRunNo t
					INNER JOIN 
					(
						SELECT GroupNo, ItemCount AS ItemCount
						FROM #TmpItemCount
						GROUP BY GroupNo, ItemCount
					) ic 
						ON ic.GroupNo = t.GroupNo

				DECLARE @OffsetGNo INT = 1,
						@TotalGroupNoCount INT;
				SELECT @TotalGroupNoCount = COUNT(DISTINCT GroupNo) FROM @SumResult;

				WHILE @OffsetGNo <= @TotalGroupNoCount
					BEGIN 				
						
						INSERT INTO dbo.ClaimPayBackSubGroupDetail
						(
							ClaimPayBackId
							,Amount
							,ClaimPayBackSubGroupId
							,IsActive
							,CreatedByUserId
							,CreatedDate
							,UpdatedByUserId
							,UpdatedDate
						)
						SELECT 
						 s.ClaimPayBackId
						 ,d.SumAmount
						 ,g.ClaimPayBackSubGroupId
						 ,1							IsActive
						 , @CreatedByUserId			CreatedByUserId
						 , @CreatedDate				CreatedDate
						 , @CreatedByUserId			UpdatedByUserId
						 , @CreatedDate				UpdatedDate
						FROM #TmpSubGroupDetail d
						INNER JOIN @SumResult s
							ON s.ClaimPayBackId = d.ClaimPayBackId
						LEFT JOIN @GeneratedIds g
							ON g.ClaimPayBackTransferId = d.ClaimPayBackTransferId		
						WHERE s.GroupNo = @OffsetGNo

						SET @OffsetGNo = @OffsetGNo + 1;
					END

				-- อัปเดต ClaimPayBackDetail ด้วย ClaimPayBackSubGroupId
				--SELECT *
				UPDATE CPBD
				SET CPBD.ClaimPayBackSubGroupId = g.ClaimPayBackSubGroupId
					, CPBD.UpdatedDate = @CreatedDate
					, CPBD.UpdatedByUserId = @CreatedByUserId
				FROM dbo.ClaimPayBackDetail CPBD
				INNER JOIN #TmpD TD 
					ON CPBD.ClaimPayBackDetailId = TD.ClaimPayBackDetailId
				LEFT JOIN @GeneratedIds g
					ON g.ClaimPayBackTransferId = TD.ClaimPayBackTransferId


				INSERT INTO dbo.ClaimPayBackTransferTransaction
				(
					TransactionDetail
					,TransactionDetailId
					,ClaimPayBackTransferId
					,IsActive
					,CreatedByUserId
					,CreatedDate
				)
				SELECT DISTINCT
				 @TransactionDetail			TransactionDetail
				 ,2							TransactionDetailId
				 ,ClaimPayBackTransferId	ClaimPayBackTransferId
				 ,1							IsActive
				 ,@CreatedByUserId			CreatedByUserId
				 ,@CreatedDate				CreatedDate
				FROM #TmpGroupTotalRunNo
	
				SET @IsResult   = 1;
				SET @Msg        = 'บันทึก สำเร็จ';
	
				COMMIT TRANSACTION
			END TRY
			BEGIN CATCH
	
				SET @IsResult   = 0;
				SET @Msg        = 'บันทึก ไม่สำเร็จ' + ERROR_MESSAGE();
	
				IF (@@Trancount > 0) ROLLBACK;
			END CATCH
			-----------------------------------

		IF OBJECT_ID('tempdb..#Src') IS NOT NULL  DROP TABLE #Src;
		IF OBJECT_ID('tempdb..#TmpD') IS NOT NULL  DROP TABLE #TmpD;
		IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;
		IF OBJECT_ID('tempdb..#TmpGroup') IS NOT NULL  DROP TABLE #TmpGroup;
		IF OBJECT_ID('tempdb..#TmpSumResult') IS NOT NULL  DROP TABLE #TmpSumResult;
		IF OBJECT_ID('tempdb..#TmpItemCount') IS NOT NULL  DROP TABLE #TmpItemCount;
		IF OBJECT_ID('tempdb..#TmpSubGroupDetail') IS NOT NULL  DROP TABLE #TmpSubGroupDetail;
		IF OBJECT_ID('tempdb..#TmpGroupTotalRunNo') IS NOT NULL  DROP TABLE #TmpGroupTotalRunNo;
	
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
	
END;