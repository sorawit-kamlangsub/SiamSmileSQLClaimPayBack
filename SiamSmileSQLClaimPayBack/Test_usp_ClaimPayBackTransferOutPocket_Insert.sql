USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackSubGroup_Insert]    Script Date: 28/1/2569 11:10:01 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
--/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackTransferOutPocket_Insert]    Script Date: 10/25/2023 9:30:52 AM ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

-- =============================================
-- Author:		Sorawit.k 08719
-- Create date: 20260128
-- Update date: 
-- Description:	Group CPT โอนเงินสำรองจ่าย
-- =============================================
--ALTER PROCEDURE [dbo].[usp_ClaimPayBackTransferOutPocket_Insert]
-- Add the parameters for the stored procedure here
	--@ClaimPayBackTransferId		INT
	--,@CreatedByUserId			INT
--AS
--BEGIN
--	-- SET NOCOUNT ON added to prevent extra result sets from
--	-- interfering with SELECT statements.
--	SET NOCOUNT ON;

	-- For Test
	DECLARE @ClaimPayBackTransferId NVARCHAR(MAX) = '4149';--'2924,2925'
	DECLARE @CreatedByUserId INT = 1

	-- Add the parameters for the stored procedure here
	DECLARE @IsResult			BIT				= 1;
	DECLARE @Result				VARCHAR(100)	= '';
	DECLARE @Msg				NVARCHAR(500)	= '';

	DECLARE @CreatedDate				DATETIME2 = GETDATE();
	DECLARE @ClaimPayBackSubGroupCount	INT = 0;
	DECLARE @ClaimGroupTypeId			INT;
	DECLARE @OutOfPocketAmountLimit		DECIMAL(16,2);
	
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
			--AND cpt.OutOfPocketStatus IS NULL

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
				SUM(SumAmount) OVER (
					PARTITION BY ClaimPayBackTransferId
				) AS SumAmountTotal  ,
				CASE
					WHEN SUM(SumAmount) OVER (
						PARTITION BY ClaimPayBackTransferId
					) < @OutOfPocketAmountLimit THEN 1
					ELSE 0
				END AS IsNoneLimit
			INTO #TmpGroup
			FROM #TmpSubGroupDetail
			ORDER BY ClaimPayBackTransferId; 

			DECLARE @TmpGroupTotal TABLE (ClaimPayBackTransferId INT,SumAmountTotal DECIMAL(16,0))

			INSERT INTO @TmpGroupTotal(ClaimPayBackTransferId,SumAmountTotal)
			SELECT 
				ClaimPayBackTransferId
				, SumAmountTotal	
			FROM #TmpGroup
			GROUP BY ClaimPayBackTransferId,SumAmountTotal,IsNoneLimit
			HAVING IsNoneLimit = 1; 

			INSERT INTO @TmpGroupTotal(ClaimPayBackTransferId,SumAmountTotal)
			SELECT 
				ClaimPayBackTransferId
				, SumAmount	
			FROM #TmpGroup
			GROUP BY ClaimPayBackTransferId,SumAmount,IsNoneLimit
			HAVING IsNoneLimit = 0; 

			SELECT 
				ROW_NUMBER() OVER (ORDER BY ClaimPayBackTransferId ASC) AS rwId
				,ClaimPayBackTransferId
				,SumAmountTotal
			INTO #TmpGroupTotalRunNo
			FROM @TmpGroupTotal

			SELECT 
				ROW_NUMBER() OVER (ORDER BY ClaimPayBackTransferId ASC) AS rwId
				,ClaimPayBackTransferId
				,SumAmountTotal
				,COUNT(*) OVER (
					PARTITION BY 
						CASE 
							WHEN IsNoneLimit = 1 THEN SumAmountTotal
							ELSE SumAmount
						END
				) AS ItemCount
			INTO #TmpItemCount
			FROM #TmpGroup

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
	

				--INSERT INTO dbo.ClaimPayBackSubGroup
				--(
				--	ClaimPayBackSubGroupCode
				--	, Amount
				--	, ItemCount
				--	, HospitalCode
				--	, HospitalName
				--	, ClaimPayBackTransferId
				--	, IsActive
				--	, CreatedDate
				--	, CreatedByUserId
				--	, UpdatedDate
				--	, UpdatedByUserId
				--	, ContactEmail
				--)
				--OUTPUT INSERTED.ClaimPayBackSubGroupId, INSERTED.ClaimPayBackTransferId INTO @GeneratedIds (ClaimPayBackSubGroupId, ClaimPayBackTransferId)
				SELECT 
					CONCAT(@TT,@YY,@MM ,FORMAT(@RunningFrom + t.rwId - 1,'000000')) ClaimPayBackSubGroupCode
					, t.SumAmountTotal
					, 
						(
							SELECT TOP 1 ItemCount
							FROM #TmpItemCount tg
							WHERE tg.ClaimPayBackTransferId = t.ClaimPayBackTransferId
						)	ItemCount
					, t.ClaimPayBackTransferId
					, 1							IsActive						 
					, @CreatedDate				CreatedDate
					, @CreatedByUserId			CreatedByUserId
					, @CreatedDate				UpdatedDate
					, @CreatedByUserId			UpdatedByUserId
				FROM #TmpGroupTotalRunNo t

				--INSERT INTO dbo.ClaimPayBackSubGroupDetail
				--(
				--	ClaimPayBackId
				--	,Amount
				--	,ClaimPayBackSubGroupId
				--	,IsActive
				--	,CreatedByUserId
				--	,CreatedDate
				--	,UpdatedByUserId
				--	,UpdatedDate
				--)
				SELECT 
				 d.ClaimPayBackId
				 ,d.SumAmount
				 ,g.ClaimPayBackSubGroupId
				 ,1							IsActive
				 , @CreatedByUserId			CreatedByUserId
				 , @CreatedDate				CreatedDate
				 , @CreatedByUserId			UpdatedByUserId
				 , @CreatedDate				UpdatedDate
				FROM #TmpSubGroupDetail d
				LEFT JOIN @GeneratedIds g
					ON g.ClaimPayBackTransferId = d.ClaimPayBackTransferId

				-- อัปเดต ClaimPayBackDetail ด้วย ClaimPayBackSubGroupId
				SELECT *
				--UPDATE CPBD
				--SET CPBD.ClaimPayBackSubGroupId = GID.ClaimPayBackSubGroupId
				--	, CPBD.UpdatedDate = @CreatedDate
				--	, CPBD.UpdatedByUserId = @CreatedByUserId
				FROM dbo.ClaimPayBackDetail CPBD
				INNER JOIN #TmpD TD 
					ON CPBD.ClaimPayBackDetailId = TD.ClaimPayBackDetailId
				LEFT JOIN @GeneratedIds g
					ON g.ClaimPayBackTransferId = TD.ClaimPayBackTransferId
	
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

		IF OBJECT_ID('tempdb..#TmpD') IS NOT NULL  DROP TABLE #TmpD;
		IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;
		IF OBJECT_ID('tempdb..#TmpGroup') IS NOT NULL  DROP TABLE #TmpGroup;
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
	
--END;