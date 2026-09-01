USE [ClaimPayBack]
GO

SELECT
*
FROM
(
	SELECT
	cpbd.InsuranceCompanyId
	,td.ClaimHeaderCodeInDB
	,cpbd.ClaimGroupCode
	,cpbd.Amount
	   , COUNT(td.ClaimHeaderCodeInDB) OVER
		(
			PARTITION BY cpbd.ClaimGroupCode
		) AS ColCount
	,cpbd.CreatedDate
	FROM dbo.ClaimPayBackDetail cpbd 
	LEFT JOIN 
	(
				SELECT hg.Code								AS ClaimHeaderGroupCodeInDB
						,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
						,h.PaySS_Total							AS TotalAmountSS
						,ins.Organize_ID						AS InsuranceCompanyId
						,h.Code									AS ClaimHeaderCodeInDB
						,'2000'									AS ProductGroup
						,ctp.Detail								AS PolicyNo
						,hg.CreatedDate
				FROM SSSPA.dbo.DB_ClaimHeaderGroup AS hg
					LEFT JOIN SSSPA.dbo.DB_ClaimHeader h
						ON hg.Code = h.ClaimheaderGroup_id
					LEFT JOIN DataCenterV1.Organize.Organize AS ins
						ON hg.InsuranceCompany_id = ins.OrganizeCode
					LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
						ON h.CustomerDetail_id = ctd.Code
					LEFT JOIN SSSPA.dbo.DB_Customer AS cus
						ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090' 
					LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
						ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601' 
	) td
	ON cpbd.ClaimGroupCode = td.ClaimHeaderGroupCodeInDB
	WHERE cpbd.IsActive = 1
	AND cpbd.ProductGroupId = 3
	AND cpbd.InsuranceCompanyId = 18
	AND NOT EXISTS
	(
	 SELECT 1
	 FROM dbo.ClaimHeaderGroupImport ci
	 WHERE ci.IsActive = 1
	 AND ci.ClaimHeaderGroupImportStatusId = 3
	 AND ci.ClaimHeaderGroupCode = cpbd.ClaimGroupCode
	)
) rs
WHERE rs.ColCount = 1
Order By rs.CreatedDate ASC