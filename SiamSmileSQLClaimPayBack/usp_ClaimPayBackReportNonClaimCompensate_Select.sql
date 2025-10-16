USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackReportNonClaimCompensate_Select]    Script Date: 16/10/2568 14:43:45 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

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
-- =============================================
--ALTER PROCEDURE [dbo].[usp_ClaimPayBackReportNonClaimCompensate_Select]
DECLARE
	-- Add the parameters for the stored procedure here
	 @DateFrom			DATE = '2025-10-15'
	,@DateTo			DATE = '2025-10-16'
	,@InsuranceId		INT = NULL
	,@ProductGroupId	INT = NULL
	,@ClaimGroupTypeId	INT = 2

--AS
--BEGIN
--	-- SET NOCOUNT ON added to prevent extra result sets from
--	-- interfering with SELECT statements.
--	SET NOCOUNT ON;
	--ประกาศ Table เก็บข้อมูลจาก ClaimPayBack 2025-08-20 16:10 Krekpon Dokkamklang Mind 
--SELECT 
--    UserId,
--    EmployeeId
--INTO #TmpPersonUser
--FROM [DataCenterV1].[Person].vw_PersonUser;

--CREATE INDEX IX_TmpPersonUser_UserId ON #TmpPersonUser(UserId);
--CREATE INDEX IX_TmpPersonUser_EmpId ON #TmpPersonUser(EmployeeId);

----เอาข้อมูล Master Employee ของ DataCenter มาทำ tmp 2025-08-20 16:10 Krekpon Dokkamklang Mind 
--SELECT 
--    EmployeeId,
--    EmployeeCode,
--    PersonName
--INTO #TmpEmployee
--FROM [DataCenterV1].[Master].vw_Employee;

--CREATE INDEX IX_TmpEmployee_Id ON #TmpEmployee(EmployeeId);
--CREATE INDEX IX_TmpEmployee_Code ON #TmpEmployee(EmployeeCode); 

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
	 --CONCAT(dme.EmployeeCode,' ',dme.PersonName) AS CreatedByUser,
	 CONCAT(pu.EmployeeCode,' ',pu.PersonName)	AS CreatedByUser,
	 cpbd.HospitalCode							AS HospitalCode
 FROM  ClaimPayBack cpb
	 LEFT JOIN ClaimPayBackDetail cpbd
		ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
	 LEFT JOIN [DataCenterV1].[Product].ProductGroup dppg
		ON cpbd.ProductGroupId = dppg.ProductGroup_ID
	 LEFT JOIN ClaimGroupType cgt
		ON cpb.ClaimGroupTypeId = cgt.ClaimGroupTypeId
	 --LEFT JOIN #TmpPersonUser dmpu	--2025-08-20 16:10 Krekpon Dokkamklang Mind 
		--ON cpb.CreatedByUserId = dmpu.UserId
	 --INNER JOIN #TmpEmployee dme	--2025-08-20 16:10 Krekpon Dokkamklang Mind 
		--ON dmpu.EmployeeId = dme.EmployeeId
	LEFT JOIN 
	(
		SELECT
		  pu.User_ID		UserId
		  ,e.EmployeeCode
		  ,CONCAT(p.FirstName,' ',p.LastName) PersonName
		FROM
		  ( 
			SELECT 
				User_ID
				, Person_ID
				, Employee_ID
					FROM DataCenterV1.Person.PersonUser t 
			WHERE IsActive = 1 
		  ) pu
		  LEFT OUTER JOIN DataCenterV1.Person.Person p 
			ON pu.Person_ID = p.Person_ID
		  LEFT OUTER JOIN 
		  ( 
			SELECT 
				Employee_ID
				, EmployeeCode
			FROM DataCenterV1.Employee.Employee t
			WHERE IsActive = 1 
			) e 
			ON pu.Employee_ID = e.Employee_ID
	) pu
		ON pu.UserId = cpb.CreatedByUserId
WHERE   cpb.ClaimGroupTypeId = @ClaimGroupTypeId
	AND cpb.IsActive = 1 
	AND cpbd.IsActive = 1
	AND ((cpb.CreatedDate >= @DateFrom) AND (cpb.CreatedDate < DATEADD(Day,1,@DateTo)))
    AND (cpbd.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL)
	AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)

	--SELECT เอาไปใช้งาน
    SELECT		icu.InsuranceCompany_Name AS InsuranceCompany_Name,
				dab.BranchDetail AS Branch,
				IIF(@ClaimGroupTypeId IN( 4,6),sssmtc.Detail,NULL) AS Hospital,
				TmpCPB.ProductGroupDetailName AS ProductGroupDetailName,
				TmpCPB.ClaimGroupType AS ClaimGroupType,
				TmpCPB.ClaimGroupCodeFromCPBD AS ClaimGroupCode,
				TmpCPB.ItemCount AS ItemCount,
				TmpCPB.Amount AS Amount,
				NULL AS ClaimCompensate,
				--IIF(@ClaimGroupTypeId IN (2,4,6) AND @ProductGroupId IN (2,3),icu.ClaimCode,NULL) AS ClaimNo, --Wetpisit.P 2025-05-15
				icu.ClaimCode AS ClaimNo ,
				IIF(@ClaimGroupTypeId IN (2,6) , TmpCPB.COL,NULL) AS COL,
				IIF(@ClaimGroupTypeId IN (2,4,6) ,sssmp.Detail,NULL) AS Province,
				IIF(@ClaimGroupTypeId IN (2,4,6) ,icu.CustomerName,NULL) AS CustomerName, --Wetpisit.P 2025-05-15 --Krekpon D. 2025-08-18 remove where product
				--NULL AS CustomerName,
				IIF(@ClaimGroupTypeId IN (2,4),sssmtb.Detail,NULL) As BankName,
				IIF(@ClaimGroupTypeId IN (2,4),sssmtc.BankAccountName,NULL) AS BankAccountName,
				IIF(@ClaimGroupTypeId IN (2,4),REPLACE(sssmtc.BankAccountNo,'-',''),NULL) AS BankAccountNo,
				NULL AS PhoneNo,
				TmpCPB.CreatedDate AS CreatedDate,
				CONCAT(pu.EmployeeCode,' ',pu.PersonName) AS ApprovedUser ,
				TmpCPB.CreatedByUser AS CteatedUser ,	--2025-08-20 16:10 Krekpon Dokkamklang Mind 
				icu.ClaimAdmitType AS ClaimAdmitType,
				--IIF(@ClaimGroupTypeId IN (2,4,6) AND @ProductGroupId IN (2,3) ,icu.RecordedDate,NULL) AS RecordedDate --Wetpisit.P 2025-05-15
				NULL AS RecordedDate

FROM @TmpClaimPayBack TmpCPB
	 LEFT JOIN(
								SELECT chg.Code AS Code
									, chg.InsuranceCompany_Name AS InsuranceCompany_Name
									, cat.Detail AS ClaimAdmitType
									, chg.Hospital_id AS Hospital
									, chg.CreatedBy_id AS ApprovedUserFromSSS
									,CONCAT(tt.Detail,ct.FirstName,' ',ct.LastName) AS CustomerName
									--,hct.RecordedDate
									,ch.Code AS ClaimCode

								FROM sss.dbo.DB_ClaimHeaderGroup chg
								LEFT JOIN SSS.dbo.MT_ClaimAdmitType cat
									ON chg.ClaimAdmitType_id = cat.Code
								--Wetpisit.P 2025-05-15
								LEFT JOIN SSS.dbo.DB_ClaimHeader ch
									ON ch.ClaimHeaderGroup_id = chg.Code
								--LEFT JOIN ClaimOnLineV2.dbo.HospitalClaimTracking hct
								--	ON hct.ClaimCode = ch.Code
								LEFT JOIN SSS.dbo.DB_Customer ct
									ON ct.App_id = ch.App_id
								LEFT JOIN SSS.dbo.MT_Title tt
									ON tt.Code = ct.Title_id
								
								
								UNION ALL

								SELECT DISTINCT pachg.Code AS Code
									, pachg.InsuranceCompany_Name AS InsuranceCompany_Name
									, smc.Detail AS ClaimAdmitType
									, pachg.Hospital_id AS Hospital
									, pachg.CreatedBy_id AS ApprovedUserFromSSS
									,CONCAT(tt.Detail,cd.FirstName,' ',cd.LastName) AS CustomerName
									--,hct.RecordedDate
									,ch.Code AS ClaimCode

								FROM SSSPA.dbo.DB_ClaimHeaderGroup pachg
								LEFT JOIN SSSPA.dbo.SM_Code smc
									ON pachg.ClaimTypeGroup_id = smc.Code
								--Wetpisit.P 2025-05-15
								LEFT JOIN SSSPA.dbo.DB_ClaimHeader ch
									ON ch.ClaimheaderGroup_id = pachg.Code
								LEFT JOIN SSSPA.dbo.DB_CustomerDetail cd
									ON cd.Code = ch.CustomerDetail_id
								--LEFT JOIN ClaimOnLineV2.dbo.HospitalClaimTracking hct
								--	ON hct.ClaimCode = ch.Code
								LEFT JOIN SSSPA.dbo.MT_Title tt
									ON tt.Code = cd.Title_id
								
				) icu
		ON TmpCPB.ClaimGroupCodeFromCPBD = icu.Code
	LEFT JOIN [DataCenterV1].[Address].Branch dab
		ON TmpCPB.BranchId = dab.Branch_ID
	--INNER JOIN #TmpEmployee dmeu	--2025-08-20 16:10 Krekpon Dokkamklang Mind 
	--	ON icu.ApprovedUserFromSSS  = dmeu.EmployeeCode
	LEFT JOIN 
	(
		SELECT
		  e.EmployeeCode
		  ,CONCAT(pT.TitleDetail,p.FirstName,' ',p.LastName) PersonName
		FROM
		  ( 
			SELECT 
				Person_ID
				, Employee_ID
					FROM DataCenterV1.Person.PersonUser t 
			WHERE IsActive = 1 
			) pu
		  LEFT OUTER JOIN DataCenterV1.Person.Person p 
			ON pu.Person_ID = p.Person_ID
		  LEFT OUTER JOIN 
		  ( 
			SELECT 
				Employee_ID
				, EmployeeCode
			FROM DataCenterV1.Employee.Employee t
			WHERE IsActive = 1 
			) e 
			ON pu.Employee_ID = e.Employee_ID
		  INNER JOIN DataCenterV1.Person.Title pT 
			ON p.Title_ID = pT.Title_ID
		  WHERE pt.IsActive = 1 
	) pu
		ON pu.EmployeeCode = icu.ApprovedUserFromSSS
	LEFT JOIN SSS.dbo.MT_Company sssmtc
		ON icu.Hospital = sssmtc.Code OR TmpCPB.HospitalCode = sssmtc.Code
	LEFT JOIN SSS.dbo.MT_Bank sssmtb
		ON sssmtc.Bank_id = sssmtb.Code
	LEFT JOIN SSS.dbo.DB_Address sssadr
		ON sssmtc.Address_id = sssadr.Code
	LEFT JOIN SSS.dbo.SM_Province sssmp
		ON sssadr.Province_id = sssmp.Code

IF OBJECT_ID('tempdb..#TmpPersonUser') IS NOT NULL DROP TABLE #TmpPersonUser;
IF OBJECT_ID('tempdb..#TmpEmployee') IS NOT NULL DROP TABLE #TmpEmployee;
IF OBJECT_ID('tempdb..@TmpClaimPayBack') IS NOT NULL  DELETE FROM @TmpClaimPayBack; -- ปรับ Code การทำงานให้ทำงานได้ไวขึ้น 2024-07-01
--END
