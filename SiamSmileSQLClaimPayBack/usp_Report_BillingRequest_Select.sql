USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_Report_BillingRequest_Select]    Script Date: 16/10/2568 10:27:01 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chanadol Kookam
-- Create date: 2023-02-06 
-- Update date: 2023-07-03
--				2023-09-25 add column ManualNPLAmount, NPLOldAmount, AutoTotalAmount and ClaimCode
--				2024-02-01 add Chanadol Kookam
--				2025-09-05 Clean Code Krekpon.D
-- Update date: 2025-09-29 10:16 Bunchuai Chaiket
--				เพิ่ม SELECT ClaimHeaderGroupImportStatusName
-- Update date: 2025-10-16 19:24
--				SELEC DateHappen, DateIn
-- Description:	Report BillingRequestResult ClaimHeaderGroupImportStatusName และเพิ่ม parameter @ClaimHeaderGroupImportStatusId
-- =============================================
ALTER PROCEDURE [dbo].[usp_Report_BillingRequest_Select]
	-- Add the parameters for the stored procedure here
	@SearchTypeId							INT 
	,@DateFrom								DATE 
	,@DateTo								DATE 
	,@InsuranceId							INT = NULL
	,@ClaimHeaderGroupImportStatusId		INT = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
------------------------------------------------------
--DECLARE @SearchTypeId						INT		= 1;
--DECLARE @DateFrom							DATE	= '2025-09-01';
--DECLARE @DateTo								DATE	= '2025-10-16';
--DECLARE @InsuranceId						INT		= NULL;
--DECLARE @ClaimHeaderGroupImportStatusId		INT		= 2;

IF @DateTo IS NOT NULL SET @DateTo = DATEADD(DAY,1,@DateTo);
-------------------------------------------------------

--SearchType 1 วันที่นำเข้า ,2 วันที่วางบิล

SELECT hi.CreatedDate
      ,hi.BillingDate
	  ,hi.InsuranceCompanyName				InsuranceCompany
	  ,cgt.ClaimHeaderGroupTypeName  
	  ,hi.ClaimHeaderGroupCode
	  ,d.ClaimCode
	  ,hi.ItemCount
	  ,ISNULL(npl.CoverAmount,0)			ManualNPLAmount
	  ,ISNULL(nplo.CoverAmount,0)			NPLTotalAmount
	  ,ISNULL(ba.CoverAmount,0)				AutoTotalAmount
	  ,d.PaySS_Total
	  ,(ISNULL(ba.CoverAmount,0) - d.PaySS_Total) - ISNULL(nplo.CoverAmount,0) TotalAmount
	  ,ct.Detail
	  ,cgs.ClaimHeaderGroupImportStatusName
	  ,d.DateHappen
	  ,d.DateIn
FROM dbo.ClaimHeaderGroupImport hi
	LEFT JOIN dbo.ClaimHeaderGroupImportDetail d
		ON hi.ClaimHeaderGroupImportId = d.ClaimHeaderGroupImportId
	LEFT JOIN 
	(
		SELECT d.ClaimHeaderGroupImportDetailId
					,rd.CoverAmount 
				FROM dbo.ClaimHeaderGroupImportDetail d
					LEFT JOIN dbo.BillingRequestResultDetail rd
						ON d.ClaimHeaderGroupImportDetailId = rd.ClaimHeaderGroupImportDetailId
					LEFT JOIN dbo.BillingRequestResultHeader rh
						ON rd.BillingRequestResultHeaderId = rh.BillingRequestResultHeaderId
				WHERE d.IsActive = 1
				AND rd.IsActive = 1
				AND rh.IsManualNPL = 1
	)npl
		ON d.ClaimHeaderGroupImportDetailId = npl.ClaimHeaderGroupImportDetailId
	LEFT JOIN 
			(
				SELECT d.ClaimHeaderGroupImportDetailId
					,SUM(rd.CoverAmount) CoverAmount
				FROM dbo.ClaimHeaderGroupImportDetail d
					LEFT JOIN dbo.BillingRequestResultDetail rd
						ON d.ClaimCode = rd.ClaimCode
					LEFT JOIN dbo.BillingRequestResultHeader rh
						ON rd.BillingRequestResultHeaderId = rh.BillingRequestResultHeaderId
				WHERE rh.IsManualNPL = 1
				GROUP BY d.ClaimHeaderGroupImportDetailId
			)nplo
			ON d.ClaimHeaderGroupImportDetailId = nplo.ClaimHeaderGroupImportDetailId
	LEFT JOIN 
			(
				SELECT d.ClaimHeaderGroupImportDetailId
					,d.ClaimCode
					,SUM(rd.CoverAmount) CoverAmount
					,baf.ClaimHeaderGroupTypeId
				FROM dbo.ClaimHeaderGroupImportDetail d
					LEFT JOIN dbo.ClaimHeaderGroupImport bai
						ON d.ClaimHeaderGroupImportId = bai.ClaimHeaderGroupImportId
					LEFT JOIN  dbo.ClaimHeaderGroupImportFile baf
						ON bai.ClaimGroupImportFileId = baf.ClaimHeaderGroupImportFileId
					LEFT JOIN 
						(
							SELECT cs.ClaimCompensateCode
								,cs.ClaimHeaderCode
							FROM SSS.dbo.ClaimCompensate cs
							WHERE cs.IsActive = 1	
						)cs
						ON d.ClaimCode = cs.ClaimHeaderCode
					LEFT JOIN dbo.BillingRequestResultDetail rd
						ON d.ClaimCode = rd.ClaimCode
					LEFT JOIN dbo.BillingRequestResultHeader rh
						ON rd.BillingRequestResultHeaderId = rh.BillingRequestResultHeaderId
				WHERE d.IsActive = 1 
				AND cs.ClaimCompensateCode IS NULL
				AND rd.IsActive = 1
				AND rh.IsManualNPL = 0

				GROUP BY d.ClaimHeaderGroupImportDetailId, baf.ClaimHeaderGroupTypeId, d.ClaimCode
			)ba
			ON d.ClaimHeaderGroupImportDetailId = ba.ClaimHeaderGroupImportDetailId
	LEFT JOIN sss.dbo.MT_ClaimType ct
		ON hi.ClaimTypeCode = ct.Code
	LEFT JOIN ClaimHeaderGroupImportFile cf
		ON hi.ClaimGroupImportFileId = cf.ClaimHeaderGroupImportFileId
	LEFT JOIN ClaimHeaderGroupType cgt
		ON cf.ClaimHeaderGroupTypeId = cgt.ClaimHeaderGroupTypeId
	LEFT JOIN ClaimHeaderGroupImportStatus cgs
		ON hi.ClaimHeaderGroupImportStatusId = cgs.ClaimHeaderGroupImportStatusId

WHERE ((@SearchTypeId = 1 AND (hi.CreatedDate >= @DateFrom AND hi.CreatedDate < @DateTo))
	  OR (@SearchTypeId = 2 AND (hi.BillingDate >= @DateFrom AND hi.BillingDate < @DateTo)))
AND (hi.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)
AND (
	(@ClaimHeaderGroupImportStatusId IS NULL AND hi.ClaimHeaderGroupImportStatusId IN (2,4))
    OR (@ClaimHeaderGroupImportStatusId IS NOT NULL AND hi.ClaimHeaderGroupImportStatusId = @ClaimHeaderGroupImportStatusId)
)
AND hi.IsActive = 1

END;