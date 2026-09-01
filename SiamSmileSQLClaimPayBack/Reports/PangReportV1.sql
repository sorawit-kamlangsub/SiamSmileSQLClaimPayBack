USE [ClaimPayBack]
GO



SELECT 

cpbd.ClaimGroupCode
,cpbxc.ClaimCode
,icu.CustomerName

FROM ClaimPayBackDetail cpbd
LEFT JOIN ClaimPayBackXClaim cpbxc
	ON cpbxc.ClaimPayBackDetailId = cpbd.ClaimPayBackDetailId
	 LEFT JOIN(

			-- SSS
			SELECT chg.Code										Code
				,ch.Code										ClaimCode
				,CONCAT(tt.Detail,ct.FirstName,' ',ct.LastName) CustomerName
			FROM sss.dbo.DB_ClaimHeaderGroup chg
			LEFT JOIN SSS.dbo.MT_ClaimAdmitType cat
				ON chg.ClaimAdmitType_id = cat.Code
			LEFT JOIN SSS.dbo.DB_ClaimHeader ch
				ON ch.ClaimHeaderGroup_id = chg.Code
			LEFT JOIN SSS.dbo.DB_Customer ct
				ON ct.App_id = ch.App_id
			LEFT JOIN SSS.dbo.MT_Title tt
				ON tt.Code = ct.Title_id
			
			
			UNION ALL
			
			-- SSSPA
			SELECT DISTINCT pachg.Code							Code
				,ch.Code										ClaimCode
				,CONCAT(tt.Detail,cd.FirstName,' ',cd.LastName) CustomerName
			FROM SSSPA.dbo.DB_ClaimHeaderGroup pachg
			LEFT JOIN SSSPA.dbo.SM_Code smc
				ON pachg.ClaimTypeGroup_id = smc.Code
			LEFT JOIN SSSPA.dbo.DB_ClaimHeader ch
				ON ch.ClaimheaderGroup_id = pachg.Code
			LEFT JOIN SSSPA.dbo.DB_CustomerDetail cd
				ON cd.Code = ch.CustomerDetail_id
			LEFT JOIN SSSPA.dbo.MT_Title tt
				ON tt.Code = cd.Title_id

		) icu
	ON icu.ClaimCode = cpbxc.ClaimCode

WHERE cpbd.ClaimGroupCode IN 
(
('BUHH-888-68060965-0'),
('BUPH-888-68120046-0')
)
