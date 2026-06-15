--SELECT 
-- hg.*
--FROM
--(
--SELECT  
--		hg.Code								AS ClaimHeaderGroupCodeInDB
--		,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
--		,h.PaySS_Total							AS TotalAmountSS
--		,ins.Organize_ID						AS InsuranceCompanyId
--		,h.Code									AS ClaimHeaderCodeInDB
--		,'2000'									AS ProductGroup
--		,ctp.Detail								AS PolicyNo
--FROM SSSPA.dbo.DB_ClaimHeaderGroup AS hg
--	INNER JOIN SSSPA.dbo.DB_ClaimHeader h
--		ON hg.Code = h.ClaimheaderGroup_id
--	LEFT JOIN DataCenterV1.Organize.Organize AS ins
--		ON hg.InsuranceCompany_id = ins.OrganizeCode
--	LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
--		ON h.CustomerDetail_id = ctd.Code
--	LEFT JOIN SSSPA.dbo.DB_Customer AS cus
--		ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090'
--	LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
--		ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601'
--	WHERE ins.Organize_ID = '1120992'

--) rs
--INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg 
--	ON hg.Code = rs.ClaimHeaderGroupCodeInDB
--INNER JOIN SSSPA.dbo.DB_ClaimHeader h
--	ON h.ClaimheaderGroup_id = hg.Code
--WHERE hg.Code = 'AGAO-181-69060001-0'

--SELECT 
-- h.*
--FROM
--(
--SELECT  
--		hg.Code								AS ClaimHeaderGroupCodeInDB
--		,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
--		,h.PaySS_Total							AS TotalAmountSS
--		,ins.Organize_ID						AS InsuranceCompanyId
--		,h.Code									AS ClaimHeaderCodeInDB
--		,'2000'									AS ProductGroup
--		,ctp.Detail								AS PolicyNo
--FROM SSSPA.dbo.DB_ClaimHeaderGroup AS hg
--	INNER JOIN SSSPA.dbo.DB_ClaimHeader h
--		ON hg.Code = h.ClaimheaderGroup_id
--	LEFT JOIN DataCenterV1.Organize.Organize AS ins
--		ON hg.InsuranceCompany_id = ins.OrganizeCode
--	LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
--		ON h.CustomerDetail_id = ctd.Code
--	LEFT JOIN SSSPA.dbo.DB_Customer AS cus
--		ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090'
--	LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
--		ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601'
--	WHERE ins.Organize_ID = '1120992'

--) rs
--INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg 
--	ON hg.Code = rs.ClaimHeaderGroupCodeInDB
--INNER JOIN SSSPA.dbo.DB_ClaimHeader h
--	ON h.ClaimheaderGroup_id = hg.Code
--WHERE hg.Code = 'AGAO-181-69060001-0'

SELECT 
 ctd.*
FROM
(
SELECT  
		hg.Code								AS ClaimHeaderGroupCodeInDB
		,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
		,h.PaySS_Total							AS TotalAmountSS
		,ins.Organize_ID						AS InsuranceCompanyId
		,h.Code									AS ClaimHeaderCodeInDB
		,'2000'									AS ProductGroup
		,ctp.Detail								AS PolicyNo
FROM SSSPA.dbo.DB_ClaimHeaderGroup AS hg
	INNER JOIN SSSPA.dbo.DB_ClaimHeader h
		ON hg.Code = h.ClaimheaderGroup_id
	LEFT JOIN DataCenterV1.Organize.Organize AS ins
		ON hg.InsuranceCompany_id = ins.OrganizeCode
	LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
		ON h.CustomerDetail_id = ctd.Code
	LEFT JOIN SSSPA.dbo.DB_Customer AS cus
		ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090'
	LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
		ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601'
	WHERE ins.Organize_ID = '1120992'

) rs
INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg 
	ON hg.Code = rs.ClaimHeaderGroupCodeInDB
INNER JOIN SSSPA.dbo.DB_ClaimHeader h
	ON h.ClaimheaderGroup_id = hg.Code
LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
		ON h.CustomerDetail_id = ctd.Code
LEFT JOIN SSSPA.dbo.DB_Customer AS cus
		ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090'
LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
		ON cus.App_id  = ctp.App_id 
WHERE hg.Code = 'AGAO-181-69060001-0'

SELECT 
 cus.*
FROM
(
SELECT  
		hg.Code								AS ClaimHeaderGroupCodeInDB
		,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
		,h.PaySS_Total							AS TotalAmountSS
		,ins.Organize_ID						AS InsuranceCompanyId
		,h.Code									AS ClaimHeaderCodeInDB
		,'2000'									AS ProductGroup
		,ctp.Detail								AS PolicyNo
FROM SSSPA.dbo.DB_ClaimHeaderGroup AS hg
	INNER JOIN SSSPA.dbo.DB_ClaimHeader h
		ON hg.Code = h.ClaimheaderGroup_id
	LEFT JOIN DataCenterV1.Organize.Organize AS ins
		ON hg.InsuranceCompany_id = ins.OrganizeCode
	LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
		ON h.CustomerDetail_id = ctd.Code
	LEFT JOIN SSSPA.dbo.DB_Customer AS cus
		ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090'
	LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
		ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601'
	WHERE ins.Organize_ID = '1120992'

) rs
INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg 
	ON hg.Code = rs.ClaimHeaderGroupCodeInDB
INNER JOIN SSSPA.dbo.DB_ClaimHeader h
	ON h.ClaimheaderGroup_id = hg.Code
LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
		ON h.CustomerDetail_id = ctd.Code
LEFT JOIN SSSPA.dbo.DB_Customer AS cus
		ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090'
LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
		ON cus.App_id  = ctp.App_id 
WHERE hg.Code = 'AGAO-181-69060001-0'

SELECT 
 ctp.*
FROM
(
SELECT  
		hg.Code								AS ClaimHeaderGroupCodeInDB
		,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
		,h.PaySS_Total							AS TotalAmountSS
		,ins.Organize_ID						AS InsuranceCompanyId
		,h.Code									AS ClaimHeaderCodeInDB
		,'2000'									AS ProductGroup
		,ctp.Detail								AS PolicyNo
FROM SSSPA.dbo.DB_ClaimHeaderGroup AS hg
	INNER JOIN SSSPA.dbo.DB_ClaimHeader h
		ON hg.Code = h.ClaimheaderGroup_id
	LEFT JOIN DataCenterV1.Organize.Organize AS ins
		ON hg.InsuranceCompany_id = ins.OrganizeCode
	LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
		ON h.CustomerDetail_id = ctd.Code
	LEFT JOIN SSSPA.dbo.DB_Customer AS cus
		ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090'
	LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
		ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601'
	WHERE ins.Organize_ID = '1120992'

) rs
INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg 
	ON hg.Code = rs.ClaimHeaderGroupCodeInDB
INNER JOIN SSSPA.dbo.DB_ClaimHeader h
	ON h.ClaimheaderGroup_id = hg.Code
LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
		ON h.CustomerDetail_id = ctd.Code
LEFT JOIN SSSPA.dbo.DB_Customer AS cus
		ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090'
LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
		ON cus.App_id  = ctp.App_id 
WHERE hg.Code = 'AGAO-181-69060001-0'
