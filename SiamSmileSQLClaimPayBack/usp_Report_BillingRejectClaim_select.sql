USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_Report_BillingRejectClaim_select]    Script Date: 16/7/2569 14:54:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chanadol Koonkam
-- Create date: 2023-07-13
-- Description:	BillingRejectClaim Report
-- =============================================
ALTER PROCEDURE [dbo].[usp_Report_BillingRejectClaim_select] 
	-- Add the parameters for the stored procedure here
	@DecisionStatusId		INT = NULL
	,@DateFrom				DATE 
	,@DateTo				DATE 
	,@InsuranceId			INT = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	IF @DateTo IS NOT NULL SET @DateTo = DATEADD(DAY,1,@DateTo);

    SELECT bg.BillingDate
	,bg.BillingRequestGroupCode		AS BillingRequestGroup
	,cgt.ClaimHeaderGroupTypeName	AS ClaimAdmit_Type
	,bg.InsuranceCompanyName		AS InsuranceCompany
	,b.Detail						AS Branch
	,gd.ClaimHeaderGroupCode		AS ClaimHeaderGroup_id
	,gd.ClaimCode					AS Code
	,gd.CustName					AS Customer_Name
	,bi.AmountTotal					AS Pay_Total
	,rd.UncoverAmount				
	,rd.UnCoverRemark
	,ds.DecisionStatusName			AS DecisionStatus
	,rd.DecisionDate
	,rd.RejectResult
	,ct.Detail						AS ClaimType
	FROM dbo.BillingRequestResultDetail rd
		LEFT JOIN dbo.BillingRequestItem bi
			ON rd.BillingRequestItemCode = bi.BillingRequestItemCode
		LEFT JOIN dbo.BillingRequestGroup bg
			ON bi.BillingRequestGroupId = bg.BillingRequestGroupId
		LEFT JOIN dbo.ClaimHeaderGroupImportDetail gd
			ON bi.ClaimHeaderGroupImportDetailId = gd.ClaimHeaderGroupImportDetailId
		LEFT JOIN SSS.dbo.MT_ClaimType ct
			ON bg.ClaimTypeCode = ct.Code
		LEFT JOIN dbo.ClaimHeaderGroupType cgt
			ON cgt.ClaimHeaderGroupTypeId = bg.ClaimHeaderGroupTypeId
		LEFT JOIN
				(
						SELECT Code 
							,CreatedBy_id
						FROM SSS.dbo.DB_ClaimHeader
					UNION
						SELECT Code 
							,CreatedBy_id
						FROM SSSPA.dbo.DB_ClaimHeader
				) d
			ON gd.ClaimCode = d.Code
		LEFT JOIN SSS.dbo.DB_Employee emp
			ON d.CreatedBy_id = emp.Code
		LEFT JOIN SSS.dbo.DB_Team t
			ON emp.Team_id = t.Code
		LEFT JOIN SSS.dbo.MT_Branch b
			ON t.Branch_id = b.Code
		LEFT JOIN dbo.DecisionStatus ds
			ON rd.DecisionStatusId = ds.DecisionStatusId
	WHERE rd.BillingRequestItemCode IS NOT NULL
		AND rd.DecisionStatusId IN(3,4)
		AND	(bg.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)
		AND (rd.DecisionStatusId = @DecisionStatusId OR @DecisionStatusId IS NULL)
		AND (rd.CreatedDate >= @DateFrom AND rd.CreatedDate < @DateTo)

END
