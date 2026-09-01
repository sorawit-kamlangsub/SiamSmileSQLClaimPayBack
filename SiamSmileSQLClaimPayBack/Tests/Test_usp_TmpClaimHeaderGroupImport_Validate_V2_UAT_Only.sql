USE [ClaimPayBack]
GO

--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO



-- =============================================
-- Author:		Siriphong Narkphung
-- Create date: 2022-11-02
-- Update date: 2023-08-08	Siriphong	Narkphung	Add ValidateDoc
-- update date:  2024-01-24 Kittisak.Ph 
-- update date:  2024-02-01 Kittisak.Ph เช็ครายการเคลมซ้ำ ใน บ.ส.เดียวกัน
-- update date:	2024-04-23 Kerkpon.Mind เพิ่มเงื่อนไขเช็คว่าเลข claim มีซ้ำ
-- update date: 2024-06-17 Krekpon.Mind เพิ่มเงื่อนไข
-- update date: 2024-07-09 Krekpon.Mind เพิ่ม IsActive
-- update date: 2025-04-11 Wetpisit.P เพิ่ม validate เช็คเลขกรมธรรม์ใน บ.ส.โดยดึงข้อมูล PolicyNo มาใส่ #TmpDetail เพื่อนำไปเช็ค,เพิ่มเงื่อนไขการเช็คจำนวนเอกสารใน #tmpDoc
-- update date: 2025-10-02 10:02 เพิ่ม IsActive ใน LEFT JOIN ClaimHeaderGroupImport
-- Update date: 2025-10-16 14:01 Clear comment Krekpon.D
-- Update date: 2025-10-30 09:34 Add ClaimMisc and Clean Script Sorawit kamlangsub
-- Update date: 2026-03-11 13:16 Add Pa Validate PolicyNo Sorawit kamlangsub
-- Update date: 2026-03-12 08:47 เพิ่ม Validate กรณีเป็น บ.ส.นั้นเป็นเบิกจ่ายกองทุนม้าลาย Sorawit kamlangsub
-- Update date: 2026-06-06 08:57 เพิ่ม union ClaimMisc ใน #TmpClaimType Sorawit kamlangsub
-- Description:	PROD (P30,1000) dl.DocumentListID = 137 (2000) dl.DocumentListID = 138 
--	UAT  dl.DocumentListID = 134 (2000) dl.DocumentListID = 135
-- =============================================
--ALTER PROCEDURE [dbo].[usp_TmpClaimHeaderGroupImport_Validate_V2]
--	@TmpCode VARCHAR(20)

--AS
--BEGIN
	
--SET NOCOUNT ON;

DECLARE @IsQuery BIT = 0;
DECLARE @IsImport BIT = 1;

IF @IsQuery = 1
BEGIN
	SELECT TOP(1000)
		td.ClaimHeaderGroupCodeInDB
		,1 ItemCode
		,IIF(ISNULL(td.TotalAmount,0) = 0 ,td.TotalAmountSS,td.TotalAmount)	Amount
		,ISNULL(td.TotalAmount,0)	TotalAmount
		,ISNULL(td.TotalAmountSS,0)	TotalAmountSS
		,td.InsuranceCompanyId
		,td.ClaimHeaderCodeInDB
		,td.ProductGroup
		,td.PolicyNo
		,td.CreatedDate
		,td.PolicyType_id
	FROM
		(	--SSS------
			SELECT h.ClaimHeaderGroup_id					AS ClaimHeaderGroupCodeInDB
					,CAST(v.Pay_Total AS DECIMAL(16,2))		AS TotalAmount
					,v.PaySS_Total							AS TotalAmountSS
					,ins.Organize_ID						AS InsuranceCompanyId
					,h.Code									AS ClaimHeaderCodeInDB
					,IIF(h.Product_id = 'P30',h.Product_id,'1000') AS ProductGroup
					,cus.InsuredPolicy_no					AS PolicyNo
					,h.CreatedDate
					,NULL									AS PolicyType_id
			FROM SSS.dbo.DB_ClaimHeader h
				LEFT JOIN SSS.dbo.DB_ClaimVoucher v
					ON h.Code = v.Code
				LEFT JOIN DataCenterV1.Organize.Organize ins
					ON h.InsuranceCompany_id = ins.OrganizeCode
				LEFT JOIN sss.dbo.MT_ClaimType ct
					ON h.ClaimAdmitType_id = ct.Code
				LEFT JOIN sss.dbo.DB_Customer  cus
					ON h.App_id = cus.App_id

			UNION
			--SSSPA------
			SELECT hg.Code								AS ClaimHeaderGroupCodeInDB
					,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
					,h.PaySS_Total							AS TotalAmountSS
					,ins.Organize_ID						AS InsuranceCompanyId
					,h.Code									AS ClaimHeaderCodeInDB
					,'2000'									AS ProductGroup
					,ctp.Detail								AS PolicyNo
					,hg.CreatedDate
					,ctp.PolicyType_id
			FROM SSSPA.dbo.DB_ClaimHeaderGroup AS hg
				LEFT JOIN SSSPA.dbo.DB_ClaimHeader h
					ON hg.Code = h.ClaimheaderGroup_id
				LEFT JOIN DataCenterV1.Organize.Organize AS ins
					ON hg.InsuranceCompany_id = ins.OrganizeCode
				LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
					ON h.CustomerDetail_id = ctd.Code
				LEFT JOIN SSSPA.dbo.DB_Customer AS cus
					ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090' 
				LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
					ON cus.App_id  = ctp.App_id 

			UNION

			--ClaimCompensate------
			SELECT cg.ClaimCompensateGroupCode				AS ClaimHeaderGroupCodeInDB
				,cc.CompensateRemain						AS TotalAmount
				,cc.CompensateRemain						AS TotalAmountSS
				,ins.Organize_ID							AS InsuranceCompanyId
				,cc.ClaimCompensateCode						AS ClaimHeaderCodeInDB
				,'2222'										AS ProductGroup
				,cus.InsuredPolicy_no						AS PolicyNo
				,cg.CreatedDate
				,NULL										AS PolicyType_id
			FROM SSS.dbo.ClaimCompensateGroup cg
				LEFT JOIN
					(
						SELECT 
							CompensateRemain
							,ClaimCompensateCode
							,ClaimCompensateGroupId
						FROM SSS.dbo.ClaimCompensate
						WHERE IsActive = 1
					)cc
					ON cg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
				LEFT JOIN DataCenterV1.Organize.Organize AS ins
					ON cg.InsuranceCompanyCode = ins.OrganizeCode
				LEFT JOIN SSS.dbo.DB_ClaimHeader h
					ON cg.ClaimCompensateGroupCode = h.ClaimHeaderGroup_id
				LEFT JOIN sss.dbo.DB_Customer  cus
					ON h.App_id = cus.App_id

			UNION

				-- ClaimMisc 
				SELECT 	
					cm.ClaimHeaderGroupCode									ClaimHeaderGroupCodeInDB
					,cm.PayAmount												TotalAmount
					,cm.PayAmount												TotalAmountSS
					,org.Organize_ID											InsuranceCompanyId
					,NULL														ClaimHeaderCodeInDB
					,IIF(cpbType.ClaimPaymentTypeId = 2, 'ZebraMisc','Misc')	ProductGroup
					,cm.PolicyNo												PolicyNo
					,cm.CreatedDate
					,NULL														PolicyType_id
				FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
					LEFT JOIN [ClaimMiscellaneous].[misc].[InsuranceCompany] ins
						ON ins.InsuranceCompanyId = cm.InsuranceCompanyId
					LEFT JOIN [DataCenterV1].[Organize].[Organize] org
						ON org.OrganizeCode = ins.InsuranceCompanyCode
					LEFT JOIN (
							SELECT DISTINCT
								h.ClaimMiscId
								,cp.ClaimPaymentTypeId
								,cp.ClaimPaymentTypeName
							FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] h
								LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] p
								 ON h.ClaimMiscPaymentHeaderId = p.ClaimMiscPaymentHeaderId
								LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimPaymentType] cp
								 ON cp.ClaimPaymentTypeId = p.ClaimPaymentTypeId
								) cpbType
						ON cm.ClaimMiscId = cpbType.ClaimMiscId

	) td
	WHERE td.ClaimHeaderGroupCodeInDB IS NOT NULL
	  AND td.ClaimHeaderGroupCodeInDB <> ''
	  AND td.ClaimHeaderCodeInDB LIKE '%CLPA69%'
	  AND SUBSTRING(td.ClaimHeaderGroupCodeInDB, 3, 1) = 'A'
	  AND (td.PolicyNo IS NOT NULL AND td.PolicyType_id <> '')
	  --AND td.PolicyType_id <> 9601
	ORDER BY td.ClaimHeaderGroupCodeInDB ASC
	,td.CreatedDate DESC
END

DECLARE @TransactionCodeControlTypeDetail varchar(8) = 'IMCHG'
DECLARE @RunningLenght int = 6
DECLARE @ResultCode varchar(20)

IF @IsImport = 1
BEGIN

	EXECUTE [dbo].[usp_GenerateCode] 
	   @TransactionCodeControlTypeDetail
	  ,@RunningLenght
	  ,@ResultCode OUTPUT

	INSERT INTO [dbo].[TmpClaimHeaderGroupImport]
			   ([TmpCode]
			   ,[ClaimHeaderGroupCode]
			   ,[ItemCount]
			   ,[TotalAmount]
			   ,[BillingDate]
			   ,[IsValid]
			   ,[ValidateResult]
			   ,[InsuranceCompanyId]
			   ,[ClaimHeaderGroupTypeId]
			   ,[ClaimTypeCode])
		 VALUES
			   (
			   @ResultCode				--[TmpCode]
			   ,'BUAH-888-69010001-0'	--[ClaimHeaderGroupCode]
			   ,1						--[ItemCount]
			   ,350					--[TotalAmount]
			   ,NULL					--[BillingDate]
			   ,NULL					--[IsValid]
			   ,NULL					--[ValidateResult]
			   ,NULL					--[InsuranceCompanyId]
			   ,3					--[ClaimHeaderGroupTypeId]
			   ,NULL					--[ClaimTypeCode]
			   )
END

--Test Zone
DECLARE @TmpCode VARCHAR(20) = @ResultCode
--End Test

DECLARE @ClaimHeaderSSS INT = 2;
DECLARE @ClaimHeaderSSSPA INT = 3;
DECLARE @ClaimCompensate INT = 4;
DECLARE @ClaimHeaderPA30 INT = 5;
DECLARE @ClaimMisc INT = 6;
DECLARE @IsResult    BIT             = 1;		
DECLARE @Result        VARCHAR(100) = '';		
DECLARE @Msg        NVARCHAR(500)= '';	
DECLARE @CountIsError INT;

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
,(6,'Misc')
DECLARE @ClaimTypeCode_H	VARCHAR(20) = '1000'
DECLARE @ClaimTypeCode_C	VARCHAR(20) = '2000'

DECLARE @MapAdmitTypeWithPolicy TABLE (AdmitTypeCode VARCHAR(20),PolicyCode VARCHAR(20),Detail NVARCHAR(255));
INSERT INTO @MapAdmitTypeWithPolicy
SELECT
    admit.Code AdmitTypeCode
    ,[policy].Code PolicyCode
    ,CONCAT(admit.Detail,' ต้องมี ',[policy].Detail) Detail
FROM
(
    VALUES
        ('4001', '9601'),
        ('4009', '9602'),
        ('4010', '9604')
) m(AdmitTypeCode, PolicyCode)
INNER JOIN SSSPA.dbo.SM_Code admit
    ON admit.Code = m.AdmitTypeCode
INNER JOIN SSSPA.dbo.SM_Code [policy]
    ON [policy].Code = m.PolicyCode

----------------------------------------------

IF @IsResult = 1 AND @IsImport = 1		
	BEGIN					
	
		SELECT 
			tmp.TmpClaimHeaderGroupImportId
			,tmp.TmpCode
			,tmp.ClaimHeaderGroupCode
			,ISNULL(tmp.ItemCount,0) ItemCount
			,ISNULL(tmp.TotalAmount ,0) TotalAmount
			,tmp.BillingDate
			,tmp.IsValid
			,tmp.ValidateResult
			,tmp.InsuranceCompanyId
			,tmp.ClaimHeaderGroupTypeId
		INTO #Tmp
		FROM dbo.TmpClaimHeaderGroupImport tmp
		WHERE tmp.TmpCode = @TmpCode;


		
		SELECT x.TmpClaimHeaderGroupImportId
              ,m.ClaimHeaderGroupCode
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

		UNION ALL 
			
			SELECT 
				ClaimHeaderGroupCode	
				,CASE ClaimTypeId 
					WHEN 2 THEN @ClaimTypeCode_H
					WHEN 3 THEN @ClaimTypeCode_C
					ELSE ''
					END								ClaimTypeCode
			FROM [ClaimMiscellaneous].[misc].[ClaimMisc] 
			

		)m
			INNER JOIN #Tmp x
				ON m.ClaimHeaderGroupCode = x.ClaimHeaderGroupCode;

		
		SELECT d.TmpClaimHeaderGroupImportId
			,d.ClaimHeaderGroupCodeInDB
			,d.TotalAmount
			,d.TotalAmountSS
			,d.InsuranceCompanyId
			,d.ClaimHeaderCodeInDB
			,d.ProductGroup
			,d.AdmitTypeCode
			,d.PolicyNo
			,d.PolicyHistory
		INTO #TmpDetail
		FROM
			(	--SSS------
				SELECT t.TmpClaimHeaderGroupImportId
						,h.ClaimHeaderGroup_id							AS ClaimHeaderGroupCodeInDB
						,CAST(v.Pay_Total AS DECIMAL(16,2))				AS TotalAmount
						,v.PaySS_Total									AS TotalAmountSS
						,ins.Organize_ID								AS InsuranceCompanyId
						,h.Code											AS ClaimHeaderCodeInDB
						,IIF(h.Product_id = 'P30',h.Product_id,'1000')  AS ProductGroup
						,NULL											AS AdmitTypeCode
						,cus.InsuredPolicy_no							AS PolicyNo
						,NULL											AS PolicyHistory
				FROM #Tmp t
					LEFT JOIN SSS.dbo.DB_ClaimHeader h
						ON t.ClaimHeaderGroupCode = h.ClaimHeaderGroup_id
					LEFT JOIN SSS.dbo.DB_ClaimVoucher v
						ON h.Code = v.Code
					LEFT JOIN DataCenterV1.Organize.Organize ins
						ON h.InsuranceCompany_id = ins.OrganizeCode
					LEFT JOIN sss.dbo.MT_ClaimType ct
						ON h.ClaimAdmitType_id = ct.Code
					LEFT JOIN sss.dbo.DB_Customer  cus
						ON h.App_id = cus.App_id
				WHERE t.ClaimHeaderGroupTypeId IN(@ClaimHeaderSSS,@ClaimHeaderPA30)


				UNION
				--SSSPA------
				SELECT t.TmpClaimHeaderGroupImportId
						,hg.Code									AS ClaimHeaderGroupCodeInDB
						,CAST(h.Amount_Pay AS DECIMAL(16,2))		AS TotalAmount
						,h.PaySS_Total								AS TotalAmountSS
						,ins.Organize_ID							AS InsuranceCompanyId
						,h.Code										AS ClaimHeaderCodeInDB
						,'2000'										AS ProductGroup	
						,h.ClaimType_id								AS AdmitTypeCode
						,custpolicy.PolicyNo
					    ,CONCAT( 'ประวัติการบันทึกกรมธรรม์ >> ',STUFF((
					   			SELECT ' > ' + CONCAT(p.Detail,' (',policyType.Detail,')')
					   			FROM SSSPA.dbo.DB_CustomerPolicy p
					   			LEFT JOIN SSSPA.dbo.SM_Code policyType
					   				ON p.PolicyType_id = policyType.Code
					   			WHERE p.App_id = cust.App_id
					   			ORDER BY p.CreatedDate ASC
					   			FOR XML PATH(''), TYPE
					   			).value('.', 'nvarchar(255)'), 1, 3, '')
							)										AS	PolicyHistory
				FROM #Tmp t
					INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg
						ON t.ClaimHeaderGroupCode = hg.Code
					LEFT JOIN DataCenterV1.Organize.Organize AS ins
						ON hg.InsuranceCompany_id = ins.OrganizeCode
					LEFT JOIN SSSPA.dbo.DB_ClaimHeader h
						ON hg.Code = h.ClaimheaderGroup_id
					LEFT JOIN 
					(
						SELECT 
						 ctd.Code
						 ,cus.App_id
						FROM SSSPA.dbo.DB_CustomerDetail ctd
						LEFT JOIN SSSPA.dbo.DB_Customer cus
							ON ctd.Application_id = cus.App_id 
						WHERE cus.Status_id <> '3090' 
					) cust
						ON h.CustomerDetail_id = cust.Code 
					LEFT JOIN @MapAdmitTypeWithPolicy mapPolicy	
						ON h.ClaimType_id = mapPolicy.AdmitTypeCode
					LEFT JOIN 
					(
						SELECT 
						 App_id
						 ,Detail	PolicyNo
						 ,PolicyType_id
						FROM SSSPA.dbo.DB_CustomerPolicy
					) custpolicy
					ON cust.App_id = custpolicy.App_id
						AND custpolicy.PolicyType_id = mapPolicy.PolicyCode
				WHERE t.ClaimHeaderGroupTypeId = @ClaimHeaderSSSPA

				UNION

				--ClaimCompensate------
				SELECT t.TmpClaimHeaderGroupImportId
					,cg.ClaimCompensateGroupCode				AS ClaimHeaderGroupCodeInDB
					,cc.CompensateRemain						AS TotalAmount
					,cc.CompensateRemain						AS TotalAmountSS
					,ins.Organize_ID							AS InsuranceCompanyId
					,cc.ClaimCompensateCode						AS ClaimHeaderCodeInDB
					,'2222'										AS ProductGroup
					,NULL										AS AdmitTypeCode
					,cus.InsuredPolicy_no						AS PolicyNo
					,NULL										AS PolicyHistory
				FROM #Tmp t
					INNER JOIN SSS.dbo.ClaimCompensateGroup cg
						ON t.ClaimHeaderGroupCode = cg.ClaimCompensateGroupCode
					LEFT JOIN
						(
							SELECT 
								CompensateRemain
								,ClaimCompensateCode
								,ClaimCompensateGroupId
							FROM SSS.dbo.ClaimCompensate
							WHERE IsActive = 1
						)cc
						ON cg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
					LEFT JOIN DataCenterV1.Organize.Organize AS ins
						ON cg.InsuranceCompanyCode = ins.OrganizeCode
					LEFT JOIN SSS.dbo.DB_ClaimHeader h
						ON t.ClaimHeaderGroupCode = h.ClaimHeaderGroup_id
					LEFT JOIN sss.dbo.DB_Customer  cus
						ON h.App_id = cus.App_id
				WHERE t.ClaimHeaderGroupTypeId = @ClaimCompensate

				UNION

				-- ClaimMisc 
				SELECT 
					t.TmpClaimHeaderGroupImportId	
					,cm.ClaimHeaderGroupCode									ClaimHeaderGroupCodeInDB
					,cm.PayAmount												TotalAmount
					,cm.PayAmount												TotalAmountSS
					,org.Organize_ID											InsuranceCompanyId
					,NULL														ClaimHeaderCodeInDB
					,NULL														AdmitTypeCode					
					,IIF(cpbType.ClaimPaymentTypeId = 2, 'ZebraMisc','Misc')	ProductGroup
					,cm.PolicyNo												PolicyNo
					,NULL														PolicyHistory
				FROM #Tmp t
					INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm
						ON t.ClaimHeaderGroupCode = cm.ClaimHeaderGroupCode
					LEFT JOIN [ClaimMiscellaneous].[misc].[InsuranceCompany] ins
						ON ins.InsuranceCompanyId = cm.InsuranceCompanyId
					LEFT JOIN [DataCenterV1].[Organize].[Organize] org
						ON org.OrganizeCode = ins.InsuranceCompanyCode
					LEFT JOIN (
							SELECT DISTINCT
								h.ClaimMiscId
								,cp.ClaimPaymentTypeId
								,cp.ClaimPaymentTypeName
							FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] h
								LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] p
								 ON h.ClaimMiscPaymentHeaderId = p.ClaimMiscPaymentHeaderId
								LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimPaymentType] cp
								 ON cp.ClaimPaymentTypeId = p.ClaimPaymentTypeId
								) cpbType
						ON cm.ClaimMiscId = cpbType.ClaimMiscId
			)d;

		----------------Update 2023-08-09-----------------------
		SELECT m.TmpClaimHeaderGroupImportId
			 , m.ClaimHeaderGroupCodeInDB
             , m.ClaimHeaderCodeInDB
			 , m.TotalAmountSS
			 , IIF(m.ProductGroup IN ('Misc','ZebraMisc'),1,ISNULL(d.CountDoc,0)) CountDoc
			 , IIF(IIF(m.ProductGroup IN ('Misc','ZebraMisc'),1,ISNULL(d.CountDoc,0)) = 0,N'ไม่พบเอกสารแนบ','') ValidateDetailResult
		INTO #TmpDoc
		FROM #TmpDetail m
			LEFT JOIN 
				(
					SELECT  td.ClaimHeaderGroupCodeInDB
							,td.ClaimHeaderCodeInDB
							,CASE 
								WHEN 
									-- ตรวจสอบเอกสาร PH ที่เป็นเคลมโรงพยาบาลต้องมีทั้งเอกสารเคลมโรงพยาบาล(24) กับหนังสือแจ้งชำระค่ารักษาพยาบาล (UAT 134,PROD 137)
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup IN ('P30','1000') AND dl.DocumentListID = 24 THEN 1 ELSE 0 END) >= 1
									AND
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup IN ('P30','1000') AND dl.DocumentListID = 134 THEN 1 ELSE 0 END) >= 1
								THEN 1
								WHEN 
									-- ตรวจสอบเอกสาร PA ที่เป็นเคลมโรงพยาบาลต้องมีทั้งเอกสารเคลมโรงพยาบาล(26) กับหนังสือแจ้งชำระค่ารักษาพยาบาล (UAT 135,PROD 138)
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
						LEFT JOIN 
						(
							SELECT
								DocumentListID
							FROM ISC_SmileDoc.dbo.DocumentList 
							WHERE DocumentTypeId IN (5,6)
						) dl
							ON d.DocumentListID = dl.DocumentListID
						INNER JOIN #TmpDetail td
							ON dd.DocumentIndexData = td.ClaimHeaderCodeInDB COLLATE DATABASE_DEFAULT
						INNER JOIN #TmpClaimType ct
							ON td.ClaimHeaderGroupCodeInDB = ct.ClaimHeaderGroupCode
					WHERE d.IsEnable = 1
					GROUP BY td.ClaimHeaderGroupCodeInDB, td.ClaimHeaderCodeInDB
				)d
				ON m.ClaimHeaderCodeInDB = d.ClaimHeaderCodeInDB
				AND m.ClaimHeaderGroupCodeInDB = d.ClaimHeaderGroupCodeInDB;

		---------------------------------------------------------------------------

		SELECT 
				t.TmpClaimHeaderGroupImportId
				,t.ClaimHeaderGroupCode
				,t.TmpCode
				,c.InsuranceCompanyId
				,t.ItemCount
				,t.TotalAmount
				,c.ItemCountInDB
				,c.TotalAmountInDB
				,imd.ClaimCodeInSystem AS ClaimCodeInSystem
				,img.ClaimHeaderGroupCode AS ClaimHeaderGroupInSystem
				,s.ClaimHeaderGroupCode AS ClaimHeaderGroupCodeInFlie
				,c.ClaimHeaderGroupCodeInDB
				----------------------Update 2023-08-08--------------------
				,CONCAT
					(
						 IIF(s.ClaimHeaderGroupCode IS NOT NULL,N'รายการ บ.ส. ซ้ำกันในไฟล์, ','')
						,IIF(img.ClaimHeaderGroupCode IS NOT NULL,N'รายการ บ.ส. ซ้ำกับในระบบ, ','')
						,IIF(c.ClaimHeaderGroupCodeInDB IS NULL, N'ไม่พบเลข บ.ส. นี้ในฐานข้อมูล, ','')
						,IIF(t.ItemCount<>ISNULL(c.ItemCountInDB,0) AND t.ClaimHeaderGroupTypeId = pg.ProductGroupId AND s.ClaimHeaderGroupCode IS NULL,N'ข้อมูลจำนวนเคลมไม่ตรงกับในฐานข้อมูล, ','')
						,IIF(t.TotalAmount = 0,N'ไม่มียอดเงินในรายการ บ.ส., ','')
						,IIF(t.TotalAmount<>ISNULL(c.TotalAmountInDB,0) AND t.ClaimHeaderGroupTypeId = pg.ProductGroupId AND s.ClaimHeaderGroupCode IS NULL,CONCAT(N'ข้อมูลจำนวนเงินรวมไม่ตรงกับในฐานข้อมูล','( ',FORMAT(c.TotalAmountInDB,'N'),'), '),'')
						,IIF(imd.ClaimCodeInSystem IS NOT NULL AND t.ClaimHeaderGroupCode LIKE '%_0' AND cbd.ClaimGroupCode = t.ClaimHeaderGroupCode AND imd.ClaimHeaderGroupCode = t.ClaimHeaderGroupCode ,N'มีรายการเคลมนี้ในระบบแล้ว, ','') -- Update 2024-02-01 Kittisak.Ph เช็ครายการเคลมซ้ำ ใน บ.ส.เดียวกัน --Update 2024-06-17 Krekpon.Mind เพิ่มเงื่อนไข
						,IIF(t.ClaimHeaderGroupTypeId <> pg.ProductGroupId ,CONCAT(N'รายการ บ.ส. นี้ ไม่ใช่กลุ่ม', 
									' ',
									--IIF(t.ClaimHeaderGroupTypeId = @ClaimHeaderSSS,'PH','PA30')
									CASE
										WHEN
											t.ClaimHeaderGroupTypeId = @ClaimHeaderSSS
										THEN 'PH'
										WHEN 
											t.ClaimHeaderGroupTypeId = @ClaimHeaderSSSPA
										THEN 
											'PA30'
										WHEN 
											t.ClaimHeaderGroupTypeId = @ClaimMisc
										THEN 
											'เบ็ดเตล็ด'
										ELSE
											'-'
									END
									,N' ตามกลุ่มที่ระบุ, '),'')
						,IIF(doc.CountDoc > 0 ,N'บ.ส. ไม่มีเอกสารแนบ, ','')
						,IIF(a.ClaimTypeCode = '',N'ไม่ได้ MappingType (H,C), ','')
						,IIF(c.PolicyNo IS NULL , CONCAT(mapPolicy.Detail,' , ',c.PolicyHistory),'')
						,IIF(c.ProductGroup = 'ZebraMisc', 'ตรวจสอบรายการเคลมกองทุนรถม้าลาย','')
					)ValidateResult
				---------------------------------------------------------------
				,a.ClaimTypeCode	ClaimTypeCode

		INTO #TmpUpdate
		FROM #Tmp t
			LEFT JOIN 
				(
					SELECT ClaimHeaderGroupCodeInDB
						,InsuranceCompanyId
						,COUNT(ClaimHeaderGroupCodeInDB)	ItemCountInDB
						,SUM(TotalAmountSS)					TotalAmountInDB
						,ProductGroup
						,AdmitTypeCode
						,MAX(PolicyNo)						PolicyNo
						,MAX(PolicyHistory)					PolicyHistory
					FROM #TmpDetail
					GROUP BY ClaimHeaderGroupCodeInDB
							,InsuranceCompanyId
							,ProductGroup
							,AdmitTypeCode
				) c
				ON t.ClaimHeaderGroupCode = c.ClaimHeaderGroupCodeInDB
			LEFT JOIN @ProductGroup pg
				ON c.ProductGroup = pg.ProductGroupCode
			LEFT JOIN (
				SELECT *
				FROM dbo.ClaimHeaderGroupImport
				WHERE IsActive = 1
			) img
				ON t.ClaimHeaderGroupCode = img.ClaimHeaderGroupCode
			LEFT JOIN
				(
					SELECT  d.ClaimHeaderGroupCodeInDB AS ClaimCodeInSystem
							,imd.ClaimHeaderGroupCode AS ClaimHeaderGroupCode --Update 2024-06-17 Krekpon.Mind เพิ่มเงื่อนไข
					FROM #TmpDetail d
						INNER JOIN dbo.ClaimHeaderGroupImportDetail imd 
							ON d.ClaimHeaderCodeInDB = imd.ClaimCode
					WHERE d.ClaimHeaderCodeInDB = imd.ClaimCode -- ลองเปลี่ยนเป็น Where 2024-04-23 Krekpon-Mind
						  AND imd.IsActive = 1 -- 2024-07-09 Krekpon.Mind เพิ่ม IsActive
					GROUP BY d.ClaimHeaderGroupCodeInDB,imd.ClaimHeaderGroupCode
				) imd
				ON t.ClaimHeaderGroupCode = imd.ClaimCodeInSystem
			LEFT JOIN 
				(
					SELECT ClaimHeaderGroupCode
						,COUNT(TmpClaimHeaderGroupImportId) xCount
					FROM #Tmp 
					GROUP BY ClaimHeaderGroupCode
					HAVING COUNT(TmpClaimHeaderGroupImportId) >1
				)s
				ON t.ClaimHeaderGroupCode = s.ClaimHeaderGroupCode

			LEFT JOIN #TmpClaimType a
				ON t.TmpClaimHeaderGroupImportId = a.TmpClaimHeaderGroupImportId
			-------------------------Update 2023-08-09--------------------
			LEFT JOIN 
				(
					SELECT ClaimHeaderGroupCodeInDB
						,COUNT(ClaimHeaderGroupCodeInDB) CountDoc
					FROM #TmpDoc
					WHERE CountDoc = 0
					GROUP BY ClaimHeaderGroupCodeInDB
				) doc
				ON t.ClaimHeaderGroupCode = doc.ClaimHeaderGroupCodeInDB
			-------------------------------------------------------------------	
			LEFT JOIN [ClaimPayBack].[dbo].[ClaimPayBackDetail] cbd 
				ON cbd.ClaimGroupCode = t.ClaimHeaderGroupCode
			LEFT JOIN @MapAdmitTypeWithPolicy mapPolicy
				ON c.AdmitTypeCode = mapPolicy.AdmitTypeCode

			SELECT @CountIsError = COUNT(ValidateResult)
			FROM #TmpUpdate
			WHERE TmpCode = @TmpCode 
			AND ValidateResult <>'';

			IF @CountIsError IS NULL SET @CountIsError = 0;

		------------------------------------------------------

SELECT * FROM @MapAdmitTypeWithPolicy;
SELECT * FROM #Tmp;
SELECT * FROM #TmpDetail;
SELECT * FROM #TmpDoc;
SELECT * FROM #TmpUpdate;
SELECT * FROM #TmpClaimType;
		
IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;
IF OBJECT_ID('tempdb..#TmpDetail') IS NOT NULL  DROP TABLE #TmpDetail;
IF OBJECT_ID('tempdb..#TmpDoc') IS NOT NULL  DROP TABLE #TmpDoc;
IF OBJECT_ID('tempdb..#TmpUpdate') IS NOT NULL  DROP TABLE #TmpUpdate;
IF OBJECT_ID('tempdb..#TmpClaimType') IS NOT NULL  DROP TABLE #TmpClaimType;	

	END									  					
										  					
IF @IsResult = 1	BEGIN	SET @Result = IIF(@CountIsError = 0,1,0) END
ELSE				BEGIN	SET @Result = 'Failure'END	
			
							  								
            							  					
       SELECT @IsResult IsResult		  					
		,@Result Result					  					
		,@Msg	 Msg 		



--END