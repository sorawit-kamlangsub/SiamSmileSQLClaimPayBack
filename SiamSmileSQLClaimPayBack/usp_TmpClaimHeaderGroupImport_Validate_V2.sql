USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_TmpClaimHeaderGroupImport_Validate_V2]    Script Date: 16/10/2568 9:00:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


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
-- Description:	
-- =============================================
ALTER PROCEDURE [dbo].[usp_TmpClaimHeaderGroupImport_Validate_V2]
	@TmpCode VARCHAR(20)

AS
BEGIN
	
SET NOCOUNT ON;

--DECLARE @ClaimHeaderGroupTypeId INT;
DECLARE @ClaimHeaderSSS INT = 2;
DECLARE @ClaimHeaderSSSPA INT = 3;
DECLARE @ClaimCompensate INT = 4;
DECLARE @ClaimHeaderPA30 INT = 5;
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
DECLARE @ClaimTypeCode_H	VARCHAR(20) = '1000'
DECLARE @ClaimTypeCode_C	VARCHAR(20) = '2000'
----------------------------------------------

IF @IsResult = 1			
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
		)m
			INNER JOIN #Tmp x
				ON m.ClaimHeaderGroupCode = x.ClaimHeaderGroupCode;



		--SELECT @ClaimHeaderGroupTypeId = ClaimHeaderGroupTypeId
		--FROM #Tmp
		
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
						ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090' --ไม่ใช่ยกเลิกกรมธรรม์
					LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
						ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601' --เป็นเลขกรมธรรม์ ปกติ
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
							SELECT * 
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
			)d;

		----------------Update 2023-08-09-----------------------
		SELECT m.TmpClaimHeaderGroupImportId
			 , m.ClaimHeaderGroupCodeInDB
             , m.ClaimHeaderCodeInDB
			 , m.TotalAmountSS
             , ISNULL(d.CountDoc,0) CountDoc
			 , IIF(ISNULL(d.CountDoc,0) = 0,N'ไม่พบเอกสารแนบ','') ValidateDetailResult
		INTO #TmpDoc
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
					--AND	(
					--		(	
					--			td.ProductGroup IN('P30','1000') AND --PA30,PH
					--				(
					--					(
					--						ct.ClaimTypeCode = @ClaimTypeCode_H AND dl.DocumentListID IN (24,134) --เคลมโรงพยาบาล(24) กับหนังสือแจ้งชำระค่ารักษาพยาบาล (134)
					--					)
					--					OR
					--					(
					--						ct.ClaimTypeCode = @ClaimTypeCode_C AND dl.DocumentListID IN (22,23) --เคลมสาขา(22) เคลมลูกค้า (23)
					--					)
					--				)
					--		)
					--		OR 
					--		(
					--			td.ProductGroup = '2000' AND  --PA
					--			(
					--				(
					--					ct.ClaimTypeCode = @ClaimTypeCode_H AND dl.DocumentListID IN(26,135) --เคลมโรงพยาบาล(26) กับหนังสือแจ้งชำระค่ารักษาพยาบาล (135)
					--				)
					--				OR 
					--				(
					--					ct.ClaimTypeCode = @ClaimTypeCode_C AND dl.DocumentListID IN (25) --เคลมโรงเรียน(25)
					--				)
					--			)
					--		)
					--	) 
					AND d.IsEnable = 1
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

				--,CONCAT(
				--		CASE
				--			WHEN s.ClaimHeaderGroupCode IS NOT NULL THEN N'รายการบส.ซ้ำกันในไฟล์'
				--			WHEN img.ClaimHeaderGroupCode IS NOT NULL THEN N'รายการบส.ซ้ำกับในระบบ'
				--			WHEN c.ClaimHeaderGroupCodeInDB IS NULL THEN N'ไม่พบเลขบส.นี้ในฐานข้อมูล'
				--			WHEN ISNULL(t.ItemCount,0)<>ISNULL(c.ItemCountInDB,0) THEN N'ข้อมูลจำนวนเคลมไม่ตรงกับในฐานข้อมูล'
				--			WHEN ISNULL(t.TotalAmount ,0) = 0 THEN N'ไม่มียอดเงินในรายการ บ.ส.'
				--			WHEN ISNULL(t.TotalAmount,0)<>ISNULL(c.TotalAmountInDB,0) THEN N'ข้อมูลจำนวนเงินรวมไม่ตรงกับในฐานข้อมูล'
				--			WHEN imd.ClaimCodeInSystem IS NOT NULL AND t.ClaimHeaderGroupCode LIKE '%_0' THEN N'มีรายการเคลมนี้ในระบบแล้ว'
				--			WHEN t.ClaimHeaderGroupTypeId IN (@ClaimHeaderSSS,@ClaimHeaderPA30) AND pg.[2000] >0 AND pg.[1000]>0 THEN N'มีรายการ PH และ PA30 อยู่'
				--			ELSE ''  
				--			END 
				--		,IIF(a.ClaimTypeCode = '',N'ไม่ได้ MappingType (H,C),','')
				--		,''

				--	)ValidateResult
				----------------------Update 2023-08-08--------------------
				,CONCAT
					(
						 IIF(s.ClaimHeaderGroupCode IS NOT NULL,N'รายการ บ.ส. ซ้ำกันในไฟล์, ','')
						,IIF(img.ClaimHeaderGroupCode IS NOT NULL,N'รายการ บ.ส. ซ้ำกับในระบบ, ','')
						,IIF(c.ClaimHeaderGroupCodeInDB IS NULL, N'ไม่พบเลข บ.ส. นี้ในฐานข้อมูล, ','')
						,IIF(t.ItemCount<>ISNULL(c.ItemCountInDB,0) AND t.ClaimHeaderGroupTypeId = pg.ProductGroupId AND s.ClaimHeaderGroupCode IS NULL,N'ข้อมูลจำนวนเคลมไม่ตรงกับในฐานข้อมูล, ','')
						,IIF(t.TotalAmount = 0,N'ไม่มียอดเงินในรายการ บ.ส., ','')
						,IIF(t.TotalAmount<>ISNULL(c.TotalAmountInDB,0) AND t.ClaimHeaderGroupTypeId = pg.ProductGroupId AND s.ClaimHeaderGroupCode IS NULL,CONCAT(N'ข้อมูลจำนวนเงินรวมไม่ตรงกับในฐานข้อมูล','( ',FORMAT(c.TotalAmountInDB,'N'),'), '),'')
						--,IIF(imd.ClaimCodeInSystem IS NOT NULL AND t.ClaimHeaderGroupCode LIKE '%_0',N'มีรายการเคลมนี้ในระบบแล้ว, ','')
						,IIF(imd.ClaimCodeInSystem IS NOT NULL AND t.ClaimHeaderGroupCode LIKE '%_0' AND cbd.ClaimGroupCode = t.ClaimHeaderGroupCode AND imd.ClaimHeaderGroupCode = t.ClaimHeaderGroupCode ,N'มีรายการเคลมนี้ในระบบแล้ว, ','') -- Update 2024-02-01 Kittisak.Ph เช็ครายการเคลมซ้ำ ใน บ.ส.เดียวกัน --Update 2024-06-17 Krekpon.Mind เพิ่มเงื่อนไข
						--,IIF(t.ClaimHeaderGroupTypeId IN (@ClaimHeaderSSS,@ClaimHeaderPA30) AND pg.[2000] >0 AND pg.[1000]>0 ,N'มีรายการ PH และ PA30 อยู่, ','')
						,IIF(t.ClaimHeaderGroupTypeId IN (@ClaimHeaderSSS,@ClaimHeaderPA30) AND t.ClaimHeaderGroupTypeId <> pg.ProductGroupId,CONCAT(N'รายการ บ.ส. นี้ ไม่ใช่กลุ่ม', 
									' ',IIF(t.ClaimHeaderGroupTypeId = @ClaimHeaderSSS,'PH','PA30'),N' ตามกลุ่มที่ระบุ, '),'')
						,IIF(doc.CountDoc > 0 ,N'บ.ส. ไม่มีเอกสารแนบ, ','')
						,IIF(a.ClaimTypeCode = '',N'ไม่ได้ MappingType (H,C), ','')
						--,IIF(c.PolicyNo = '' OR c.PolicyNo IS NULL,'ไม่มีกรมธรรม์ในรายการ บ.ส.','' ) --kittisak.Ph 20250513
					)ValidateResult
				---------------------------------------------------------------
				,a.ClaimTypeCode

		INTO #TmpUpdate
		FROM #Tmp t
			LEFT JOIN 
				(
					SELECT ClaimHeaderGroupCodeInDB
						,InsuranceCompanyId
						,COUNT(ClaimHeaderGroupCodeInDB) ItemCountInDB
						,SUM(TotalAmountSS)  TotalAmountInDB
						,MAX(ProductGroup)	ProductGroup
						,PolicyNo
					FROM #TmpDetail
					GROUP BY ClaimHeaderGroupCodeInDB,InsuranceCompanyId,PolicyNo
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
					SELECT  d.ClaimHeaderGroupCodeInDB AS ClaimCodeInSystem,
							imd.ClaimHeaderGroupCode AS ClaimHeaderGroupCode --Update 2024-06-17 Krekpon.Mind เพิ่มเงื่อนไข
							
						--,MAX(imd.ClaimCode) xClaimCode
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
			--LEFT JOIN 
			--	(
			--		SELECT p.[2000]
			--				,p.[1000] 
			--				,p.TmpCode
			--		FROM
			--			(
			--				SELECT 
			--					hg.ProductGroup_id
			--					,t.TmpCode
			--					,t.TmpClaimHeaderGroupImportId
			--				FROM #Tmp t
			--					LEFT JOIN SSS.dbo.DB_ClaimHeaderGroup hg
			--						ON t.ClaimHeaderGroupCode = hg.Code
			--			)d
			--		PIVOT
			--		(
			--			COUNT(TmpClaimHeaderGroupImportId) FOR ProductGroup_id IN ([1000],[2000])
			--		)p
			--	)pg
			--	ON pg.TmpCode = t.TmpCode
			--LEFT JOIN
			--	(
			--				SELECT 
			--					hg.Code ClaimHeaderGroupCode
			--					,CASE hg.ProductGroup_id
			--						WHEN '1000' THEN 2
			--						WHEN '2000' THEN 5
			--						ELSE ''
			--					END AS ProductGroup_id
			--				FROM SSS.dbo.DB_ClaimHeaderGroup hg
			--			)d
			--			ON t.ClaimHeaderGroupCode = d.ClaimHeaderGroupCode

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
			LEFT JOIN [ClaimPayBack].[dbo].[ClaimPayBackDetail] cbd ON cbd.ClaimGroupCode = t.ClaimHeaderGroupCode
			--WHERE img.IsActive=1; --Kittisak.Ph 2024-01-24 แก้ไขให้ Import ไฟล์ได้ กรณีมีการ Re Import ไฟล์ บ.ส.
			SELECT @CountIsError = COUNT(ValidateResult)
			FROM #TmpUpdate
			WHERE TmpCode = @TmpCode 
			AND ValidateResult <>'';

			IF @CountIsError IS NULL SET @CountIsError = 0;

		------------------------------------------------------

		BEGIN TRY			
			BEGIN TRANSACTION

				DELETE hd
				FROM dbo.TmpClaimHeaderGroupImportDetail hd
					INNER JOIN #TmpDoc d
						ON hd.TmpClaimHeaderGroupImportId = d.TmpClaimHeaderGroupImportId;


				INSERT INTO dbo.TmpClaimHeaderGroupImportDetail
				(
				    TmpClaimHeaderGroupImportId
				  , ClaimHeaderCode
				  , DocumentCount
				  , Amount
				  , ValidateDetailResult
				  ,IsValid
				)
				SELECT TmpClaimHeaderGroupImportId
                     , ClaimHeaderCodeInDB
                     , CountDoc 
					 ,TotalAmountSS
					 ,ValidateDetailResult
					 ,IIF(ValidateDetailResult = '',1,0)
				FROM #TmpDoc 
				ORDER BY TmpClaimHeaderGroupImportId;

				UPDATE m
					SET m.ValidateResult = u.ValidateResult
					,m.IsValid = IIF(u.ValidateResult = '',1,0)
					,m.InsuranceCompanyId = u.InsuranceCompanyId
					,m.ClaimTypeCode = u.ClaimTypeCode
				FROM dbo.TmpClaimHeaderGroupImport m
					INNER JOIN #TmpUpdate u
						ON m.TmpClaimHeaderGroupImportId = u.TmpClaimHeaderGroupImportId;



			SET @IsResult = 1			  					
			SET @Msg = 'บันทึก สำเร็จ'	 												  					
			COMMIT TRANSACTION			  					
		END TRY							  					
		BEGIN CATCH						  					
										  					
			SET @IsResult = 0			  					
			SET @Msg = 'บันทึก ไม่สำเร็จ'						
										  					
			IF @@TRANCOUNT > 0 ROLLBACK	  					
		END CATCH
		
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




--IsResult = 1 and Result = 1  ข้อมูลถูกต้อง เปิดปุ่มให้บันทึกได้


END
