USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_GetClaimHeaderGroupImportDetailById_Select]    Script Date: 21/1/2569 12:05:09 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

-- =============================================
-- Author:		Nattavut Jaikaew
-- Create date: 20221215 1225
-- Update date: 2022-12-22 App Field URLOpenClaimLink , App Field URLOpenApplicationLink
-- Update date: Kittisak.Ph 20230703
-- Update date: 2023-09-21 chanadol add column IsManualNPL
-- Description:	
-- =============================================
--ALTER PROCEDURE [dbo].[usp_GetClaimHeaderGroupImportDetailById_Select]
DECLARE
		@ClaimHeaderGroupImportDetailId INT = 2822;

--AS
--BEGIN
--	-- SET NOCOUNT ON added to prevent extra result sets from
--	-- interfering with SELECT statements.
--	SET NOCOUNT ON;


DECLARE @pId INT = @ClaimHeaderGroupImportDetailId

DECLARE @UrlPH NVARCHAR(255) = 'http://uat.siamsmile.co.th:9101/' --prod --https://sssph.siamsmile.co.th/
DECLARE @UrlPA NVARCHAR(255) = 'http://uat.siamsmile.co.th:9102/' --prod --https://ssspa.siamsmile.co.th/
DECLARE @UrlClaimMisc NVARCHAR(255) = 'https://uatclaimmisc.siamsmile.co.th/' --prod https://claimmisc.siamsmile.co.th/

DECLARE @URLLinkClaimPH NVARCHAR(MAX)		= CONCAT(@UrlPH,'Modules/Claim/frmClaimApproveOverview.aspx?clm=')
DECLARE @URLLinkApplicationPH NVARCHAR(MAX) = CONCAT(@UrlPH,'Modules/PH/frmPHDetail.aspx?app=')

DECLARE @URLLinkClaimPA NVARCHAR(MAX)		= CONCAT(@UrlPA,'Modules/Claim/frmClaimPA_New.aspx?clm=')
DECLARE @URLLinkApplicationPA NVARCHAR(MAX) = CONCAT(@UrlPA,'Modules/PA/frmApplicationDetail.aspx?app=')

DECLARE @URLLinkApplicationClaimMisc NVARCHAR(MAX) = CONCAT(@UrlClaimMisc,'claimdetailhomeandhouse?id=')

SELECT d.ClaimHeaderGroupImportDetailId
      ,d.ClaimHeaderGroupImportId
      ,d.ClaimCode
      ,d.ClaimHeaderGroupCode
      ,d.Province
      ,d.IdentityCard
      ,d.CustName
      ,d.DateHappen
      ,CASE WHEN f.ClaimHeaderGroupTypeId = 6 THEN h.TotalAmount ELSE d.Pay END AS Pay
      ,d.HospitalId
      ,d.HospitalName
      ,d.DateIn
      ,d.DateOut
      ,d.ApplicationCode
      ,d.ProductId
      ,d.Product
      ,d.DateNotice
      ,d.StartCoverDate
      ,d.ClaimAdmitTypeCode
      ,d.ClaimAdmitType
      ,d.ClaimType
      ,d.ICD10_1Code
      ,d.ICD10
      ,d.IPDCount
      ,d.ICUCount
      ,d.Net
      ,d.Compensate_Include
      ,d.Pay_Total
      ,d.DiscountSS
      ,d.PaySS_Total
      ,d.PolicyNo
      ,d.SchoolName
      ,d.CustomerDetailCode
      ,d.SchoolLevel
      ,d.Accident
      ,d.ChiefComplain
      ,d.Orgen
      ,d.Amount_Compensate_in
      ,d.Amount_Compensate_out
      ,d.Amount_Pay
      ,d.Amount_Dead
      ,d.Remark

	  ,CASE WHEN ccnpl.ClaimHeaderGroupImportDetailId IS NULL THEN ISNULL(cc.CoverAmount,0) ELSE 0 END AS CoverAmount
	  ,CASE WHEN ccnpl.ClaimHeaderGroupImportDetailId IS NOT NULL THEN ISNULL(cc.CoverAmount,0) ELSE 0 END AS AmountNPL
	  ,h.InsuranceCompanyId			InsuranceCompanyId
	  --,ins.OrganizeDetail			InsuranceCompanyName	--Kittisak.Ph 20230703
	  ,i.InsuranceCompany_Name InsuranceCompanyName		--Kittisak.Ph 20230703

	  ,CASE--Folk add 2022-12-23 --Sun add ClaimHeaderGroupTypeId 4,5 2023-01-04
		WHEN f.ClaimHeaderGroupTypeId IN (2,4,5) THEN CONCAT(@URLLinkClaimPH,dbo.uFnStringToBase64 (d.ClaimCode))
		WHEN f.ClaimHeaderGroupTypeId = 3 THEN CONCAT(@URLLinkClaimPA,dbo.uFnStringToBase64 (d.ClaimCode))
		WHEN f.ClaimHeaderGroupTypeId = 6 THEN CONCAT(@URLLinkApplicationClaimMisc,cm.ClaimMiscId)
		ELSE ''
		END AS URLOpenClaimLink

	  ,CASE--Folk add 2022-12-23
		WHEN f.ClaimHeaderGroupTypeId IN (2) THEN CONCAT(@URLLinkApplicationPH,dbo.uFnStringToBase64 (d.ClaimCode))
		WHEN f.ClaimHeaderGroupTypeId = 3 THEN CONCAT(@URLLinkApplicationPA,dbo.uFnStringToBase64 (d.ClaimCode))
		WHEN f.ClaimHeaderGroupTypeId = 6 THEN CONCAT(@URLLinkApplicationClaimMisc,cm.ClaimMiscId)
		ELSE ''
	   END AS URLOpenApplicationLink
	  ,ccnpl.ClaimHeaderGroupImportDetailId		IsManualNPL  --update 2023-09-21 chanadol

FROM dbo.ClaimHeaderGroupImportDetail d
	LEFT JOIN 
		(
			SELECT a.ClaimHeaderGroupImportDetailId
					,a.CoverAmount
			FROM dbo.BillingRequestResultDetail a
				INNER JOIN dbo.BillingRequestResultHeader b
					ON a.BillingRequestResultHeaderId = b.BillingRequestResultHeaderId
			WHERE a.IsActive = 1
			AND b.IsActive = 1
			AND b.IsManual = 1		--Manual only
		)cc
		ON d.ClaimHeaderGroupImportDetailId = cc.ClaimHeaderGroupImportDetailId
	LEFT JOIN 
		(
			SELECT a.ClaimHeaderGroupImportDetailId
			FROM dbo.BillingRequestResultDetail a
				INNER JOIN dbo.BillingRequestResultHeader b
					ON a.BillingRequestResultHeaderId = b.BillingRequestResultHeaderId
			WHERE a.IsActive = 1
			AND b.IsActive = 1
			AND b.IsManual = 1		
			AND b.IsManualNPL = 1 --Amount NPL only
		)ccnpl
		ON d.ClaimHeaderGroupImportDetailId = ccnpl.ClaimHeaderGroupImportDetailId		--update 2023-09-21 chanadol
	LEFT JOIN dbo.ClaimHeaderGroupImport h
		ON d.ClaimHeaderGroupImportId = h.ClaimHeaderGroupImportId
	--LEFT JOIN 
	--	(
	--		SELECT * 
	--		FROM DataCenterV1.Organize.Organize
	--		WHERE OrganizeType_ID = 2
	--	)ins
	--	ON h.InsuranceCompanyId = ins.Organize_ID

	LEFT JOIN -- 20230703 07242
		(
			SELECT Code
				, InsuranceCompany_Name
			FROM sss.dbo.DB_ClaimHeaderGroup
			UNION
			SELECT Code
				, InsuranceCompany_Name
			FROM SSSPA.dbo.DB_ClaimHeaderGroup
		) i
	ON d.ClaimHeaderGroupCode = i.Code
	----------------------------------------------------------------Folk 2022-12-23
	LEFT JOIN dbo.ClaimHeaderGroupImport g
		ON d.ClaimHeaderGroupImportId = g.ClaimHeaderGroupImportId
	LEFT JOIN dbo.ClaimHeaderGroupImportFile f
		ON g.ClaimGroupImportFileId = f.ClaimHeaderGroupImportFileId
	LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm
		ON cm.ClaimHeaderGroupCode = h.ClaimHeaderGroupCode
	-----------------------------------------------------------------
WHERE d.ClaimHeaderGroupImportDetailId = @pId

--END
