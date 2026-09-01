USE [ClaimPayBack]
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Mr.Bunchuai Chaiket (08498)
-- Create date: 2026/07/10 10:54:34
-- Description:	รายงานเคลมก่อนอนุมัติกรมธรรม์ PA
-- =============================================
CREATE PROCEDURE [dbo].[usp_Report_PAClaimBeforePolicyApproval_Select]
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- ========================================== 
	DECLARE @SMIImsurance VARCHAR(20) = '100000000041';
	DECLARE @D DATETIME = GETDATE();
	-- ==========================================


	SELECT  
	cd.Application_id							ApplicationId
	,CONCAT(mtc.CompanyTitle ,'',mtc.Detail)	SchoolName
	,db.BranchDetail							Brance
	,pss.Detail									PolicyStatus
	,org.OrganizeDetail							InsuranceName
	,ch.Code			
	,ch.ClaimOnLineCode
	,CONCAT(mt.Detail,' ',cd.FirstName,' ', cd.LastName)							CustomerBenefitName
	,cgb.Code																		ClaimHeaderGroupCode
	,IIF(ch.PaySS_Total IS NULL, ocol.TransferAmountTotal, ch.PaySS_Total)			ClaimAmount				-- ไม่มั่นใจเรื่อง Field
	,ctt.CreatedDate																ApprovedPolicyDate
	,ch.CreatedDate																	ClaimCreatedDate  
	,IIF(colPH.PaymentDate IS NULL,ocol.TransferDateLatest, colPH.PaymentDate)		ClaimPaytransferDate	-- ไม่มั่นใจเรื่อง Field
	,cd.StartCoverDate
	,vwcust.PaymentStatus
	
FROM [SSSPA].[dbo].DB_ClaimHeader ch
	INNER JOIN [SSSPA].[dbo].DB_ClaimHeaderGroupItem gi
		ON ch.Code = gi.ClaimHeader_id
	LEFT JOIN [SSSPA].[dbo].DB_ClaimHeaderGroup cgb
		ON gi.ClaimHeaderGroup_id = cgb.Code
	LEFT JOIN [DataCenterV1].[Address].[Branch] db
		ON cgb.Branch_id = db.tempcode
	LEFT JOIN [DataCenterV1].[Organize].[Organize] org
		ON ch.InsuranceCompany_id = org.OrganizeCode
	LEFT JOIN [SSSPA].[dbo].DB_CustomerDetail cd
		ON ch.CustomerDetail_id = cd.Code
	LEFT JOIN [SSSPA].[dbo].DB_Customer ctm
		ON cd.Application_id = ctm.App_id
	LEFT JOIN [SSSPA].[dbo].SM_Status	ss
		ON ch.Status_id = ss.Code 
	LEFT JOIN [SSSPA].[dbo].MT_Title mt 
		ON cd.Title_id = mt.Code
	LEFT JOIN (
		SELECT 
			Code
			,CompanyTitle
			,Detail
		FROM [SSSPA].[dbo].MT_Company
		WHERE CompanyGroup_id = '8000'
	)
	mtc
		ON ctm.School_id = mtc.Code
	LEFT JOIN [SSSPA].[dbo].SM_Status	pss
		ON ctm.Status_id = pss.Code 
	LEFT JOIN
		(
			SELECT
				co.ClaimOnLineCode
				,co.ClaimOnLineId
				,cpt.PaymentDate
				,SUM(cg.TotalAmount)	TotalAmount 
			FROM [ClaimOnlineV2].[dbo].[ClaimOnline] co
				LEFT JOIN ClaimOnlineV2.dbo.ClaimPayGroup cg
					ON cg.ClaimOnLineId = co.ClaimOnLineId
				LEFT JOIN [ClaimOnlineV2].[dbo].[ClaimPayTransaction] cpt 
					ON cg.ClaimPayGroupId = cpt.ClaimPayGroupId
			WHERE co.IsActive = 1  
				AND cg.IsActive = 1 
				AND cpt.IsActive = 1
				AND cg.PaymentStatusId = 4
			GROUP BY  co.ClaimOnLineCode, co.ClaimOnLineId ,cpt.PaymentDate
		) colPH
		ON ch.ClaimOnLineCode = colPH.ClaimOnLineCode
	LEFT JOIN  (
		SELECT 
			a.Application_id
			,t.Detail
			,a.CreatedDate 
			,a.TransactionType_id
		FROM [SSSPA].[dbo].TR_CustomerTransaction a
			LEFT JOIN [SSSPA].[dbo].SM_TransactionType t 
				ON a.TransactionType_id = t.Code
		WHERE a.TransactionType_id = '6540'
	)  ctt
		ON cd.Application_id = ctt.Application_id
	LEFT JOIN (
		SELECT 
			ClaimOnLineCode
			,TransferDateLatest
			,TransferAmountTotal
		FROM [ClaimOnLine].[dbo].[ClaimOnLine]
		WHERE IsActive = 1
	) ocol
		ON ch.ClaimOnLineCode = ocol.ClaimOnLineCode
	 LEFT JOIN [SSSPA].[dbo].vw_Customer vwcust
		ON vwcust.App_id = cd.Application_id
		 
	WHERE ch.InsuranceCompany_id <> @SMIImsurance			-- ไม่เอา SMI
		AND db.IsActive = 1
		AND ctm.IsActive = 1
		AND cd.IsActive = 1 
		AND ctm.[Year] IN(2568,2569)						-- ปีกรมธรรม์
		AND ch.IsClaimOnLine = 1							-- เอาแค่รายการที่เป็น ClaimOnline 
		AND (
			(ctt.CreatedDate > ch.CreatedDate)
			OR
			(ctt.CreatedDate IS NULL) 
		) 
END;
GO

