USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackTrasferReport_Select]    Script Date: 3/9/2026 10:43:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		06588 Krekpon Dokkamklang Mind
-- Create date: 2024-06-21
-- Description: รายงานหลังส่งการเงินของประเภทเคลมโอนแยก
-- Update date: 2026-03-09 Sorawit.k
-- Description:	เพิ่ม ClaimPaymentTypeName,ClaimPaymentTypeDetail
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackTrasferReport_Select]
	-- Add the parameters for the stored procedure here
	 @DateFrom			DATE 
	,@DateTo			DATE 
	,@InsuranceId		INT = NULL
	,@ProductGroupId	INT = NULL
	,@ClaimGroupTypeId	INT = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SELECT		icu.InsuranceCompany_Name AS InsuranceCompany_Name,
				dab.BranchDetail AS Branch,
				icu.Hospital AS Hospital,
				dppg.ProductGroupDetail AS ProductGroupDetailName,
				cgt.ClaimGroupType AS ClaimGroupType,
				cpbd.ClaimGroupCode AS ClaimGroupCode,
				cpbd.ItemCount AS ItemCount,
				cpbd.Amount AS Amount,
				icu.ClaimCompensateCode AS ClaimCompensate,
				icu.ClaimHeaderCode AS ClaimNo,
				NULL AS COL,
				icu.Province AS Province,
				icu.CustomerName AS CustomerName,
				icu.BankName As BankName,
				icu.BankAccountName AS BankAccountName,
				icu.BankAccountNo AS BankAccountNo,
				icu.PhoneNo AS PhoneNo,
				cpb.CreatedDate AS SendDate,
				cpbt.TransferDate AS CreatedDate,
				CONCAT(dmeu.EmployeeCode,' ',dmeu.PersonName) AS ApprovedUser ,
				CONCAT(dme.EmployeeCode,' ',dme.PersonName) AS CteatedUser ,
				icu.ClaimAdmitType AS ClaimAdmitType
				,NULL AS ClaimPaymentTypeName
				,NULL AS ClaimPaymentTypeDetail

FROM ClaimPayBackTransfer cpbt 
	 INNER JOIN ClaimPayBack cpb
		ON cpb.ClaimPayBackTransferId = cpbt.ClaimPayBackTransferId
	 INNER JOIN ClaimPayBackDetail cpbd
		ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
	 LEFT JOIN [DataCenterV1].[Product].ProductGroup dppg
		ON cpbd.ProductGroupId = dppg.ProductGroup_ID
	 LEFT JOIN ClaimGroupType cgt
		ON cpb.ClaimGroupTypeId = cgt.ClaimGroupTypeId
		 LEFT JOIN(
									SELECT ccg.ClaimCompensateGroupCode AS Code
										, ccg.InsuranceCompany_Name AS InsuranceCompany_Name
										, cat.Detail AS ClaimAdmitType
										, sscmtb.Detail AS BankName --UpdateDate 2024-07-16 Add BankTransfer
										, scc.BankAccountNameTransfer AS BankAccountName --UpdateDate 2024-07-16 Add BankTransfer
										, scc.BankAccountNoTransfer AS BankAccountNo --UpdateDate 2024-07-16 Add BankTransfer
										, IIF(scc.HospitalCode IS NOT NULL,ssmtc.Detail,NULL) AS Hospital
										, ssmp.Detail AS Province
										, scc.ClaimCompensateCode AS ClaimCompensateCode
										, scc.ClaimHeaderCode AS ClaimHeaderCode
										, CONCAT(mtt.Detail,'', cust.FirstName,' ',cust.LastName) AS CustomerName
										, scc.PhoneNo AS PhoneNo
										, ccg.CreatedByCode AS ApproveUserBySSS
									FROM sss.dbo.ClaimCompensateGroup ccg
									INNER JOIN SSS.dbo.ClaimCompensate scc
										ON ccg.ClaimCompensateGroupId = scc.ClaimCompensateGroupId
									INNER JOIN SSS.dbo.DB_ClaimHeader sch
										ON scc.ClaimHeaderCode = sch.Code
									INNER JOIN SSS.dbo.DB_Customer cust
										ON sch.App_id = cust.App_id
									INNER JOIN SSS.dbo.MT_Title mtt
										ON cust.Title_id = mtt.Code
									LEFT JOIN SSS.dbo.MT_ClaimAdmitType cat
										ON scc.ClaimAdmitTypeCode = cat.Code
									LEFT JOIN SSS.dbo.MT_Company ssmtc
										ON scc.HospitalCode = ssmtc.Code
									LEFT JOIN SSS.dbo.MT_Bank ssmtb
										ON ssmtc.Bank_id = ssmtb.Code
									LEFT JOIN SSS.dbo.DB_Address ssadr
										ON ssmtc.Address_id = ssadr.Code
									LEFT JOIN SSS.dbo.SM_Province ssmp
										ON ssadr.Province_id = ssmp.Code
									LEFT JOIN SSS.dbo.MT_Bank sscmtb
										ON scc.BankCodeTransfer = sscmtb.Code --UpdateDate 2024-07-16 Add BankTransfer
									WHERE ccg.IsActive = 1
								
					) icu
		ON cpbd.ClaimGroupCode = icu.Code
	LEFT JOIN [DataCenterV1].[Address].Branch dab
		ON cpb.BranchId = dab.Branch_ID
	LEFT JOIN [DataCenterV1].[Master].vw_PersonUser dmpu
		ON cpb.CreatedByUserId = dmpu.UserId
	INNER JOIN [DataCenterV1].[Master].vw_Employee dme  --
		ON dmpu.EmployeeId = dme.EmployeeId
	INNER JOIN [DataCenterV1].[Master].vw_Employee dmeu  --
		ON icu.ApproveUserBySSS = dmeu.EmployeeCode
WHERE	cpbt.ClaimPayBackTransferStatusId = 3   --เอาที่จ่ายแล้ว
	AND cpbt.ClaimGroupTypeId = @ClaimGroupTypeId
	AND cpbt.IsActive = 1 
	AND cpbd.IsActive = 1 
	AND ((cpbt.TransferDate >= @DateFrom) AND (cpbt.TransferDate < DATEADD(Day,1,@DateTo)))
	AND (cpbd.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL)
	AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)

END
