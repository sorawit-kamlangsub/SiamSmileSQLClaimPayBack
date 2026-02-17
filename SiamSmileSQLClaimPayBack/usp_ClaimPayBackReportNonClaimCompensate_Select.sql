USE [ClaimPayBack]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






-- =============================================
-- Author:		06588 Krekpon Dokkamklang Mind
-- Create date: 2024-06-20
-- Description:	ClaimPayBackReport รายงานส่งการเงินที่ไม่ใช่ประเภทโอนแยก
-- Update date: 2024-06-25
-- Description:	แก้ไขเงื่อนไข เอาเลขโรงพยาบาลมาหานอกการ JOIN UNION
-- Update date: 2024-07-01 06588 Krekpon.D Mind
-- Description:	เปลี่ยนโค้ดการทำงานใหม่ ให้ทำงานเร็วขึ้น
-- Update date: 2025-05-15 Wetpisit.P
-- Description:	เพิ่มการดึงข้อมูล ClaimNo CustomerName และ RecordedDate ถ้าเป็นเคลมโรงพยาบาล PH,PA
-- Update date: 2025-08-13 Bunchuai chaiket 
-- Description:	แก้ไขการดึงข้อมูล @ClaimGroupTypeId = 6 Hospital,COL, Province และเพิ่ม SELECT HospitalCode
-- Update date: 2025-08-18 16:22 Bunchuai chaiket 
-- Description:	Select icu.ClaimCode AS ClaimNo เพิ่ม
-- Update date: 2025-08-18 17:52 Krekpon Dokkamklang Mind 
-- Description:	remove where product
-- Update date: 2025-08-19 16:34 Krekpon Dokkamklang Mind 
-- Description:	WHERE isAcive
-- Update date: 2025-08-20 16:10 Krekpon Dokkamklang Mind 
-- Description:	ปรับการทำงานตอนดึงข้อมูล
-- Update date: 2025-10-16 15:20 Sorawit Kamlangsub
-- Description:	ปรับเรียกข้อมูล Employee
-- Update date: 2025-10-29 14:31 Sorawit Kamlangsub
-- Description:	Add UNION ClaimMisc
-- Update date: 2025-12-08 10:06 Krekpon.D
-- Update date: 2025-12-11 09.00 Mr.Bunchuai Chaiket (08498)
-- Description:	ปรับการแสดงผล (SELECT ข้อมูลเพิ่ม) จากระบบ ClaimMisc
-- Description:	Add province
-- Update date: 2025-12-22 9:35 Sorawit.K 
-- Description:	Fix ClaiMisc ProductGroupDetailName 
-- Update date: 2025-12-24 10.52 06588 Krekpon.D Mind
-- Description:	ปรับเงื่อนไขการแสดงข้อมูลเคลมออนไลน์ไม่ให้แสดง ธนาคาร,ชื่อบัญชี,เลขที่
-- Update date: 2025-12-24 17.07 Sorawit.k
-- Description:	ปรับเงื่อนไขการแสดงข้อมูลเคลมเบ็ดเตล็ดให้แสดง ธนาคาร,ชื่อบัญชี,เลขที่ เฉพาะ ยิ้มแฉ่ง
-- Update date: 2026-01-08 10.14 06588 Krekpon.D Mind
-- Description:	ปรับเงื่อนไขการแสดงข้อมูลเคลม MISC ให้ไม่แสดง ธนาคาร,ชื่อบัญชี,เลขที่
-- Update date: 2026-01-14 14.11 06588 Krekpon.D Mind
-- Description: ปรับรายการแสดงของการเลือก ProductType
-- Update date: 2026-02-17 14.11 Sorawit.k
-- Description: ปรับการค้นหา ClaimMisc Motor
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackReportNonClaimCompensate_Select]
	 @DateFrom			DATE =	NULL
	,@DateTo			DATE =	NULL
	,@InsuranceId		INT =	NULL
	,@ProductGroupId	INT =	NULL
	,@ClaimGroupTypeId	INT =	NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
-- START TEST
--DECLARE
--	 @DateFrom			DATE =	'2026-02-16'
--	,@DateTo			DATE =	'2026-02-17'
--	,@InsuranceId		INT =	NULL
--	,@ProductGroupId	INT =	4
--	,@ClaimGroupTypeId	INT =	7;
-- END Test

DECLARE @TmpClaimPayBack TABLE (
	 ClaimGroupCodeFromCPBD NVARCHAR(150),
	 ClaimGroupType NVARCHAR(100),
	 ItemCount		 INT,
     Amount			 DECIMAL(16,2),
	 ProductGroupDetailName NVARCHAR(20),
	 BranchId		 INT,
	 COL			 NVARCHAR(150),
	 CreatedDate	 DATETIME,
	 CreatedByUser NVARCHAR(150),
	 HospitalCode VARCHAR(20)
     )

	SELECT 
		pu.User_ID
		,e.EmployeeCode
		,CONCAT(e.EmployeeCode,' ',pT.TitleDetail,p.FirstName,' ',p.LastName) PersonName
	INTO #TmpPersonUser
	FROM DataCenterV1.Person.PersonUser pu
	LEFT JOIN  DataCenterV1.Person.Person p 
		ON pu.Person_ID = p.Person_ID
			AND p.IsActive = 1
	LEFT JOIN DataCenterV1.Employee.Employee e
		ON pu.Employee_ID = e.Employee_ID
			AND e.IsActive = 1
	LEFT JOIN DataCenterV1.Person.Title pT 
		ON p.Title_ID = pT.Title_ID
	WHERE pu.IsActive = 1

	CREATE INDEX IX_TmpPersonUser_User_ID ON #TmpPersonUser(User_ID);
	CREATE INDEX IX_TmpPersonUser_Code ON #TmpPersonUser(EmployeeCode);

	SELECT 11	ProductGroupID
		  ,[ProductType_ID]
		  ,CASE [ProductType_ID]
			WHEN  27 THEN N'PA ชุมชน'
			WHEN  32 THEN N'สไมล์พลัส'
			WHEN  33 THEN N'ประกันเดินทาง'
			WHEN  38 THEN N'PA บุคลากร ยิ้มแฉ่ง'
			WHEN  41 THEN N'PA ครอบครัวอุ่นใจ'
			WHEN  10 THEN N'ประกันบ้าน'
			ELSE [ProductTypeDetail]
		END as Detail
	INTO #TmpProductClaimMisc
	FROM [DataCenterV1].[Product].[ProductType]
	WHERE ProductGroup_ID IN(6,7,9,11)
		AND ProductType_ID IN (10,11,27,32,33,38,41,42)
		AND IsActive = 1 

	DECLARE @ProductGroupTB TABLE 
	(
		ProductGroupID INT,
		ProductType_ID INT,
		ProductGroupDetail NVARCHAR(100)	
	);
	INSERT INTO @ProductGroupTB (ProductGroupID,ProductType_ID, ProductGroupDetail)
	VALUES
		(1,1, N'รอข้อมูล'),
		(2,2, N'PH'),
		(3,3, N'PA'),
		(4,4, N'Motor');

 -- เอาข้อมูลลงใน temp แล้วไป JOIN ต่อกับฝั่ง Base อื่น
 INSERT INTO @TmpClaimPayBack(
      ClaimGroupCodeFromCPBD,
	  ClaimGroupType,
	  ItemCount,
      Amount,
	  ProductGroupDetailName,
	  BranchId,
	  COL,
	  CreatedDate,
	  CreatedByUser,
	  HospitalCode
      )
 SELECT   
     cpbd.ClaimGroupCode						AS ClaimGroupCode,
	 cgt.ClaimGroupType							AS ClaimGroupType,
	 cpbd.ItemCount								AS ItemCount,
     cpbd.Amount								AS Amount,
	 dppg.ProductGroupDetail					AS ProductGroupDetailName,
	 cpb.BranchId								AS BranchId,
	 cpbd.ClaimOnLineCode						AS COL,
	 cpb.CreatedDate							AS CreatedDate,
	 pu.PersonName								AS CreatedByUser,
	 cpbd.HospitalCode							AS HospitalCode
 FROM  ClaimPayBack cpb
		 LEFT JOIN (
			SELECT 
			 ClaimPayBackId
			 ,ClaimGroupCode
			 ,ItemCount
			 ,Amount
			 ,ClaimOnLineCode
			 ,HospitalCode
			 ,ProductGroupId
			 ,InsuranceCompanyId
			FROM ClaimPayBackDetail
			WHERE IsActive = 1
		 ) cpbd
			ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
		LEFT JOIN [DataCenterV1].[Product].ProductGroup dppg
			ON cpbd.ProductGroupId = dppg.ProductGroup_ID
		LEFT JOIN ClaimGroupType cgt
			ON cpb.ClaimGroupTypeId = cgt.ClaimGroupTypeId
		INNER JOIN #TmpPersonUser pu
			ON pu.User_ID = cpb.CreatedByUserId
 		LEFT JOIN
		(
			SELECT
				ClaimHeaderGroupCode
				,ProductGroupId
				,ProductTypeId
			FROM [ClaimMiscellaneous].[misc].[ClaimMisc] 
			WHERE IsActive = 1
		) cm
			ON cm.ClaimHeaderGroupCode = cpbd.ClaimGroupCode
		 LEFT JOIN 
		 (
			SELECT
				* 
			FROM #TmpProductClaimMisc
			UNION ALL
			SELECT
				*
			FROM @ProductGroupTB	 
		 ) pg
			ON pg.ProductType_ID = cpbd.ProductGroupId
				OR pg.ProductType_ID = cm.ProductTypeId
 WHERE   cpb.ClaimGroupTypeId = @ClaimGroupTypeId
	AND cpb.IsActive = 1
	AND ((cpb.CreatedDate >= @DateFrom) AND (cpb.CreatedDate < DATEADD(Day,1,@DateTo)))
	AND (pg.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL)
	AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)
	 
	--SELECT เอาไปใช้งาน
    SELECT		icu.InsuranceCompany_Name									InsuranceCompany_Name
				,dab.BranchDetail											Branch
				,IIF(@ClaimGroupTypeId IN( 4,6,7),sssmtc.Detail,NULL)		Hospital
				,CASE 
					WHEN @ClaimGroupTypeId IN (2,4,6) THEN TmpCPB.ProductGroupDetailName
					WHEN @ClaimGroupTypeId = 7		  THEN icu.ProductTypeName
					ELSE NULL
				END															ProductGroupDetailName
				,TmpCPB.ClaimGroupType										ClaimGroupType
				,TmpCPB.ClaimGroupCodeFromCPBD								ClaimGroupCode
				,TmpCPB.ItemCount											ItemCount
				,TmpCPB.Amount												Amount
				,NULL														ClaimCompensate
				,icu.ClaimCode												ClaimNo 
				,IIF(@ClaimGroupTypeId IN (2,6,7) , TmpCPB.COL,NULL)		COL
				,IIF(@ClaimGroupTypeId IN (2,4,6,7) ,sssmp.Detail,NULL)		Province
				,IIF(@ClaimGroupTypeId IN (2,4,6,7) ,icu.CustomerName,NULL)	CustomerName
				,CASE 
					WHEN @ClaimGroupTypeId IN (4,6)							THEN sssmtb.Detail
					ELSE NULL
				END												BankName
				,CASE 
					WHEN @ClaimGroupTypeId IN (4,6)							THEN sssmtc.BankAccountName
					ELSE NULL
				END												BankAccountName
				,CASE 
					WHEN @ClaimGroupTypeId IN (4,6)							THEN REPLACE(sssmtc.BankAccountNo,'-','')
					ELSE NULL
				END												BankAccountNo
				,NULL											PhoneNo
				,TmpCPB.CreatedDate								CreatedDate
				,pu.PersonName									ApprovedUser 
				,TmpCPB.CreatedByUser							CteatedUser 
				,icu.ClaimAdmitType								ClaimAdmitType
				,NULL											RecordedDate

FROM @TmpClaimPayBack TmpCPB
	 LEFT JOIN(

			-- SSS
			SELECT chg.Code										Code
				, chg.InsuranceCompany_Name						InsuranceCompany_Name
				, cat.Detail									ClaimAdmitType
				, chg.Hospital_id								Hospital
				, chg.CreatedBy_id								ApprovedUserFromSSS
				,CONCAT(tt.Detail,ct.FirstName,' ',ct.LastName) CustomerName
				,ch.Code										ClaimCode
				,NULL											BankAccountName
				,NULL											BankAccountNo
				,NULL											BankName
				,NULL											PhoneNo
				,NULL											ProductTypeName
				,NULL											ProductTypeId
			FROM sss.dbo.DB_ClaimHeaderGroup chg
			LEFT JOIN SSS.dbo.MT_ClaimAdmitType cat
				ON chg.ClaimAdmitType_id = cat.Code
			LEFT JOIN SSS.dbo.DB_ClaimHeader ch
				ON ch.ClaimHeaderGroup_id = chg.Code
			LEFT JOIN SSS.dbo.DB_Customer ct
				ON ct.App_id = ch.App_id
			LEFT JOIN SSS.dbo.MT_Title tt
				ON tt.Code = ct.Title_id
			
			
			UNION ALL
			
			-- SSSPA
			SELECT DISTINCT pachg.Code							Code
				, pachg.InsuranceCompany_Name					InsuranceCompany_Name
				, smc.Detail									ClaimAdmitType
				, pachg.Hospital_id								Hospital
				, pachg.CreatedBy_id							ApprovedUserFromSSS
				,CONCAT(tt.Detail,cd.FirstName,' ',cd.LastName) CustomerName
				,ch.Code										ClaimCode
				,NULL											BankAccountName
				,NULL											BankAccountNo
				,NULL											BankName
				,NULL											PhoneNo
				,NULL											ProductTypeName
				,NULL											ProductTypeId
			FROM SSSPA.dbo.DB_ClaimHeaderGroup pachg
			LEFT JOIN SSSPA.dbo.SM_Code smc
				ON pachg.ClaimTypeGroup_id = smc.Code
			LEFT JOIN SSSPA.dbo.DB_ClaimHeader ch
				ON ch.ClaimheaderGroup_id = pachg.Code
			LEFT JOIN SSSPA.dbo.DB_CustomerDetail cd
				ON cd.Code = ch.CustomerDetail_id
			LEFT JOIN SSSPA.dbo.MT_Title tt
				ON tt.Code = cd.Title_id
			
			UNION ALL
			
			-- ClaimMisc
			SELECT 
				ClaimHeaderGroupCode		Code
				,InsuranceCompanyName		InsuranceCompany_Name
				,cxa.ClaimAdmitType			ClaimAdmitType
				,h.HospitalCode				Hospital
				,u.EmployeeCode				ApprovedUserFromSSS
				,cm.CustomerName			CustomerName
				,cm.ClaimMiscNo				ClaimCode
				,NULL						BankAccountName
				,NULL						BankAccountNo
				,NULL						BankName
				,ce.ContactPersonPhoneNo	PhoneNo
				,pd.ProductTypeName
				,pd.ProductTypeId
			FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			LEFT JOIN [ClaimMiscellaneous].[misc].[Hospital] h
				ON h.HospitalId = cm.HospitalId 
			LEFT JOIN #TmpPersonUser u
				ON u.[User_ID] = cm.CreatedByUserId
			LEFT JOIN
			(
				SELECT
					 x.ClaimMiscId
					 ,STUFF((
					         SELECT ',' + a.ClaimAdmitTypeName
					         FROM [ClaimMiscellaneous].[misc].[ClaimMiscXClaimAdmitType] x2
								JOIN [ClaimMiscellaneous].[misc].[ClaimAdmitType] a
					                 ON a.ClaimAdmitTypeId = x2.ClaimAdmitTypeId
					         WHERE x2.IsActive = 1
								AND a.IsActive  = 1
								AND x2.ClaimMiscId = x.ClaimMiscId
					         FOR XML PATH(''), TYPE
					 ).value('.', 'nvarchar(255)'), 1, 1, '')        ClaimAdmitType
				FROM [ClaimMiscellaneous].[misc].[ClaimMiscXClaimAdmitType] x
				WHERE x.IsActive = 1
				GROUP BY x.ClaimMiscId
			) cxa
				ON cxa.ClaimMiscId = cm.ClaimMiscId
			LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimEvent] ce
				ON cm.ClaimEventId = ce.ClaimEventId
			LEFT JOIN 
			(
				SELECT 
					ProductTypeId
					,ProductTypeName
				FROM [ClaimMiscellaneous].[misc].[ProductType] 
				WHERE IsActive = 1
			) pd
				ON pd.ProductTypeId = cm.ProductTypeId
		) icu
		ON TmpCPB.ClaimGroupCodeFromCPBD = icu.Code
	LEFT JOIN [DataCenterV1].[Address].Branch dab
		ON TmpCPB.BranchId = dab.Branch_ID
	INNER JOIN #TmpPersonUser pu
		ON icu.ApprovedUserFromSSS = pu.EmployeeCode
	LEFT JOIN SSS.dbo.MT_Company sssmtc
		ON icu.Hospital = sssmtc.Code OR icu.Hospital = sssmtc.Code
	LEFT JOIN SSS.dbo.MT_Bank sssmtb
		ON sssmtc.Bank_id = sssmtb.Code
	LEFT JOIN SSS.dbo.DB_Address sssadr
		ON sssmtc.Address_id = sssadr.Code
	LEFT JOIN SSS.dbo.SM_Province sssmp
		ON sssadr.Province_id = sssmp.Code;

IF OBJECT_ID('tempdb..#TmpPersonUser') IS NOT NULL DROP TABLE #TmpPersonUser;
IF OBJECT_ID('tempdb..#TmpProductClaimMisc') IS NOT NULL DROP TABLE #TmpProductClaimMisc;
IF OBJECT_ID('tempdb..@TmpClaimPayBack') IS NOT NULL  DELETE FROM @TmpClaimPayBack;   
END;
