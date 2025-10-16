﻿USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequest_Insert_V3]    Script Date: 16/10/2568 10:21:15 ******/
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
-- Description:
-- =============================================
ALTER PROCEDURE [dbo].[usp_BillingRequest_Insert_V3]
		@CreatedByUserId	INT	
		,@BillingDateTo		DATE
		,@CreatedDateFrom	DATE
		,@CreatedDateTo		DATE

AS
BEGIN
	SET NOCOUNT ON;


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

--WHILE Loop---------------------------------
DECLARE @max INT;

SELECT	@max = MAX(rwId)
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

		INSERT INTO @TmpResult ( IsResult, Result, Msg)

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
		EXECUTE [dbo].[usp_BillingRequest_Sub01_Insert_V2] 
							@GroupTypeId
							,@ClaimTypeCode
							,@InsuranceCompanyId
							,@CreatedByUserId
							,@BillingDate 
							,@ClaimHeaderGroupTypeId
							,@InsuranceCompanyName
							,@BillingDateTo
							,@CreatedDateFrom
							,@CreatedDateTo
		------------------------------
        SET @intFlag = @intFlag + 1;
    END;
---------------------------------------------

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

END;


