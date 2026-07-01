	SELECT
		td.ClaimHeaderGroupCodeInDB
		,1 ItemCode
		,IIF(ISNULL(td.TotalAmount,0) = 0 ,td.TotalAmountSS,td.TotalAmount)	Amount
		,ISNULL(td.TotalAmount,0)	TotalAmount
		,ISNULL(td.TotalAmountSS,0)	TotalAmountSS
		,td.InsuranceCompanyId
		,td.ClaimHeaderCodeInDB
		,td.ProductGroup
		,td.PolicyNo
		,td.CreatedDate
	FROM
		(	--SSS------
			SELECT h.ClaimHeaderGroup_id					AS ClaimHeaderGroupCodeInDB
					,CAST(v.Pay_Total AS DECIMAL(16,2))		AS TotalAmount
					,v.PaySS_Total							AS TotalAmountSS
					,ins.Organize_ID						AS InsuranceCompanyId
					,h.Code									AS ClaimHeaderCodeInDB
					,IIF(h.Product_id = 'P30',h.Product_id,'1000') AS ProductGroup
					,cus.InsuredPolicy_no					AS PolicyNo
					,h.CreatedDate
			FROM SSS.dbo.DB_ClaimHeader h
				LEFT JOIN SSS.dbo.DB_ClaimVoucher v
					ON h.Code = v.Code
				LEFT JOIN DataCenterV1.Organize.Organize ins
					ON h.InsuranceCompany_id = ins.OrganizeCode
				LEFT JOIN sss.dbo.MT_ClaimType ct
					ON h.ClaimAdmitType_id = ct.Code
				LEFT JOIN sss.dbo.DB_Customer  cus
					ON h.App_id = cus.App_id

			UNION
			--SSSPA------
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

			UNION

			--ClaimCompensate------
			SELECT cg.ClaimCompensateGroupCode				AS ClaimHeaderGroupCodeInDB
				,cc.CompensateRemain						AS TotalAmount
				,cc.CompensateRemain						AS TotalAmountSS
				,ins.Organize_ID							AS InsuranceCompanyId
				,cc.ClaimCompensateCode						AS ClaimHeaderCodeInDB
				,'2222'										AS ProductGroup
				,cus.InsuredPolicy_no						AS PolicyNo
				,cg.CreatedDate
			FROM SSS.dbo.ClaimCompensateGroup cg
				LEFT JOIN
					(
						SELECT 
							CompensateRemain
							,ClaimCompensateCode
							,ClaimCompensateGroupId
						FROM SSS.dbo.ClaimCompensate
						WHERE IsActive = 1
					)cc
					ON cg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
				LEFT JOIN DataCenterV1.Organize.Organize AS ins
					ON cg.InsuranceCompanyCode = ins.OrganizeCode
				LEFT JOIN SSS.dbo.DB_ClaimHeader h
					ON cg.ClaimCompensateGroupCode = h.ClaimHeaderGroup_id
				LEFT JOIN sss.dbo.DB_Customer  cus
					ON h.App_id = cus.App_id

	) td	

	WHERE td.ClaimHeaderGroupCodeInDB IN
	(
		'SBAD-888-69060001-0'
	)