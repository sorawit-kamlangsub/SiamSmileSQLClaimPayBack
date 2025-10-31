USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [Claim].[usp_BillingClaimMiscExport_Select]    Script Date: 31/10/2568 16:31:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Sorawit KamlangSub
-- Create date: 2025-10-31 16:30
-- Description:	For Export Claimmisc Billing
-- =============================================
ALTER PROCEDURE [Claim].[usp_BillingClaimMiscExport_Select]
	 @ClaimCode VARCHAR(20)
	 ,@BillingRequestGroupCode INT
AS
BEGIN
	SET NOCOUNT ON;

--DECLARE @ClaimCode VARCHAR(20) = 'CLMI68100000117'
--DECLARE @BillingRequestGroupCode INT = 6

SELECT 
	be.ClaimHeaderGroupCode	
	,be.PolicyNo	
	,be.[Product]	
	,be.ClaimCode
	,NULL	BranchName
	,be.SchoolName	
	,be.CustName	
	,be.DateHappen
	,be.HospitalName
	,be.DateIn
	,be.DateOut
	,be.ChiefComplain
	,be.Accident
	,NULL	Injury
	,NULL	Organs
	,be.Remark
	,NULL	CompensationIPD
	,NULL	CompensationOPD
	,NULL	ExpenseIPD
	,NULL	ExpenseOPD
	,NULL	Dead
	,NULL	Expense
	,NULL	ClaimPayBackAmount
	,NULL	UnCoverAmount
	,NULL	TotalPay
	,NULL	PayRemark
	,NULL	ContinueClaim
	,NULL	DocumentLink
FROM BillingExport be
WHERE be.ClaimCode = @ClaimCode
AND be.ClaimHeaderGroupTypeId = @BillingRequestGroupCode

END;