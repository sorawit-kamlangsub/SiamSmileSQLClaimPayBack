USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequest_Insert_V3]    Script Date: 30/10/2568 16:59:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Napaporn Saarnwong
-- Create date: 2022-12-16  09:05
-- Updated date: 2023-01-02 Improve and add PaySS_Total, CoverAmount, TotalAmount of dbo.BillingRequestGroup 
--				 2023-02-08 Add input data and improve script(i.BillingDate <= @BillingDateTo)
--				 2023-03-18 Add	insert ClaimHeaderGroupTypeId in BillingRequestGroup Sahatsawat golffy 06958
--				 2023-03-07 Add insert InsuranceCompanyName in BillingRequestGroup Sahatsawat golffy 06958
--				 2025-10-16	Add Parameter @CreatedDateFrom @CreatedDateTo Sorawit kem 
--				 2025-10-30 Add ClaimMisc ClaimHeaderGroupTypeId = 6 @ClaimHeaderGroupTypeId = 3 Sorawit Kamlangsub
-- Description:
-- =============================================
--ALTER PROCEDURE [dbo].[usp_BillingRequest_Insert_V3]
DECLARE
		@CreatedByUserId	INT	 = 1
		,@BillingDateTo		DATE = '2026-01-12'
		,@CreatedDateFrom	DATE = '2026-01-12'
		,@CreatedDateTo		DATE = '2026-01-12'

--AS
--BEGIN
--	SET NOCOUNT ON;


DECLARE @IsResult	BIT			 = 1;
DECLARE @Result		VARCHAR(100) = '';
DECLARE @Msg		NVARCHAR(500)= '';

IF (@IsResult = 0) SET @Msg = N'ปิดใช้งาน';


SELECT g.InsuranceCompanyId
      ,g.GroupTypeId
	  ,ROW_NUMBER() OVER(ORDER BY (g.InsuranceCompanyId) ASC ) AS rwId
	  ,g.ClaimTypeCode
	  ,g.BillingDate
	  ,g.ClaimHeaderGroupTypeId
	  ,g.InsuranceCompanyName
INTO #TmpLoop
FROM
		(	SELECT	i.InsuranceCompanyId
					,CASE 
						WHEN f.ClaimHeaderGroupTypeId = 2 THEN 1
						WHEN f.ClaimHeaderGroupTypeId = 3 THEN 2
						WHEN f.ClaimHeaderGroupTypeId = 4 THEN 1
						WHEN f.ClaimHeaderGroupTypeId = 5 THEN 1
						WHEN f.ClaimHeaderGroupTypeId = 6 THEN 3
						ELSE NULL
						END	GroupTypeId
					,i.ClaimTypeCode
					,i.BillingDate
					,f.ClaimHeaderGroupTypeId
					,i.InsuranceCompanyName
			FROM	dbo.ClaimHeaderGroupImport AS i
					INNER JOIN dbo.ClaimHeaderGroupImportFile AS f
						ON i.ClaimGroupImportFileId = f.ClaimHeaderGroupImportFileId
			WHERE	f.IsActive = 1
			AND		i.IsActive = 1
			AND		i.ClaimHeaderGroupImportStatusId = 2
			AND		i.BillingRequestGroupId IS NULL
			AND		i.BillingDate <= @BillingDateTo
		) AS g
WHERE	g.GroupTypeId IS NOT NULL	
GROUP BY	g.InsuranceCompanyId
			,g.GroupTypeId
			,g.ClaimTypeCode
			,g.BillingDate
			,g.ClaimHeaderGroupTypeId
			,g.InsuranceCompanyName;

DECLARE @TmpResult TABLE (IsResult BIT, Result VARCHAR(100), Msg NVARCHAR(MAX));
DECLARE @TmpInput TABLE (RwId INT,ClaimTypeCode VARCHAR(100),ProductTypeId INT,ProductTypeShortName VARCHAR(100));

--WHILE Loop---------------------------------
DECLARE @max INT;

SELECT	@max = MAX(rwId)
FROM	#TmpLoop;

SELECT	*
FROM	#TmpLoop;

IF (@max IS NULL) SET @max = 0;

DECLARE @intFlag INT;
SET @intFlag = 1;
WHILE ( @intFlag <= @max )
    BEGIN
		------------------------------
		DECLARE @GroupTypeId			INT;
		DECLARE @InsuranceCompanyId		INT;
        DECLARE @ClaimTypeCode			VARCHAR(20);
		DECLARE @BillingDate			DATE;
		DECLARE @ClaimHeaderGroupTypeId INT; 
		DECLARE @InsuranceCompanyName	NVARCHAR(300);

        SELECT	@InsuranceCompanyId		= InsuranceCompanyId
				,@GroupTypeId			= GroupTypeId
				,@ClaimTypeCode			= ClaimTypeCode
				,@BillingDate			= BillingDate
				,@ClaimHeaderGroupTypeId = ClaimHeaderGroupTypeId
				,@InsuranceCompanyName	= InsuranceCompanyName
        FROM	#TmpLoop
		WHERE	rwId = @intFlag;

		IF (@ClaimHeaderGroupTypeId = 6)
			BEGIN
				
				DECLARE @maxInput INT;
				DECLARE @inputFlag INT;

				INSERT INTO @TmpInput(RwId,ClaimTypeCode,ProductTypeId,ProductTypeShortName)
				SELECT	ROW_NUMBER() OVER(ORDER BY (cm.ProductTypeShortName) ASC ) AS rwId
						,i.ClaimTypeCode		
						,cm.ProductTypeId
						,cm.ProductTypeShortName
				FROM	dbo.ClaimHeaderGroupImport AS i
						INNER JOIN dbo.ClaimHeaderGroupImportFile AS f
							ON i.ClaimGroupImportFileId = f.ClaimHeaderGroupImportFileId
						INNER JOIN #TmpLoop lp
							ON lp.InsuranceCompanyId = i.InsuranceCompanyId
						LEFT JOIN 
						(
							SELECT
								cm.ClaimHeaderGroupCode
								,cm.ProductTypeId
								,pt.ProductTypeShortName
							FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
								LEFT JOIN [ClaimMiscellaneous].[misc].[ProductType] pt
									ON pt.ProductTypeId = cm.ProductTypeId
							WHERE cm.IsActive = 1
						) cm
							ON cm.ClaimHeaderGroupCode = i.ClaimHeaderGroupCode
				WHERE	f.IsActive = 1
				AND		i.IsActive = 1
				AND		i.ClaimHeaderGroupImportStatusId = 2
				AND		i.BillingRequestGroupId IS NULL
				AND		i.BillingDate <= @BillingDateTo		
				GROUP BY cm.ProductTypeId,cm.ProductTypeShortName,i.ClaimTypeCode

				SELECT	@maxInput = MAX(RwId)
				FROM	@TmpInput;

				SET @inputFlag = 1;
				DECLARE @ProductTypeId		  INT;
				DECLARE @ProductTypeShortName VARCHAR(20);

				WHILE ( @inputFlag <= @maxInput )
					BEGIN

						SELECT 
							@ProductTypeId = ProductTypeId
							,@ProductTypeShortName = ProductTypeShortName
						FROM @TmpInput
						WHERE RwId = @inputFlag

						SET @inputFlag = @inputFlag + 1;

					--INSERT INTO @TmpResult ( IsResult, Result, Msg)
					--EXECUTE [dbo].[usp_BillingRequest_ClaimMisc_Insert] 
					--					@GroupTypeId
					--					,@ClaimTypeCode
					--					,@InsuranceCompanyId
					--					,@CreatedByUserId
					--					,@BillingDate 
					--					,@ClaimHeaderGroupTypeId
					--					,@InsuranceCompanyName
					--					,@BillingDateTo
					--					,@CreatedDateFrom
					--					,@CreatedDateTo
					--					,@ProductTypeShortName
					--					,@ProductTypeId				

						PRINT @ProductTypeId
					END
				
			END
		ELSE
			BEGIN
				--INSERT INTO @TmpResult ( IsResult, Result, Msg)

		/* Original
				EXECUTE [dbo].[usp_BillingRequest_Sub01_Insert] 
							@GroupTypeId
							,@ClaimTypeCode
							,@InsuranceCompanyId
							,@CreatedByUserId
							,@BillingDate 
							,@ClaimHeaderGroupTypeId
							,@InsuranceCompanyName
		*/
				--EXECUTE [dbo].[usp_BillingRequest_Sub01_Insert_V2] 
				--					@GroupTypeId
				--					,@ClaimTypeCode
				--					,@InsuranceCompanyId
				--					,@CreatedByUserId
				--					,@BillingDate 
				--					,@ClaimHeaderGroupTypeId
				--					,@InsuranceCompanyName
				--					,@BillingDateTo
				--					,@CreatedDateFrom
				--					,@CreatedDateTo
				PRINT ''
			END;
		------------------------------
        SET @intFlag = @intFlag + 1;
    END;
---------------------------------------------

SELECT * FROM @TmpInput

IF OBJECT_ID('tempdb..#TmpLoop') IS NOT NULL  DROP TABLE #TmpLoop;	


IF (@max = 0)
	BEGIN
		SET @IsResult	= 0;
		SET @Msg		= N'ไม่พบรายการ';
	END
ELSE
	BEGIN
		DECLARE @SuccessCount INT;

		SELECT	@SuccessCount = COUNT(IsResult)
		FROM	@TmpResult
		WHERE	IsResult = 1

		SET @IsResult	= 1;
		SET @Msg		= CONCAT(	'บันทึก สำเร็จ '
									,'(จำนวน: ', @SuccessCount, '/', @max,' ) '
								);
	END;

IF (@IsResult = 1) 
BEGIN	
	SET @Result = 'Success';
END	
ELSE
BEGIN
	SET @Result = 'Failure';
END;	

SELECT @IsResult IsResult
		,@Result Result
		,@Msg	 Msg;

--END;


