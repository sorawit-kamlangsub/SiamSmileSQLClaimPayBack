DECLARE @TmpCode VARCHAR(20) = 'IMCHG6901000068'
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
			,d.PolicyNo
		INTO #TmpDetail
		FROM
			(	--SSS------
				SELECT t.TmpClaimHeaderGroupImportId
						,h.ClaimHeaderGroup_id					AS ClaimHeaderGroupCodeInDB
						,CAST(v.Pay_Total AS DECIMAL(16,2))		AS TotalAmount
						,v.PaySS_Total							AS TotalAmountSS
						,ins.Organize_ID						AS InsuranceCompanyId
						,h.Code									AS ClaimHeaderCodeInDB
						,IIF(h.Product_id = 'P30',h.Product_id,'1000') AS ProductGroup
						,cus.InsuredPolicy_no					AS PolicyNo
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
						,hg.Code								AS ClaimHeaderGroupCodeInDB
						,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
						,h.PaySS_Total							AS TotalAmountSS
						,ins.Organize_ID						AS InsuranceCompanyId
						,h.Code									AS ClaimHeaderCodeInDB
						,'2000'									AS ProductGroup
						,ctp.Detail								AS PolicyNo
				FROM #Tmp t
					INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg
						ON t.ClaimHeaderGroupCode = hg.Code
					LEFT JOIN SSSPA.dbo.DB_ClaimHeader h
						ON hg.Code = h.ClaimheaderGroup_id
					LEFT JOIN DataCenterV1.Organize.Organize AS ins
						ON hg.InsuranceCompany_id = ins.OrganizeCode
					LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
						ON h.CustomerDetail_id = ctd.Code
					LEFT JOIN SSSPA.dbo.DB_Customer AS cus
						ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090' --????????????????????
					LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
						ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601' --??????????????? ????
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
					,cus.InsuredPolicy_no						AS PolicyNo
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
					,cm.ClaimHeaderGroupCode		ClaimHeaderGroupCodeInDB
					,cm.PayAmount					TotalAmount
					,cm.PayAmount					TotalAmountSS
					,org.Organize_ID				InsuranceCompanyId
					,NULL							ClaimHeaderCodeInDB
					,'Misc'							ProductGroup
					,cm.PolicyNo					PolicyNo
				FROM #Tmp t
					INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm
						ON t.ClaimHeaderGroupCode = cm.ClaimHeaderGroupCode
					LEFT JOIN [ClaimMiscellaneous].[misc].[InsuranceCompany] ins
						ON ins.InsuranceCompanyId = cm.InsuranceCompanyId
					LEFT JOIN [DataCenterV1].[Organize].[Organize] org
						ON org.OrganizeCode = ins.InsuranceCompanyCode
			)d;

		SELECT * FROM #TmpDetail


		SELECT m.TmpClaimHeaderGroupImportId
			 , m.ClaimHeaderGroupCodeInDB
             , m.ClaimHeaderCodeInDB
			 , m.TotalAmountSS
			 ,d.DocumentListID

		FROM #TmpDetail m
			LEFT JOIN 
				(
					SELECT  td.ClaimHeaderGroupCodeInDB
							,td.ClaimHeaderCodeInDB
							,dl.DocumentListID							
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
				)d
				ON m.ClaimHeaderCodeInDB = d.ClaimHeaderCodeInDB
				AND m.ClaimHeaderGroupCodeInDB = d.ClaimHeaderGroupCodeInDB;

		----------------Update 2023-08-09-----------------------
		SELECT m.TmpClaimHeaderGroupImportId
			 , m.ClaimHeaderGroupCodeInDB
             , m.ClaimHeaderCodeInDB
			 , m.TotalAmountSS
			 , IIF(m.ProductGroup = 'Misc',1,ISNULL(d.CountDoc,0)) CountDoc
			 , IIF(IIF(m.ProductGroup = 'Misc',1,ISNULL(d.CountDoc,0)) = 0,N'??????????????','') ValidateDetailResult

		FROM #TmpDetail m
			LEFT JOIN 
				(
					SELECT  td.ClaimHeaderGroupCodeInDB
							,td.ClaimHeaderCodeInDB
							,CASE 
								WHEN 
									-- ????????????? PH ?????????????????????????????????????????????????(24) ???????????????????????????????? (134)
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup IN ('P30','1000') AND dl.DocumentListID = 24 THEN 1 ELSE 0 END) >= 1
									AND
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup IN ('P30','1000') AND dl.DocumentListID = 134 THEN 1 ELSE 0 END) >= 1
								THEN 1
								WHEN 
									-- ????????????? PA ?????????????????????????????????????????????????(26) ???????????????????????????????? (135)
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup = '2000' AND dl.DocumentListID = 26 THEN 1 ELSE 0 END) >= 1
									AND
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup = '2000' AND dl.DocumentListID = 135 THEN 1 ELSE 0 END) >= 1
								THEN 1
								WHEN 
									-- ???????????????? ?????????????????????????
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H THEN 1 ELSE 0 END) = 0
								THEN 1
								WHEN 
									-- ??????????????????
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

IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;
IF OBJECT_ID('tempdb..#TmpDetail') IS NOT NULL  DROP TABLE #TmpDetail;
IF OBJECT_ID('tempdb..#TmpDoc') IS NOT NULL  DROP TABLE #TmpDoc;
IF OBJECT_ID('tempdb..#TmpUpdate') IS NOT NULL  DROP TABLE #TmpUpdate;
IF OBJECT_ID('tempdb..#TmpClaimType') IS NOT NULL  DROP TABLE #TmpClaimType;