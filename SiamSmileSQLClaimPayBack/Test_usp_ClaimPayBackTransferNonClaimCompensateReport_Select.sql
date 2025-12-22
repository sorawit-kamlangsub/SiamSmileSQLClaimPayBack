USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackTransferNonClaimCompensateReport_Select]    Script Date: 14/10/2568 16:42:27 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO


-- =============================================
-- Author:		06588 Krekpon Dokkamklang Mind
-- Create date: 2024-06-21
-- Description:	????????????????????
-- Update date: 2024-07-01 06588 Krekpon.D Mind 
-- Description:	??????????????????????? ????????????????
-- Update date: 2025-08-15 06588 Krekpon.D Mind 
-- Description:	????????????????? ClaimGroupTypeId =  6
-- Update date: 2025-08-18 06588 Krekpon.D Mind 
-- Description:	remove where product
-- Update date: 2025-08-20 16:26 06588 Krekpon.D Mind 
-- Description:	??????? join ??????
-- Update date: 2025-10-29 14:31 Sorawit Kamlangsub
-- Update date: 2025-12-09 10.20 Mr.Bunchuai Chaiket (08498)
-- Description:	????????????? (SELECT ???????????) ??????? ClaimMisc
-- Description:	Add UNION ClaimMisc
-- =============================================
--ALTER PROCEDURE [dbo].[usp_ClaimPayBackTransferNonClaimCompensateReport_Select]
DECLARE
	-- Add the parameters for the stored procedure here
	 @DateFrom			DATE = '2025-12-19'
	,@DateTo			DATE = '2025-12-22'
	,@InsuranceId		INT = NULL
	,@ProductGroupId	INT = NULL
	,@ClaimGroupTypeId	INT = 7
--AS
--BEGIN

--	SET NOCOUNT ON;
    -- Insert statements for procedure here

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

--?????? Table ????????????? ClaimPayBack
DECLARE @TmpClaimPayBack TABLE (
	 ClaimGroupCodeFromCPBD		NVARCHAR(150),
	 ClaimGroupType				NVARCHAR(100),
	 ItemCount					INT,
     Amount						DECIMAL(16,2),
	 ProductGroupDetailName		NVARCHAR(20),
	 BranchId					INT,
     SendDate					DATETIME,
     TransferDate				DATETIME,
	 COL						NVARCHAR(150),
	 CreatedDate				DATETIME,
	 CreatedByUser				NVARCHAR(150)
     )
 -- ????????????? temp ?????? JOIN ?????????? Base ????
 INSERT INTO @TmpClaimPayBack(
      ClaimGroupCodeFromCPBD,
	  ClaimGroupType,
	  ItemCount,
      Amount,
	  ProductGroupDetailName,
	  BranchId,
      SendDate,
      TransferDate,
	  COL,
	  CreatedDate,
	  CreatedByUser
      )
 SELECT   
     cpbd.ClaimGroupCode		ClaimGroupCode
	 ,cgt.ClaimGroupType		ClaimGroupType
	 ,cpbd.ItemCount			ItemCount
     ,cpbd.Amount				Amount
	 ,dppg.ProductGroupDetail	ProductGroupDetailName
	 ,cpb.BranchId				BranchId
     ,cpb.CreatedDate			SendDate
     ,cpbt.TransferDate			CreatedDate
	 ,cpbd.ClaimOnLineCode		COL
	 ,cpb.CreatedDate			CreatedDate
	 ,pu.PersonName				CreatedByUser
 
 FROM ClaimPayBackTransfer cpbt 
	 INNER JOIN ClaimPayBack cpb
		ON cpbt.ClaimPayBackTransferId = cpb.ClaimPayBackTransferId
	 INNER JOIN ClaimPayBackDetail cpbd
		ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
	 LEFT JOIN [DataCenterV1].[Product].ProductGroup dppg
		ON cpbd.ProductGroupId = dppg.ProductGroup_ID
	 LEFT JOIN ClaimGroupType cgt
		ON cpb.ClaimGroupTypeId = cgt.ClaimGroupTypeId
	 INNER JOIN #TmpPersonUser pu
		ON pu.[User_ID] = cpb.CreatedByUserId
   
 WHERE  cpbt.ClaimPayBackTransferStatusId = 3
		AND cpbt.ClaimGroupTypeId = @ClaimGroupTypeId
		AND cpbt.IsActive = 1
		AND cpbd.IsActive = 1
		AND ((cpbt.TransferDate >= @DateFrom) AND (cpbt.TransferDate < DATEADD(Day,1,@DateTo)))
		AND (cpbd.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL)
		AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)


SELECT 			icu.InsuranceCompany_Name														InsuranceCompany_Name
				,dab.BranchDetail																Branch
				,IIF(@ClaimGroupTypeId IN (4,7),ssicu.Detail,NULL)								Hospital
				,CASE 
					WHEN @ClaimGroupTypeId IN (2,4,6) THEN tmpCpbd.ProductGroupDetailName
					WHEN @ClaimGroupTypeId = 7		  THEN icu.ProductTypeName
					ELSE NULL
				END																				ProductGroupDetailName				
				,tmpCpbd.ClaimGroupType															ClaimGroupType
				,tmpCpbd.ClaimGroupCodeFromCPBD													ClaimGroupCode
				,tmpCpbd.ItemCount																ItemCount
				,tmpCpbd.Amount																	Amount
				,NULL																			ClaimCompensate
				,icu.ClaimCode																	ClaimNo
				,IIF(@ClaimGroupTypeId IN (2,6,7) , tmpCpbd.COL, NULL)							COL
				,IIF(@ClaimGroupTypeId IN (4,7),sssmp.Detail, NULL)								Province
				,IIF(@ClaimGroupTypeId IN (2,4,6,7) ,icu.CustomerName, NULL)					CustomerName
				,CASE 
					WHEN @ClaimGroupTypeId IN (2,4,6) THEN sssmtb.Detail
					WHEN @ClaimGroupTypeId = 7		  THEN icu.BankName
					ELSE NULL
				END													BankName
				,CASE 
					WHEN @ClaimGroupTypeId IN (2,4,6)	THEN ssicu.BankAccountName
					WHEN @ClaimGroupTypeId  = 7			THEN icu.BankAccountName
					ELSE NULL
				END													BankAccountName
				,CASE 
					WHEN @ClaimGroupTypeId IN (2,4,6)	THEN REPLACE(ssicu.BankAccountNo,'-','')
					WHEN @ClaimGroupTypeId  = 7			THEN icu.BankAccountNo
					ELSE NULL
				END													BankAccountNo
				,CASE 
					WHEN @ClaimGroupTypeId IN (2,4,6)	THEN NULL
					WHEN @ClaimGroupTypeId  = 7			THEN icu.PhoneNo
					ELSE NULL
				END													PhoneNo
				,tmpCpbd.CreatedDate								SendDate
				,tmpCpbd.TransferDate								CreatedDate
				,dmeu.PersonName									ApprovedUser
				,tmpCpbd.CreatedByUser								CteatedUser
				,icu.ClaimAdmitType									ClaimAdmitType


FROM	@TmpClaimPayBack tmpCpbd
	 LEFT JOIN(

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
		ON tmpCpbd.ClaimGroupCodeFromCPBD = icu.Code
	LEFT JOIN SSS.dbo.MT_Company ssicu
		ON icu.Hospital = ssicu.Code
	LEFT JOIN [DataCenterV1].[Address].Branch dab
		ON tmpCpbd.BranchId = dab.Branch_ID
	INNER JOIN #TmpPersonUser dmeu
		ON icu.ApprovedUserFromSSS  = dmeu.EmployeeCode
	LEFT JOIN SSS.dbo.MT_Bank sssmtb
		ON ssicu.Bank_id = sssmtb.Code
	LEFT JOIN SSS.dbo.DB_Address sssadr
		ON ssicu.Address_id = sssadr.Code
	LEFT JOIN SSS.dbo.SM_Province sssmp
		ON sssadr.Province_id = sssmp.Code

IF OBJECT_ID('tempdb..#TmpPersonUser') IS NOT NULL DROP TABLE #TmpPersonUser;
IF OBJECT_ID('tempdb..@TmpClaimPayBack') IS NOT NULL  DELETE FROM @TmpClaimPayBack;

--END
