USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequestValidate_Select]    Script Date: 16/10/2568 9:36:55 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

-- =============================================
-- Author:		Mr.Bunchuai Chaiket
-- Create date: 2025-10-01 15:16
-- Update date: 2025-10-16 08:37
--				Remove condition BillingAmount <> (TransferAmount - NPLAmount)
-- Description:	store สำหรับ Validate รายการ Generate group Import บ.ส. 
---- =============================================
--ALTER PROCEDURE [dbo].[usp_BillingRequestValidate_Select] 
DECLARE
	 @DateFrom		DATE = '2025-10-15',
	 @DateTo		DATE = '2025-10-16'
--AS
--BEGIN
	
--	SET NOCOUNT ON;
-- ================================
DECLARE @MessageValidate1 NVARCHAR(100) = N'ยอด บ.ส. ไม่เท่ากับ ยอดวางบิล'; 
DECLARE @MessageValidate2 NVARCHAR(100) = N'ยอด บ.ส. และยอดวางบิลเป็น 0'; 
DECLARE @MessageValidate3 NVARCHAR(100) = N'ยอดโอนเงิน ไม่เท่ากับ (ยอด บ.ส. + ยอด NPL)'; 
DECLARE @MessageValidate4 NVARCHAR(100) = N'ยอดวางบิลเป็น ไม่เท่ากับ (ยอดโอนเงิน - ยอด NPL)';  
-- ================================
--DECLARE @DateFrom	DATE = '2025-10-15';
--DECLARE @DateTo		DATE = '2025-10-15';

IF @DateTo IS NOT NULL SET @DateTo = DATEADD(DAY,1,@DateTo);

SELECT 
	g.InsuranceCompanyId
	,g.GroupTypeId
	,ROW_NUMBER() OVER(ORDER BY (g.InsuranceCompanyId) ASC ) AS rwId
	,g.ClaimTypeCode
	,g.CreatedDate
	,g.ClaimHeaderGroupTypeId
	,g.InsuranceCompanyName
	,g.ClaimHeaderGroupCode
	,SUM(g.TotalAmount)		BillingAmount
INTO #TmpLoop	
FROM
	(SELECT	i.InsuranceCompanyId
				,CASE 
						WHEN f.ClaimHeaderGroupTypeId = 2 THEN 1
						WHEN f.ClaimHeaderGroupTypeId = 3 THEN 2
						WHEN f.ClaimHeaderGroupTypeId = 4 THEN 1
						WHEN f.ClaimHeaderGroupTypeId = 5 THEN 1
					ELSE NULL
					END	GroupTypeId
				,i.ClaimTypeCode
				,i.CreatedDate
				,f.ClaimHeaderGroupTypeId
				,i.InsuranceCompanyName
				,i.TotalAmount
				,i.ClaimHeaderGroupCode
		FROM	dbo.ClaimHeaderGroupImport AS i
				INNER JOIN dbo.ClaimHeaderGroupImportFile AS f
					ON i.ClaimGroupImportFileId = f.ClaimHeaderGroupImportFileId
		WHERE	f.IsActive = 1
			AND		i.IsActive = 1
			AND		i.ClaimHeaderGroupImportStatusId = 2
			AND		i.BillingRequestGroupId IS NULL
			AND		i.CreatedDate >	@DateFrom
			AND		i.CreatedDate <=  @DateTo
	) AS g
WHERE	g.GroupTypeId IS NOT NULL
GROUP BY	g.InsuranceCompanyId
			,g.GroupTypeId
			,g.ClaimTypeCode
			,g.CreatedDate
			,g.ClaimHeaderGroupTypeId
			,g.InsuranceCompanyName
			,g.ClaimHeaderGroupCode;
			 
SELECT 
	t.ClaimHeaderGroupCode 
	,t.ClaimHeaderGroupTypeId					
	,pa.PaySS_Total  				Amount 
	,ISNULL(t.BillingAmount, 0)		BillingAmount
	,ISNULL(colPH.TotalAmount, 0)	TransferAmount
	,ISNULL(nplds.NPLAmount, 0)		NPLAmount 
INTO #Tmp2
FROM #TmpLoop t 
	LEFT JOIN (
		-- PH
		SELECT
			cgi.ClaimHeaderGroup_id			Code
			,cv.PaySS_Total					PaySS_Total
			,ch.ClaimOnLineCode				ClaimOnLineCode 
		FROM  SSS.dbo.DB_ClaimHeaderGroupItem cgi  
			LEFT JOIN sss.dbo.DB_ClaimHeader ch
				ON cgi.ClaimHeader_id = ch.Code
			LEFT JOIN sss.dbo.DB_ClaimVoucher cv
				ON cgi.ClaimHeader_id = cv.Code 

		UNION

		-- PA
		SELECT	
			chgPA.Code						Code
			,chPA.PaySS_Total				PaySS_Total
			,chPA.ClaimOnLineCode			ClaimOnLineCode
		FROM [SSSPA].[dbo].[DB_ClaimHeaderGroupItem] hPA
			LEFT JOIN SSSPA.dbo.DB_ClaimHeaderGroup chgPA
				ON hPA.ClaimHeaderGroup_id = chgPA.Code
			LEFT JOIN SSSPA.dbo.DB_ClaimHeader chPA
				ON hPA.ClaimHeader_id = chPA.Code 

		UNION

		--ClaimCompensate------
		SELECT 
			cg.ClaimCompensateGroupCode		Code
			,cc.CompensateRemain			PaySS_Total
			,cc.ClaimHeaderCode				ClaimOnLineCode
		FROM [SSS].[dbo].[ClaimCompensateGroup] cg
			LEFT JOIN
				(
					SELECT * 
					FROM SSS.dbo.ClaimCompensate
					WHERE IsActive = 1
				)cc
				ON cg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
	)pa
		ON t.ClaimHeaderGroupCode = pa.Code
	LEFT JOIN [SSSPA].[dbo].[DB_ClaimHeader] hdPA
		ON t.ClaimHeaderGroupCode = hdPA.Code
	LEFT JOIN
		(
			SELECT
				co.ClaimOnLineCode 
				,cg.ClaimOnLineId
				,SUM(cg.TotalAmount)	TotalAmount
			FROM ClaimOnlineV2.dbo.ClaimOnline co
				LEFT JOIN ClaimOnlineV2.dbo.ClaimPayGroup cg
					ON cg.ClaimOnLineId = co.ClaimOnLineId
			WHERE co.IsActive = 1  
				AND cg.IsActive = 1
				AND cg.PaymentStatusId = 4
			GROUP BY  co.ClaimOnLineCode,cg.ClaimOnLineId
		) colPH
		ON colPH.ClaimOnLineCode = pa.ClaimOnLineCode
	LEFT JOIN (
		SELECT 
			ClaimOnLineId
			,SUM(npld.Amount)	NPLAmount
		FROM ClaimOnlineV2.dbo.NPLHeader nplh
			INNER JOIN ClaimOnlineV2.dbo.NPLDetail npld
				ON nplh.NPLHeaderId = npld.NPLHeaderId
		WHERE nplh.IsActive = 1
			AND npld.IsActive = 1
		GROUP BY ClaimOnLineId
	)nplds
		ON nplds.ClaimOnLineId = colPH.ClaimOnLineId

-- =============================================================
/*
 1 Amount = BillingAmount
 2 TransferAmount = (Amount + NPLAmount)
 3 BillingAmount = (TransferAmount - NPLAmount)
*/

SELECT 
	*
	,CASE
		WHEN (Amount <> BillingAmount)		THEN @MessageValidate1
		WHEN ((Amount + BillingAmount) = 0)	THEN @MessageValidate2
		WHEN TransferAmount > 0	THEN 
			CASE 
				WHEN  TransferAmount <> (Amount + NPLAmount)		THEN @MessageValidate3
				--WHEN  BillingAmount <> (TransferAmount - NPLAmount) THEN @MessageValidate4
			ELSE NULL END  
		ELSE NULL END  IsValidate
FROM #Tmp2 
WHERE ClaimHeaderGroupCode = 'SEHN-222-68100002-0'
	

IF OBJECT_ID('tempdb..#TmpLoop') IS NOT NULL  DROP TABLE #TmpLoop;	
IF OBJECT_ID('tempdb..#Tmp2') IS NOT NULL  DROP TABLE #Tmp2;	

--DECLARE @ClaimHeaderGroupCode NVARCHAR(50)
--, @ClaimHeaderGroupTypeId INT
--, @Amount DECIMAL(16,2)
--, @BillingAmount DECIMAL(16,2)
--, @TransferAmount DECIMAL(16,2)
--, @NPLAmount DECIMAL(16,2)
--, @IsValidate NVARCHAR(50) ;

--SELECT 
--	@ClaimHeaderGroupCode		ClaimHeaderGroupCode
--	, @ClaimHeaderGroupTypeId	ClaimHeaderGroupTypeId
--	, @Amount					Amount 
--	, @BillingAmount			BillingAmount
--	, @TransferAmount			TransferAmount
--	, @NPLAmount				NPLAmount
--	, @IsValidate				IsValidate

--END;