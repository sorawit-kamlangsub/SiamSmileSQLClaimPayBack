USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimHeaderGroupValidateAmountPay_Select]    Script Date: 12/8/2025 3:59:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Mr.Bunchuai chaiket
-- Create date: 2025-09-03 14:32
-- Update date:	2025-09-11 15:42
--				?????????????????????? Customer policy ???? Product ???? PA
-- Update date: 2025-10-16 11:06
--				???????? SELECT ??????? NPL
-- Update date: 2025-10-16 16:49
--				??????????? ????????????????????? ???????? PA ????????????????
-- Update date: 2025-10-22 10:30 Bunchuai Chaiket
--				????? validate ????????? ClaimMisc
-- Update date: 2025-10-27 12:28 Sorawit kamlangsub
--				change THEN NULL To ''
-- Description:	Function ?????? Validate ??????? ?.?. ?????????????
-- =============================================
--ALTER PROCEDURE [dbo].[usp_ClaimHeaderGroupValidateAmountPay_Select]  
--	@ProductGroupId				INT
--	,@ClaimGroupTypeId			INT
--	,@ClaimHeaderGroupCode		VARCHAR(MAX)
--AS
--BEGIN
--SET NOCOUNT ON;

-- =============================================
DECLARE @ProductGroupId				INT				= 7;
DECLARE @ClaimGroupTypeId			INT				= 7; 
DECLARE @ClaimHeaderGroupCode		VARCHAR(MAX)	= 'CHCMO88868120010';
-- =============================================

-- Set message 
DECLARE @AmountWarning					VARCHAR(MAX) = N'??? ?.?. ????????????????';	
DECLARE @PolicyWarning					VARCHAR(MAX) = N'???????????????????';	
DECLARE @ClaimHeaderGroupAmountWarning	VARCHAR(MAX) = N'?????????? ?.?. ??????????';
DECLARE @ClaimHeaderPaymentWarning		VARCHAR(MAX) = N'?.?.??????????????????????????????';
DECLARE @InsuranceCompanyId				VARCHAR(MAX) = '100000000041';

-- Create temp table
SELECT DISTINCT Element
INTO #Tmp
FROM dbo.func_SplitStringToTable(@ClaimHeaderGroupCode,',');

CREATE TABLE #Tmplst
(
	ClaimHeaderGroupCode	VARCHAR(30)
	,TransferAmount			DECIMAL(16,2)
	,Amount					DECIMAL(16,2)
	,NPLAmount				DECIMAL(16,2)
	,WarningMessage			NVARCHAR(MAX)
);

-- PH
IF @ProductGroupId = 2

	BEGIN

		INSERT INTO #Tmplst(
			ClaimHeaderGroupCode
			,TransferAmount
			,Amount
			,NPLAmount 
			,WarningMessage
		)
		SELECT 
			chg.code								ClaimHeaderGroupCode
			,ISNULL(colPH.TotalAmount, 0)			TotalAmount
			,cv.PaySS_Total							Amount
			,ISNULL(nplds.NPLAmount, 0)				NPLAmount
			,CASE 
				WHEN  ISNULL(cv.PaySS_Total, 0) = 0	THEN @ClaimHeaderGroupAmountWarning
				WHEN @ClaimGroupTypeId IN(2,6)															
					AND (
						(ISNULL(colPH.TotalAmount, 0) = 0 AND cv.PaySS_Total = 0) OR ISNULL(colPH.TotalAmount, 0) <> (cv.PaySS_Total + ISNULL(nplds.NPLAmount, 0))
					)								THEN @AmountWarning
			ELSE NULL END  AS WarningMessage
		FROM sss.dbo.DB_ClaimHeaderGroup chg
			INNER JOIN #Tmp ts
				ON chg.Code = ts.Element
			LEFT JOIN SSS.dbo.DB_ClaimHeaderGroupItem cgi 
				ON chg.Code = cgi.ClaimHeaderGroup_id
			LEFT JOIN sss.dbo.DB_ClaimHeader ch
				ON cgi.ClaimHeader_id = ch.Code
			LEFT JOIN sss.dbo.DB_ClaimVoucher cv
				ON cgi.ClaimHeader_id = cv.Code
			LEFT JOIN
			(
				SELECT
					co.ClaimOnLineCode
					,co.ClaimOnLineId
					,SUM(cg.TotalAmount)	TotalAmount
				FROM ClaimOnlineV2.dbo.ClaimOnline co
					LEFT JOIN ClaimOnlineV2.dbo.ClaimPayGroup cg
						ON cg.ClaimOnLineId = co.ClaimOnLineId
				WHERE co.IsActive = 1  
					AND cg.PaymentStatusId = 4
				GROUP BY  co.ClaimOnLineCode, co.ClaimOnLineId
			) colPH
				ON colPH.ClaimOnLineCode = ch.ClaimOnLineCode
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

			WHERE  chg.InsuranceCompany_id <> @InsuranceCompanyId				

	END

-- PA
ELSE IF @ProductGroupId = 3

	BEGIN
    
		INSERT INTO #Tmplst(
			ClaimHeaderGroupCode
			,TransferAmount
			,Amount
			,NPLAmount
			,WarningMessage
		)
		SELECT 
			chgPA.Code							ClaimHeaderGroupCode
			,ISNULL(colPA.TotalAmount, 0)		TransferAmount
			,ISNULL(chPA.PaySS_Total, 0)		Amount
			,ISNULL(nplds.NPLAmount, 0)			NPLAmount
			,(
				ISNULL(
					CASE 
						WHEN @ClaimGroupTypeId NOT IN (4)
						AND (
							ctmpPA.Code IS NULL
						)
						THEN @PolicyWarning + ' , ' 
					END, ''
				)
				+
				ISNULL(
					CASE 
						WHEN ISNULL(chPA.PaySS_Total, 0) = 0
							THEN CONCAT(@ClaimHeaderGroupAmountWarning, ' , ')
						ELSE ''
					END, NULL
				)
				+
				ISNULL(
					CASE 
						WHEN @ClaimGroupTypeId IN (2,6)
							AND (
								ISNULL(colPA.TotalAmount, 0) <> (chPA.PaySS_Total + ISNULL(nplds.NPLAmount, 0))
							)
						THEN @AmountWarning + ' , ' 
						ELSE ''
					END, NULL
				)
			) AS WarningMessage
				
		FROM SSSPA.dbo.DB_ClaimHeaderGroupItem cgiPA
			LEFT JOIN SSSPA.dbo.DB_ClaimHeaderGroup chgPA
				ON cgiPA.ClaimHeaderGroup_id = chgPA.Code
			INNER JOIN #Tmp ts
				ON chgPA.Code = ts.Element
			LEFT JOIN SSSPA.dbo.DB_ClaimHeader chPA
				ON cgiPA.ClaimHeader_id = chPA.Code 
			LEFT JOIN (
				SELECT *
				FROM SSSPA.dbo.DB_CustomerDetail
				WHERE IsActive = 1
			) ctmdPA
				ON chPA.CustomerDetail_id = ctmdPA.Code
			LEFT JOIN (
				SELECT * 
				FROM SSSPA.dbo.DB_CustomerPolicy
				WHERE PolicyType_id <> '9605'
			) ctmpPA
				ON ctmdPA.Application_id = ctmpPA.App_id
			LEFT JOIN
			(
				SELECT  
					co.ClaimOnLineCode 
					,co.ClaimOnLineId
					,SUM(cg.TotalAmount)    TotalAmount
				FROM ClaimOnlineV2.dbo.ClaimOnline co
					LEFT JOIN (
						SELECT 
							ClaimOnLineId
							,IsActive
							,PaymentStatusId
							,SUM(ISNULL(TotalAmount, 0)) TotalAmount
						FROM ClaimOnlineV2.dbo.ClaimPayGroup
						GROUP BY ClaimOnLineId
							,IsActive
							,PaymentStatusId
					)cg
						ON cg.ClaimOnLineId = co.ClaimOnLineId
				WHERE co.IsActive = 1
					AND cg.IsActive = 1  
					AND cg.PaymentStatusId = 4
				GROUP BY  co.ClaimOnLineCode,co.ClaimOnLineId

			) colPA
				ON colPA.ClaimOnLineCode = chPA.ClaimOnLineCode 
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
				ON nplds.ClaimOnLineId = colPA.ClaimOnLineId

		WHERE chgPA.InsuranceCompany_id <> @InsuranceCompanyId
	
	END

-- Claim Misc
ELSE IF @ProductGroupId > 3

	BEGIN

		INSERT INTO #Tmplst(
			ClaimHeaderGroupCode
			,TransferAmount
			,Amount
			,NPLAmount
			,WarningMessage
		)
		SELECT 
				cm.ClaimHeaderGroupCode		ClaimHeaderGroupCode
				,cph.PayAmount				TransferAmount
				,ISNULL(cm.PayAmount, 0)	Amount
				,colnlp.NPLAmount			NPLAmount
				,(
					ISNULL(
						CASE 
							WHEN ISNULL(cm.PayAmount, 0) = 0 
								THEN @ClaimHeaderGroupAmountWarning + ' , ' 
							ELSE ''
						END, NULL
					)
					+
					ISNULL(
						CASE 
							WHEN ISNULL(cph.PayAmount, 0) <> (ISNULL(cm.PayAmount, 0) + ISNULL(colnlp.NPLAmount, 0))
								THEN CONCAT(@AmountWarning, ' , ')
							ELSE ''
						END, NULL
					)
					+
					ISNULL(
						CASE 
							WHEN NULLIF(cm.PolicyNo ,'')  IS NULL
								THEN CONCAT(@PolicyWarning, ' , ')
							ELSE ''
						END, NULL
					)
					+
					ISNULL(
						CASE 
							WHEN cph.ClaimMiscPaymentHeaderId  IS NOT NULL
								THEN CONCAT(@ClaimHeaderPaymentWarning, ' , ')
							ELSE ''
						END, NULL
					)
				 ) AS WarningMessage 
				 
		FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			INNER JOIN #Tmp t
				ON cm.ClaimHeaderGroupCode = t.Element
			LEFT JOIN (
				SELECT 
					nplh.ClaimOnLineId
					,SUM(npld.Amount)	NPLAmount
				FROM ClaimOnlineV2.dbo.NPLHeader nplh
					LEFT JOIN ClaimOnlineV2.dbo.NPLDetail npld
						ON nplh.NPLHeaderId = npld.NPLHeaderId
				WHERE nplh.IsActive = 1
					AND npld.IsActive = 1
				GROUP BY ClaimOnLineId
			)colnlp
				ON colnlp.ClaimOnLineId = cm.ClaimOnLineId 
			INNER JOIN 
			(
				SELECT 
					ph.ClaimMiscId						ClaimMiscId
					,SUM(
						CASE 
							WHEN ph.PaymentTypeId IN (2,3) THEN ISNULL(ph.SumAmount, 0)
							WHEN ph.PaymentTypeId IN (4) THEN -ISNULL(ph.SumAmount, 0)
							ELSE 0
						END
						) PayAmount
					,cp.ClaimMiscPaymentHeaderId
				FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] ph
					LEFT JOIN 
					(
						SELECT *
						FROM [ClaimMiscellaneous].[misc].[ClaimMiscPayment] 
						WHERE IsActive = 1 
							AND PaymentStatusId <> 4
							AND PremiumSourceStatusId <> 5
					)cp
						ON ph.ClaimMiscPaymentHeaderId = cp.ClaimMiscPaymentHeaderId
				WHERE ph.IsActive = 1 
				GROUP BY  ph.ClaimMiscId, cp.ClaimMiscPaymentHeaderId
			)
			cph
				ON cm.ClaimMiscId = cph.ClaimMiscId
		WHERE cm.IsActive = 1
			 
 	END

-- set result
SELECT  
	 tmp.ClaimHeaderGroupCode											ClaimHeaderGroupCode 
	,tmp.Amount															Amount
	,tmp.NPLAmount														NPLAmount
	,tmp.TransferAmount													TransferAmount
	,IIF(tmp.WarningMessage IS NULL OR tmp.WarningMessage = '', 1, 0)	IsValid
	,tmp.WarningMessage													WarningMessage
FROM #Tmplst tmp
GROUP BY  tmp.ClaimHeaderGroupCode	
		 ,tmp.Amount				
		 ,tmp.NPLAmount
		 ,tmp.TransferAmount		
		 ,tmp.WarningMessage		
		 

IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;	
IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;


 
--DECLARE @TransferAmount		DECIMAL(16,2)	= NULL;
--DECLARE @Amount				DECIMAL(16,2)	= NULL;
--DECLARE @NPLAmount			DECIMAL(16,2)	= NULL;
--DECLARE @WarningMessage		NVARCHAR(MAX)	= NULL;
--DECLARE @IsValid              INT             = NULL;

--SELECT
--	 @ClaimHeaderGroupCode	ClaimHeaderGroupCode
--	 ,@Amount				Amount
--	 ,@TransferAmount 		TransferAmount
--	 ,@NPLAmount			NPLAmount
--	 ,@WarningMessage		WarningMessage
--	 ,@IsValid              IsValid 

--END;