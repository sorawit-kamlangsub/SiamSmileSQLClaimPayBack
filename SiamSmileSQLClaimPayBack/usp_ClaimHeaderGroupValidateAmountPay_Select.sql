﻿USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimHeaderGroupValidateAmountPay_Select]    Script Date: 27/10/2568 12:35:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Mr.Bunchuai chaiket
-- Create date: 2025-09-03 14:32
-- Update date:	2025-09-11 15:42
--				เพิ่มขั้นตอนการตรวจสอบ Customer policy กรณี Product เป็น PA
-- Update date: 2025-10-16 11:06
--				แก้ไขการ SELECT ยอดเงิน NPL
-- Update date: 2025-10-16 16:49
--				ตัดเงื่อนไข ไม่ตรวจสอบเลขกรมธรรม์ กรณีเป็น PA และเคลมโรงพยาบาล
-- Update date: 2025-10-22 10:30 Bunchuai Chaiket
--				เพิ่ม validate ข้อมูลจาก ClaimMisc
-- Update date: 2025-10-27 12:28 Sorawit kamlangsub
--				change THEN NULL To ''
-- Description:	Function สำหรับ Validate ยอดเงิน บ.ส. และยอดเงินโอน
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimHeaderGroupValidateAmountPay_Select]  
	@ProductGroupId				INT
	,@ClaimGroupTypeId			INT
	,@ClaimHeaderGroupCode		VARCHAR(MAX)
AS
BEGIN
SET NOCOUNT ON;

-- =============================================
--DECLARE @ProductGroupId				INT				= 4;
--DECLARE @ClaimGroupTypeId			INT				= 7; 
--DECLARE @ClaimHeaderGroupCode		VARCHAR(MAX)	= 'CLMI68146-CLMP68110';
-- =============================================

-- Set message 
DECLARE @AmountWarning					VARCHAR(MAX) = N'ยอด บ.ส. ไม่เท่ากับยอดโอน';	
DECLARE @PolicyWarning					VARCHAR(MAX) = N'ไม่มีเลขที่กรมธรรม์';	
DECLARE @ClaimHeaderGroupAmountWarning	VARCHAR(MAX) = N'ยอดเงินตาม บ.ส. ไม่ถูกต้อง';
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
				,ISNULL(cm.ClaimAmount, 0)	Amount
				,0							NPLAmount5
				,(
					ISNULL(
						CASE 
							WHEN ISNULL(cm.ClaimAmount, 0) = 0 
								THEN @ClaimHeaderGroupAmountWarning + ' , ' 
							ELSE ''
						END, NULL
					)
					+
					ISNULL(
						CASE 
							WHEN ISNULL(cph.PayAmount, 0) <> (ISNULL(cm.ClaimAmount, 0) + ISNULL(colnlp.NPLAmount, 0))
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
				 ) AS WarningMessage 
				 
		FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			INNER JOIN #Tmp t
				ON cm.ClaimHeaderGroupCode = t.Element
			INNER JOIN [ClaimPayBack].[dbo].[ClaimPayBackProductGroup] pd
				ON cm.ProductTypeId = pd.MappingXCliamMisc
			INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] cmh
				ON cm.ClaimMiscId = cmh.ClaimMiscId
			INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] cmp
				ON cmh.ClaimMiscPaymentHeaderId = cmp.ClaimMiscPaymentHeaderId
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
			)colnlp
				ON colnlp.ClaimOnLineId = cm.ClaimOnLineId
			INNER JOIN ClaimPayBackProductGroup cpg
				ON cm.ProductTypeId = cpg.MappingXCliamMisc
					AND cpg.ProductGroup_ID = @ProductGroupId
			INNER JOIN 
			(
				SELECT 
					ClaimMiscId													ClaimMiscId
					,(ISNULL(SumPaymentAmount, 0) - ISNULL(SumRefuntAmount, 0))	PayAmount
				FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader]
				WHERE IsActive = 1
			)
			cph
				ON cm.ClaimMiscId = cph.ClaimMiscId
		WHERE cm.IsActive = 1
			AND cmh.IsActive = 1
			AND cm.ClaimMiscStatusId = 3
			AND cmp.IsActive = 1
			AND cmp.PaymentStatusId = 4
			AND cm.ClaimHeaderGroupCode IS NOT NULL

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

END;