	SELECT 
		pu.User_ID
		,e.EmployeeCode
		,CONCAT(e.EmployeeCode,' ',pT.TitleDetail,p.FirstName,' ',p.LastName) PersonName
	INTO #TmpPersonUser
	FROM DataCenterV1.Person.PersonUser pu
	LEFT JOIN  DataCenterV1.Person.Person p 
		ON pu.Person_ID = p.Person_ID
			AND p.IsActive = 1
	LEFT JOIN DataCenterV1.Employee.Employee e
		ON pu.Employee_ID = e.Employee_ID
			AND e.IsActive = 1
	LEFT JOIN DataCenterV1.Person.Title pT 
		ON p.Title_ID = pT.Title_ID
	WHERE pu.IsActive = 1

	CREATE INDEX IX_TmpPersonUser_User_ID ON #TmpPersonUser(User_ID);
	CREATE INDEX IX_TmpPersonUser_Code ON #TmpPersonUser(EmployeeCode);

SELECT
*
FROM 
(

			-- SSS
			SELECT chg.Code											Code
				, chg.InsuranceCompany_Name							InsuranceCompany_Name
				, cat.Detail										ClaimAdmitType
				, chg.Hospital_id									Hospital
				, chg.CreatedBy_id									ApprovedUserFromSSS
				, ch.Code											ClaimCode 
				, CONCAT(tt.Detail,ct.FirstName,' ',ct.LastName)	CustomerName
				,NULL												BankAccountName
				,NULL												BankAccountNo
				,NULL												BankName
				,NULL												PhoneNo
				,NULL												ProductTypeName
				,NULL												ProductTypeId
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
				,pachg.InsuranceCompany_Name					InsuranceCompany_Name
				,smc.Detail										ClaimAdmitType
				,ch.Hospital_id									Hospital
				,pachg.CreatedBy_id								ApprovedUserFromSSS
				,ch.Code										ClaimCode
				,CONCAT(tt.Detail,cd.FirstName,' ',cd.LastName)	CustomerName
				,NULL											BankAccountName
				,NULL											BankAccountNo
				,NULL											BankName
				,NULL											PhoneNo
				,NULL											ProductTypeName
				,NULL											ProductTypeId
			FROM SSSPA.dbo.DB_ClaimHeaderGroup pachg
			LEFT JOIN SSSPA.dbo.SM_Code smc
				ON pachg.ClaimTypeGroup_id = smc.Code
			LEFT JOIN SSSPA.dbo.DB_ClaimHeader ch
				ON ch.ClaimheaderGroup_id = pachg.Code
			LEFT JOIN SSSPA.dbo.DB_CustomerDetail cd
				ON cd.Code = ch.CustomerDetail_id
			LEFT JOIN SSSPA.dbo.MT_Title tt
				ON tt.Code = cd.Title_id
			
			UNION ALL
			
			-- ClaimMisc
			SELECT 
				ClaimHeaderGroupCode		Code
				,InsuranceCompanyName		InsuranceCompany_Name
				,cxa.ClaimAdmitType			ClaimAdmitType
				,h.HospitalCode				Hospital
				,u.EmployeeCode				ApprovedUserFromSSS
				,cm.ClaimMiscNo				ClaimCode
				,cm.CustomerName			CustomerName
				,miscacc.BankAccountName	BankAccountName
				,miscacc.BankAccountNo		BankAccountNo
				,miscacc.BankName			BankName
				,ce.ContactPersonPhoneNo	PhoneNo
				,pd.ProductTypeName
				,pd.ProductTypeId
			FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			LEFT JOIN [ClaimMiscellaneous].[misc].[Hospital] h
				ON h.HospitalId = cm.HospitalId 
			LEFT JOIN #TmpPersonUser u
				ON u.[User_ID] = cm.CreatedByUserId
			LEFT JOIN
			(
				SELECT
					 x.ClaimMiscId
					 ,STUFF((
					         SELECT ',' + a.ClaimAdmitTypeName
					         FROM [ClaimMiscellaneous].[misc].[ClaimMiscXClaimAdmitType] x2
								JOIN [ClaimMiscellaneous].[misc].[ClaimAdmitType] a
					                 ON a.ClaimAdmitTypeId = x2.ClaimAdmitTypeId
					         WHERE x2.IsActive = 1
								AND a.IsActive  = 1
								AND x2.ClaimMiscId = x.ClaimMiscId
					         FOR XML PATH(''), TYPE
					 ).value('.', 'nvarchar(255)'), 1, 1, '')        ClaimAdmitType
				FROM [ClaimMiscellaneous].[misc].[ClaimMiscXClaimAdmitType] x
				WHERE x.IsActive = 1
				GROUP BY x.ClaimMiscId
			) cxa
				ON cxa.ClaimMiscId = cm.ClaimMiscId
			LEFT JOIN(
				SELECT 
					ch.ClaimMiscId
					,cp.BankAccountName
					,cp.BankAccountNo
					,cp.BankName
				FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] ch
					LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] cp
						ON ch.ClaimMiscPaymentHeaderId = cp.ClaimMiscPaymentHeaderId
				WHERE ch.IsActive = 1
					AND cp.IsActive = 1
				GROUP BY ch.ClaimMiscId, cp.BankAccountName, cp.BankAccountNo, cp.BankName
			)miscacc
				ON cm.ClaimMiscId = miscacc.ClaimMiscId
			LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimEvent] ce
				ON cm.ClaimEventId = ce.ClaimEventId
			LEFT JOIN 
			(
				SELECT 
					ProductTypeId
					,ProductTypeName
				FROM [ClaimMiscellaneous].[misc].[ProductType] 
				WHERE IsActive = 1
			) pd
				ON pd.ProductTypeId = cm.ProductTypeId
	) icu
	WHERE icu.ClaimCode = 'CLCM69010003'

	IF OBJECT_ID('tempdb..#TmpPersonUser') IS NOT NULL DROP TABLE #TmpPersonUser;