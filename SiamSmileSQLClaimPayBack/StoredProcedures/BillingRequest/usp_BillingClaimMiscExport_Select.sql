USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingClaimMiscExport_Select]    Script Date: 3/11/2568 18:19:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Sorawit KamlangSub
-- Create date: 2025-10-31 16:30
-- Description:	For Export Claimmisc Billing
-- =============================================
ALTER PROCEDURE [dbo].[usp_BillingClaimMiscExport_Select]
	 @ClaimCode VARCHAR(20)
AS
BEGIN
	SET NOCOUNT ON;

--DECLARE @ClaimCode VARCHAR(20) = 'CLMI68100000158'
DECLARE @BillingRequestGroupCode INT = 6

SELECT 
	be.ClaimHeaderGroupCode	
	,be.PolicyNo	
	,be.[Product]	
	,be.ClaimCode
	,NULL				BranchName
	,be.SchoolName	
	,be.CustName	
	,be.DateHappen
	,be.HospitalName
	,be.DateIn
	,be.DateOut
	,be.ChiefComplain
	,be.Accident
	,NULL				Injury
	,NULL				Organs
	,be.Remark
	,NULL				CompensationIPD
	,NULL				CompensationOPD
	,NULL				ExpenseIPD
	,NULL				ExpenseOPD
	,NULL				Dead
	,NULL				Expense
	,NULL				ClaimPayBackAmount
	,NULL				UnCoverAmount
	,NULL				TotalPay
	,NULL				PayRemark
	,NULL				ContinueClaim
	,NULL				DocumentLink
	,doc.DocumentId
	,doc.DocumentCode
FROM BillingExport be
LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm
	ON cm.ClaimHeaderGroupCode = be.ClaimHeaderGroupCode
LEFT JOIN 
	(
		SELECT	
			ClaimMiscId
			,DocumentId
			,DocumentCode
		FROM [ClaimMiscellaneous].[misc].[Document]
		WHERE IsActive = 1
	) doc
	ON doc.ClaimMiscId = cm.ClaimMiscId
WHERE be.ClaimCode = @ClaimCode
AND be.ClaimHeaderGroupTypeId = @BillingRequestGroupCode

END;