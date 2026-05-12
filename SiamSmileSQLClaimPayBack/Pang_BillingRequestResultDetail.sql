DECLARE 
	@SearchTypeId							INT 
	,@DateFrom								DATE 
	,@DateTo								DATE 
	,@InsuranceId							INT = NULL
	,@ClaimHeaderGroupImportStatusId		INT = NULL


SELECT hi.CreatedDate
	 ,d.ClaimHeaderGroupImportDetailId
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
	  ,CASE 
			WHEN cgt.ClaimHeaderGroupTypeId <> 6 THEN (d.PaySS_Total - ISNULL(ba.CoverAmount,0)) - ISNULL(npl.CoverAmount,0)
			WHEN cgt.ClaimHeaderGroupTypeId = 6 THEN (hi.TotalAmount - (ISNULL(ISNULL(npl.CoverAmount,0) + ISNULL(ba.CoverAmount,0),0)))
		ELSE 0 END TotalAmount
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
				AND d.IsActive = 1
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
					LEFT JOIN dbo.BillingRequestResultDetail rd
						ON d.ClaimHeaderGroupImportDetailId = rd.ClaimHeaderGroupImportDetailId
					LEFT JOIN dbo.BillingRequestResultHeader rh
						ON rd.BillingRequestResultHeaderId = rh.BillingRequestResultHeaderId
				WHERE d.IsActive = 1 
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

WHERE 
1=1
--AND
--((@SearchTypeId = 1 AND (hi.CreatedDate >= @DateFrom AND hi.CreatedDate < @DateTo))
--	  OR (@SearchTypeId = 2 AND (hi.BillingDate >= @DateFrom AND hi.BillingDate < @DateTo)))
--AND (hi.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)
--AND (
--	(@ClaimHeaderGroupImportStatusId IS NULL AND hi.ClaimHeaderGroupImportStatusId IN (2,4))
--    OR (@ClaimHeaderGroupImportStatusId IS NOT NULL AND hi.ClaimHeaderGroupImportStatusId = @ClaimHeaderGroupImportStatusId)
--)
AND hi.IsActive = 1
AND hi.ClaimHeaderGroupCode IN ('PCHO-551-69010106-0','PCHO-551-69010106-1')

--SELECT * 
--FROM dbo.BillingRequestResultDetail
--WHERE ClaimHeaderGroupImportDetailId IN (565195,858529)

SELECT * 
FROM dbo.TmpClaimHeaderGroupImport
WHERE ClaimHeaderGroupCode IN ('PCHO-551-69010106-0','PCHO-551-69010106-1')

SELECT ci.BillingDate,cid.* 
FROM dbo.ClaimHeaderGroupImportDetail cid
INNER JOIN ClaimHeaderGroupImport ci
	ON ci.ClaimHeaderGroupImportId = cid.ClaimHeaderGroupImportId
WHERE cid.ClaimHeaderGroupCode IN ('PCHO-551-69010106-0','PCHO-551-69010106-1')

SELECT *
FROM EventLogging.SmileSClaimPayBackLogs
WHERE [Message] LIKE '%IMCHG6905000112%'