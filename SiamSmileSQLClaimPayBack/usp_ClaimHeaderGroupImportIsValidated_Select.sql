USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimHeaderGroupImportIsValidated_Select]    Script Date: 1/10/2568 10:29:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sorawit Kamlangsub
-- Create date: 2025-09-24 14:00
-- Description:	Find Claim Can Import
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimHeaderGroupImportIsValidated_Select]
	  @DateFrom DATE	=   NULL
	, @DateTo	DATE    =	NULL
AS
BEGIN

	SET NOCOUNT ON;

DECLARE @ClaimHeaderSSS		INT = 2;
DECLARE @ClaimHeaderSSSPA	INT = 3;
DECLARE @ClaimCompensate	INT = 4;
DECLARE @ClaimHeaderPA30	INT = 5;
DECLARE @IsResult			BIT = 1;		
DECLARE @Result				VARCHAR(100) = '';		
DECLARE @Msg				NVARCHAR(500)= '';	
DECLARE @CountIsError		INT;

DECLARE @ProductGroup TABLE (ProductGroupId INT ,ProductGroupCode VARCHAR(20));
INSERT @ProductGroup
(
	ProductGroupId
  , ProductGroupCode
)
VALUES
(2,'1000')
,(3,'2000')
,(4,'2222')
,(5,'P30')
DECLARE @ClaimTypeCode_H	VARCHAR(20) = '1000'
DECLARE @ClaimTypeCode_C	VARCHAR(20) = '2000'		

	------------------------------------------------------------------------------
SET @DateTo = DATEADD(DAY,1,@DateTo)

SELECT 
	d.ClaimGroupCode
	,d.ProductGroupId
	,d.CreatedDate
INTO #Tmp
FROM dbo.ClaimPayBackDetail d
	INNER JOIN dbo.ClaimPayBack h
		ON d.ClaimPayBackId = d.ClaimPayBackId
WHERE d.CreatedDate >= @DateFrom
AND d.CreatedDate < @DateTo
AND 
NOT EXISTS 
(
	SELECT 
	1
	FROM dbo.ClaimHeaderGroupImport i
	WHERE i.IsActive = 1
	AND i.ClaimHeaderGroupCode = d.ClaimGroupCode 
);



SELECT m.ClaimHeaderGroupCode
	  ,m.ClaimTypeCode
INTO #TmpClaimType
FROM
(
	SELECT g.Code					ClaimHeaderGroupCode
			,cat.ClaimType_id		ClaimTypeCode

	FROM sss.dbo.DB_ClaimHeaderGroup g
		INNER JOIN sss.dbo.MT_ClaimAdmitType cat
			ON g.ClaimAdmitType_id = cat.Code

UNION ALL	

	SELECT g.Code					ClaimHeaderGroupCode
			,CASE g.ClaimStyle_id
				WHEN '4110'	THEN @ClaimTypeCode_H
				WHEN '4120'	THEN @ClaimTypeCode_H
				WHEN '4130'	THEN @ClaimTypeCode_C
				WHEN '4140'	THEN @ClaimTypeCode_C
				ELSE ''
				END					ClaimTypeCode
	FROM SSSPA.dbo.DB_ClaimHeaderGroup g

UNION ALL

	SELECT g.ClaimCompensateGroupCode	ClaimHeaderGroupCode
			,@ClaimTypeCode_H			ClaimTypeCode	
	FROM SSS.dbo.ClaimCompensateGroup g
)m
	INNER JOIN #Tmp x
		ON m.ClaimHeaderGroupCode = x.ClaimGroupCode;

SELECT d.ClaimHeaderGroupCodeInDB
	,d.TotalAmount
	,d.TotalAmountSS
	,d.InsuranceCompanyId
	,d.ClaimHeaderCodeInDB
	,d.ProductGroup
	,d.PolicyNo
	,d.ProductGroupId
INTO #TmpDetail
FROM
	(	--SSS------
		SELECT 
				h.ClaimHeaderGroup_id					AS ClaimHeaderGroupCodeInDB
				,CAST(v.Pay_Total AS DECIMAL(16,2))		AS TotalAmount
				,v.PaySS_Total							AS TotalAmountSS
				,ins.Organize_ID						AS InsuranceCompanyId
				,h.Code									AS ClaimHeaderCodeInDB
				,IIF(h.Product_id = 'P30',h.Product_id,'1000') AS ProductGroup
				,cus.InsuredPolicy_no					AS PolicyNo
				,t.ProductGroupId
		FROM #Tmp t
			LEFT JOIN SSS.dbo.DB_ClaimHeader h
				ON t.ClaimGroupCode = h.ClaimHeaderGroup_id
			LEFT JOIN SSS.dbo.DB_ClaimVoucher v
				ON h.Code = v.Code
			LEFT JOIN DataCenterV1.Organize.Organize ins
				ON h.InsuranceCompany_id = ins.OrganizeCode
			LEFT JOIN sss.dbo.MT_ClaimType ct
				ON h.ClaimAdmitType_id = ct.Code
			LEFT JOIN sss.dbo.DB_Customer  cus
				ON h.App_id = cus.App_id
		WHERE t.ProductGroupId IN(@ClaimHeaderSSS,@ClaimHeaderPA30)


		UNION
		--SSSPA------
		SELECT hg.Code								AS ClaimHeaderGroupCodeInDB
				,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
				,h.PaySS_Total							AS TotalAmountSS
				,ins.Organize_ID						AS InsuranceCompanyId
				,h.Code									AS ClaimHeaderCodeInDB
				,'2000'									AS ProductGroup
				,ctp.Detail								AS PolicyNo
				,t.ProductGroupId
		FROM #Tmp t
			INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg
				ON t.ClaimGroupCode = hg.Code
			LEFT JOIN SSSPA.dbo.DB_ClaimHeader h
				ON hg.Code = h.ClaimheaderGroup_id
			LEFT JOIN DataCenterV1.Organize.Organize AS ins
				ON hg.InsuranceCompany_id = ins.OrganizeCode
			LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
				ON h.CustomerDetail_id = ctd.Code
			LEFT JOIN SSSPA.dbo.DB_Customer AS cus
				ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090' --ไม่ใช่ยกเลิกกรมธรรม์
			LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
				ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601' --เป็นเลขกรมธรรม์ ปกติ
		WHERE t.ProductGroupId = @ClaimHeaderSSSPA

		UNION

		--ClaimCompensate------
		SELECT 
			cg.ClaimCompensateGroupCode				AS ClaimHeaderGroupCodeInDB
			,cc.CompensateRemain						AS TotalAmount
			,cc.CompensateRemain						AS TotalAmountSS
			,ins.Organize_ID							AS InsuranceCompanyId
			,cc.ClaimCompensateCode						AS ClaimHeaderCodeInDB
			,'2222'										AS ProductGroup
			,cus.InsuredPolicy_no						AS PolicyNo
			,t.ProductGroupId
		FROM #Tmp t
			INNER JOIN SSS.dbo.ClaimCompensateGroup cg
				ON t.ClaimGroupCode = cg.ClaimCompensateGroupCode
			LEFT JOIN
				(
					SELECT * 
					FROM SSS.dbo.ClaimCompensate
					WHERE IsActive = 1
				)cc
				ON cg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
			LEFT JOIN DataCenterV1.Organize.Organize AS ins
				ON cg.InsuranceCompanyCode = ins.OrganizeCode
			LEFT JOIN SSS.dbo.DB_ClaimHeader h
				ON t.ClaimGroupCode = h.ClaimHeaderGroup_id
			LEFT JOIN sss.dbo.DB_Customer  cus
				ON h.App_id = cus.App_id
		WHERE t.ProductGroupId = @ClaimCompensate
	)d;

SELECT 
	 m.ClaimHeaderGroupCodeInDB
     , m.ClaimHeaderCodeInDB
	 , m.TotalAmountSS
     , IIF(d.CountDoc > 0,1,0) IsValid
	 , IIF(ISNULL(d.CountDoc,0) = 0,N'ไม่พบเอกสารแนบ','') ValidateDetailResult	 
	 , pd.ProductGroupId ClaimGroupTypeId
FROM #TmpDetail m
	LEFT JOIN 
		(
			SELECT  td.ClaimHeaderGroupCodeInDB
					,td.ClaimHeaderCodeInDB
					,CASE 
						WHEN 
							-- ตรวจสอบเอกสาร PH ที่เป็นเคลมโรงพยาบาลต้องมีทั้งเอกสารเคลมโรงพยาบาล(24) กับหนังสือแจ้งชำระค่ารักษาพยาบาล (134)
							SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup IN ('P30','1000') AND dl.DocumentListID = 24 THEN 1 ELSE 0 END) >= 1
							AND
							SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup IN ('P30','1000') AND dl.DocumentListID = 134 THEN 1 ELSE 0 END) >= 1
						THEN 1
						WHEN 
							-- ตรวจสอบเอกสาร PA ที่เป็นเคลมโรงพยาบาลต้องมีทั้งเอกสารเคลมโรงพยาบาล(26) กับหนังสือแจ้งชำระค่ารักษาพยาบาล (135)
							SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup = '2000' AND dl.DocumentListID = 26 THEN 1 ELSE 0 END) >= 1
							AND
							SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup = '2000' AND dl.DocumentListID = 135 THEN 1 ELSE 0 END) >= 1
						THEN 1
						WHEN 
							-- กรณีเป็นเคลมสาขา ต้องไม่มีของเคลมโรงพยาบาล
							SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H THEN 1 ELSE 0 END) = 0
						THEN 1
						WHEN 
							-- กรณีเป็นเคลมโอนแยก
							MAX(CASE WHEN td.ProductGroup = '2222' THEN 1 ELSE 0 END) = 1
						THEN 1
						ELSE 0
					 END AS CountDoc
			FROM ISC_SmileDoc.dbo.DocumentIndexData dd WITH(NOLOCK)
				LEFT JOIN ISC_SmileDoc.dbo.Document d WITH(NOLOCK)
					ON dd.DocumentID = d.DocumentID
				LEFT JOIN ISC_SmileDoc.dbo.DocumentList dl
					ON d.DocumentListID = dl.DocumentListID
				INNER JOIN #TmpDetail td
					ON dd.DocumentIndexData = td.ClaimHeaderCodeInDB COLLATE DATABASE_DEFAULT
				INNER JOIN #TmpClaimType ct
					ON td.ClaimHeaderGroupCodeInDB = ct.ClaimHeaderGroupCode
			WHERE dl.DocumentTypeId IN (5,6)
			AND d.IsEnable = 1
			GROUP BY td.ClaimHeaderGroupCodeInDB, td.ClaimHeaderCodeInDB
		)d
		ON m.ClaimHeaderCodeInDB = d.ClaimHeaderCodeInDB
		LEFT JOIN @ProductGroup pd
			ON pd.ProductGroupCode = m.ProductGroup
		AND m.ClaimHeaderGroupCodeInDB = d.ClaimHeaderGroupCodeInDB;


IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;
IF OBJECT_ID('tempdb..#TmpDetail') IS NOT NULL  DROP TABLE #TmpDetail;
IF OBJECT_ID('tempdb..#TmpClaimType') IS NOT NULL  DROP TABLE #TmpClaimType;	

--DECLARE @ClaimHeaderGroupCodeInDB NVARCHAR(50) = NULL;
--DECLARE @ClaimHeaderCodeInDB NVARCHAR(50) = NULL;
--DECLARE @TotalAmountSS DECIMAL(16,2) = NULL;
--DECLARE @IsValid INT = NULL;
--DECLARE @ValidateDetailResult NVARCHAR(50) = NULL;
--DECLARE @ClaimGroupTypeId INT = NULL;


--SELECT 
--@ClaimHeaderGroupCodeInDB ClaimHeaderGroupCodeInDB
--,@ClaimHeaderCodeInDB ClaimHeaderCodeInDB
--,@TotalAmountSS TotalAmountSS
--,@IsValid IsValid
--,@ValidateDetailResult ValidateDetailResult
--,@ClaimGroupTypeId ClaimGroupTypeId


END
