USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackTransferNonClaimCompensateReport_Select]    Script Date: 14/10/2568 16:42:27 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO


-- =============================================
-- Author:		06588 Krekpon Dokkamklang Mind
-- Create date: 2024-06-21
-- Description:	รายงานหลังส่งการเงิน
-- Update date: 2024-07-01 06588 Krekpon.D Mind 
-- Description:	เปลี่ยนโค้ดการทำงานใหม่ ให้ทำงานเร็วขึ้น
-- Update date: 2025-08-15 06588 Krekpon.D Mind 
-- Description:	เพิ่มข้อมูลสำหรับ ClaimGroupTypeId =  6
-- Update date: 2025-08-18 06588 Krekpon.D Mind 
-- Description:	remove where product
-- Update date: 2025-08-20 16:26 06588 Krekpon.D Mind 
-- Description:	ปรับการ join ข้อมูล
-- =============================================
--ALTER PROCEDURE [dbo].[usp_ClaimPayBackTransferNonClaimCompensateReport_Select]
DECLARE
	-- Add the parameters for the stored procedure here
	 @DateFrom			DATE = '2025-10-14'
	,@DateTo			DATE = '2025-10-15'
	,@InsuranceId		INT = NULL
	,@ProductGroupId	INT = NULL
	,@ClaimGroupTypeId	INT = 7
--AS
--BEGIN

--	SET NOCOUNT ON;
    -- Insert statements for procedure here
--เอาข้อมูลของ  Master PersonUser ของ DataCenter มาทำ tmp 2025-08-20 16:26 06588 Krekpon.D Mind 
SELECT 
    UserId,
    EmployeeId
INTO #TmpPersonUser
FROM [DataCenterV1].[Master].vw_PersonUser;

CREATE INDEX IX_TmpPersonUser_UserId ON #TmpPersonUser(UserId);
CREATE INDEX IX_TmpPersonUser_EmpId ON #TmpPersonUser(EmployeeId);

--เอาข้อมูล Master Employee ของ DataCenter มาทำ tmp 2025-08-20 16:26 06588 Krekpon.D Mind 
SELECT 
    EmployeeId,
    EmployeeCode,
    PersonName
INTO #TmpEmployee
FROM [DataCenterV1].[Master].vw_Employee;

CREATE INDEX IX_TmpEmployee_Id ON #TmpEmployee(EmployeeId);
CREATE INDEX IX_TmpEmployee_Code ON #TmpEmployee(EmployeeCode);

--ประกาศ Table เก็บข้อมูลจาก ClaimPayBack
DECLARE @TmpClaimPayBack TABLE (
	 ClaimGroupCodeFromCPBD NVARCHAR(150),
	 ClaimGroupType NVARCHAR(100),
	 ItemCount		 INT,
     Amount			 DECIMAL(16,2),
	 ProductGroupDetailName NVARCHAR(20),
	 BranchId		 INT,
     SendDate		 DATETIME,
     TransferDate    DATETIME,
	 COL			 NVARCHAR(150),
	 CreatedDate	 DATETIME,
	 CreatedByUser   NVARCHAR(150)
     )
 -- เอาข้อมูลลงใน temp แล้วไป JOIN ต่อกับฝั่ง Base อื่น
 INSERT INTO @TmpClaimPayBack(
      ClaimGroupCodeFromCPBD,
	  ClaimGroupType,
	  ItemCount,
      Amount,
	  ProductGroupDetailName,
	  BranchId,
      SendDate,
      TransferDate,
	  COL,
	  CreatedDate,
	  CreatedByUser
      )
 SELECT   
     cpbd.ClaimGroupCode AS ClaimGroupCode,
	 cgt.ClaimGroupType AS ClaimGroupType,
	 cpbd.ItemCount AS ItemCount,
     cpbd.Amount AS Amount,
	 dppg.ProductGroupDetail AS ProductGroupDetailName,
	 cpb.BranchId AS BranchId,
     cpb.CreatedDate AS SendDate,
     cpbt.TransferDate AS CreatedDate,
	 cpbd.ClaimOnLineCode AS COL,
	 cpb.CreatedDate AS CreatedDate,
	 CONCAT(dme.EmployeeCode,' ',dme.PersonName) AS CreatedByUser -- 2025-08-20 16:26 06588 Krekpon.D Mind 
 
 FROM ClaimPayBackTransfer cpbt 
	 INNER JOIN ClaimPayBack cpb
		ON cpbt.ClaimPayBackTransferId = cpb.ClaimPayBackTransferId
	 INNER JOIN ClaimPayBackDetail cpbd
		ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
	 LEFT JOIN [DataCenterV1].[Product].ProductGroup dppg
		ON cpbd.ProductGroupId = dppg.ProductGroup_ID
	 LEFT JOIN ClaimGroupType cgt
		ON cpb.ClaimGroupTypeId = cgt.ClaimGroupTypeId
	 LEFT JOIN #TmpPersonUser dmpu --2025-08-20 16:26 06588 Krekpon.D Mind 
		ON cpb.CreatedByUserId = dmpu.UserId
	 LEFT JOIN #TmpEmployee dme --2025-08-20 16:26 06588 Krekpon.D Mind 
		ON dmpu.EmployeeId = dme.EmployeeId
   
 WHERE  cpbt.ClaimPayBackTransferStatusId = 3   --เอาที่จ่ายแล้ว
		AND cpbt.ClaimGroupTypeId = @ClaimGroupTypeId
		AND cpbt.IsActive = 1
		AND cpbd.IsActive = 1
		AND ((cpbt.TransferDate >= @DateFrom) AND (cpbt.TransferDate < DATEADD(Day,1,@DateTo)))
		AND (cpbd.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL)
		AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)


SELECT 			icu.InsuranceCompany_Name AS InsuranceCompany_Name,
				dab.BranchDetail AS Branch,
				IIF(@ClaimGroupTypeId = 4,ssicu.Detail,NULL) AS Hospital,
				tmpCpbd.ProductGroupDetailName AS ProductGroupDetailName,
				tmpCpbd.ClaimGroupType AS ClaimGroupType,
				tmpCpbd.ClaimGroupCodeFromCPBD AS ClaimGroupCode,
				tmpCpbd.ItemCount AS ItemCount,
				tmpCpbd.Amount AS Amount,
				NULL AS ClaimCompensate,
				--IIF(@ClaimGroupTypeId IN (2,4,6) AND @ProductGroupId IN (2,3),icu.ClaimCode,NULL) AS ClaimNo, -- Krekpon.D 2025-08-15
				icu.ClaimCode ClaimNo,
				--NULL AS ClaimNo,
				IIF(@ClaimGroupTypeId IN (2,6) , tmpCpbd.COL,NULL) AS COL,
				IIF(@ClaimGroupTypeId = 4,sssmp.Detail,NULL) AS Province,
				IIF(@ClaimGroupTypeId IN (2,4,6) ,icu.CustomerName,NULL) AS CustomerName, -- Krekpon.D 2025-08-15  --Krekpon D. 2025-08-18 remove where product
				--NULL AS CustomerName,
				IIF(@ClaimGroupTypeId IN (2,4,6),sssmtb.Detail,NULL) As BankName, -- Krekpon.D 2025-08-15
				IIF(@ClaimGroupTypeId IN (2,4,6),ssicu.BankAccountName,NULL) AS BankAccountName, -- Krekpon.D 2025-08-15
				IIF(@ClaimGroupTypeId IN (2,4,6),REPLACE(ssicu.BankAccountNo,'-',''),NULL) AS BankAccountNo, -- Krekpon.D 2025-08-15
				NULL AS PhoneNo,
				tmpCpbd.CreatedDate AS SendDate,
				tmpCpbd.TransferDate AS CreatedDate,
				CONCAT(dmeu.EmployeeCode,' ',dmeu.PersonName) AS ApprovedUser ,
				tmpCpbd.CreatedByUser AS CteatedUser , --2025-08-20 16:26 06588 Krekpon.D Mind 
				icu.ClaimAdmitType AS ClaimAdmitType


FROM	@TmpClaimPayBack tmpCpbd
	 LEFT JOIN(
								SELECT chg.Code AS Code
									, chg.InsuranceCompany_Name AS InsuranceCompany_Name
									, cat.Detail AS ClaimAdmitType
									, chg.Hospital_id AS Hospital
									, chg.CreatedBy_id AS ApprovedUserFromSSS
									-- Krekpon.D 2025-08-15
									, ch.Code AS ClaimCode 
									, CONCAT(tt.Detail,ct.FirstName,' ',ct.LastName) AS CustomerName

								FROM sss.dbo.DB_ClaimHeaderGroup chg
								LEFT JOIN SSS.dbo.MT_ClaimAdmitType cat
									ON chg.ClaimAdmitType_id = cat.Code
								-- Krekpon.D 2025-08-15
								LEFT JOIN SSS.dbo.DB_ClaimHeader ch
									ON ch.ClaimHeaderGroup_id = chg.Code
								LEFT JOIN SSS.dbo.DB_Customer ct
									ON ct.App_id = ch.App_id
								LEFT JOIN SSS.dbo.MT_Title tt
									ON tt.Code = ct.Title_id

								UNION ALL

								SELECT DISTINCT pachg.Code AS Code
									, pachg.InsuranceCompany_Name AS InsuranceCompany_Name
									, smc.Detail AS ClaimAdmitType
									, ch.Hospital_id AS Hospital
									, pachg.CreatedBy_id AS ApprovedUserFromSSS
									 -- Krekpon.D 2025-08-15
									, ch.Code AS ClaimCode
									, CONCAT(tt.Detail,cd.FirstName,' ',cd.LastName) AS CustomerName

								FROM SSSPA.dbo.DB_ClaimHeaderGroup pachg
								LEFT JOIN SSSPA.dbo.SM_Code smc
									ON pachg.ClaimTypeGroup_id = smc.Code
								-- Krekpon.D 2025-08-15
								LEFT JOIN SSSPA.dbo.DB_ClaimHeader ch
									ON ch.ClaimheaderGroup_id = pachg.Code
								LEFT JOIN SSSPA.dbo.DB_CustomerDetail cd
									ON cd.Code = ch.CustomerDetail_id
								LEFT JOIN SSSPA.dbo.MT_Title tt
									ON tt.Code = cd.Title_id
								
				) icu
		ON tmpCpbd.ClaimGroupCodeFromCPBD = icu.Code
	LEFT JOIN SSS.dbo.MT_Company ssicu
		ON icu.Hospital = ssicu.Code
	LEFT JOIN [DataCenterV1].[Address].Branch dab
		ON tmpCpbd.BranchId = dab.Branch_ID
	LEFT JOIN #TmpEmployee dmeu
		ON icu.ApprovedUserFromSSS  = dmeu.EmployeeCode
	LEFT JOIN SSS.dbo.MT_Bank sssmtb
		ON ssicu.Bank_id = sssmtb.Code
	LEFT JOIN SSS.dbo.DB_Address sssadr
		ON ssicu.Address_id = sssadr.Code
	LEFT JOIN SSS.dbo.SM_Province sssmp
		ON sssadr.Province_id = sssmp.Code

IF OBJECT_ID('tempdb..#TmpPersonUser') IS NOT NULL DROP TABLE #TmpPersonUser; --2025-08-20 16:26 06588 Krekpon.D Mind 
IF OBJECT_ID('tempdb..#TmpEmployee') IS NOT NULL DROP TABLE #TmpEmployee; --2025-08-20 16:26 06588 Krekpon.D Mind 
IF OBJECT_ID('tempdb..@TmpClaimPayBack') IS NOT NULL  DELETE FROM @TmpClaimPayBack; -- ปรับ Code ใหม่ให้ทำงานได้เร็วขึ้น 2024-07-01


--	SELECT		icu.InsuranceCompany_Name AS InsuranceCompany_Name,
--				dab.BranchDetail AS Branch,
--				IIF(@ClaimGroupTypeId = 4,ssicu.Detail,NULL) AS Hospital,
--				dppg.ProductGroupDetail AS ProductGroupDetailName,
--				cgt.ClaimGroupType AS ClaimGroupType,
--				cpbd.ClaimGroupCode AS ClaimGroupCode,
--				cpbd.ItemCount AS ItemCount,
--				cpbd.Amount AS Amount,
--				NULL AS ClaimCompensate,
--				NULL AS ClaimNo,
--				IIF(@ClaimGroupTypeId = 2 , cpbd.ClaimOnLineCode,NULL) AS COL,
--				IIF(@ClaimGroupTypeId = 4,sssmp.Detail,NULL) AS Province,
--				NULL AS CustomerName,
--				IIF(@ClaimGroupTypeId = 4,sssmtb.Detail,NULL) As BankName,
--				IIF(@ClaimGroupTypeId = 4,ssicu.BankAccountName,NULL) AS BankAccountName,
--				IIF(@ClaimGroupTypeId = 4,REPLACE(ssicu.BankAccountNo,'-',''),NULL) AS BankAccountNo,
--				NULL AS PhoneNo,
--				cpb.CreatedDate AS SendDate,
--				cpbt.TransferDate AS CreatedDate,
--				CONCAT(dmeu.EmployeeCode,' ',dmeu.PersonName) AS ApprovedUser ,
--				CONCAT(dme.EmployeeCode,' ',dme.PersonName) AS CteatedUser ,
--				icu.ClaimAdmitType AS ClaimAdmitType


--FROM ClaimPayBackTransfer cpbt 
--	 INNER JOIN ClaimPayBack cpb
--		ON cpb.ClaimPayBackTransferId = cpbt.ClaimPayBackTransferId
--	 INNER JOIN ClaimPayBackDetail cpbd
--		ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
--	 LEFT JOIN [DataCenterV1].[Product].ProductGroup dppg
--		ON cpbd.ProductGroupId = dppg.ProductGroup_ID
--	 LEFT JOIN ClaimGroupType cgt
--		ON cpb.ClaimGroupTypeId = cgt.ClaimGroupTypeId
--	 LEFT JOIN(
--								SELECT chg.Code AS Code
--									, chg.InsuranceCompany_Name AS InsuranceCompany_Name
--									, cat.Detail AS ClaimAdmitType
--									, chg.Hospital_id AS Hospital
--									, chg.CreatedBy_id AS ApprovedUserFromSSS

--								FROM sss.dbo.DB_ClaimHeaderGroup chg
--								LEFT JOIN SSS.dbo.MT_ClaimAdmitType cat
--									ON chg.ClaimAdmitType_id = cat.Code
								
								
--								UNION ALL

--								SELECT DISTINCT pachg.Code AS Code
--									, pachg.InsuranceCompany_Name AS InsuranceCompany_Name
--									, smc.Detail AS ClaimAdmitType
--									, pachg.Hospital_id AS Hospital
--									, pachg.CreatedBy_id AS ApprovedUserFromSSS

--								FROM SSSPA.dbo.DB_ClaimHeaderGroup pachg
--								LEFT JOIN SSSPA.dbo.SM_Code smc
--									ON pachg.ClaimTypeGroup_id = smc.Code
								
--				) icu
--		ON cpbd.ClaimGroupCode = icu.Code
--	LEFT JOIN SSS.dbo.MT_Company ssicu
--		ON icu.Hospital = ssicu.Code
--	LEFT JOIN [DataCenterV1].[Address].Branch dab
--		ON cpb.BranchId = dab.Branch_ID
--	LEFT JOIN [DataCenterV1].[Master].vw_PersonUser dmpu
--		ON cpb.CreatedByUserId = dmpu.UserId
--	INNER JOIN [DataCenterV1].[Master].vw_Employee dme
--		ON dmpu.EmployeeId = dme.EmployeeId
--	INNER JOIN [DataCenterV1].[Master].vw_Employee dmeu
--		ON icu.ApprovedUserFromSSS  = dmeu.EmployeeCode
--	LEFT JOIN SSS.dbo.MT_Bank sssmtb
--		ON ssicu.Bank_id = sssmtb.Code
--	LEFT JOIN SSS.dbo.DB_Address sssadr
--		ON ssicu.Address_id = sssadr.Code
--	LEFT JOIN SSS.dbo.SM_Province sssmp
--		ON sssadr.Province_id = sssmp.Code

--WHERE	cpbt.ClaimPayBackTransferStatusId = 3   --เอาที่จ่ายแล้ว
--		AND cpbt.ClaimGroupTypeId = @ClaimGroupTypeId
--		AND cpbt.IsActive = 1 
--		AND ((cpbt.TransferDate >= @DateFrom) AND (cpbt.TransferDate < DATEADD(Day,1,@DateTo)))
--		AND (cpbd.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL)
--		AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)
--END
