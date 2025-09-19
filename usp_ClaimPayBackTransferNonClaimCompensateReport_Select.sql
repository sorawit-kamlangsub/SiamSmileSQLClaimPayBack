USE [ClaimPayBack]
GO

DECLARE @DateFrom	DATE = '2025-08-01';
DECLARE @DateTo		DATE = DATEADD(DAY ,1,GETDATE());
DECLARE @InsuranceId	INT;
DECLARE @ProductGroupId	INT;
DECLARE @ClaimGroupTypeId	INT;

DECLARE @xText	NVARCHAR(10) =NULL;

/*Setup Data*/
	SELECT
		cpbd.ClaimGroupCode
		,cgt.ClaimGroupType
		,cpbd.ItemCount
		,cpbd.Amount
		,dab.BranchDetail								Branch
		,cpbt.TransferDate
		,cpbd.ClaimOnLineCode
		,cpb.CreatedDate
		,CONCAT(dme.EmployeeCode,' ',dme.PersonName)	CteatedUser
		,dppg.ProductGroupDetail
	INTO #Tmp
	FROM ClaimPayBackTransfer cpbt 
		INNER JOIN ClaimPayBack cpb
			ON cpbt.ClaimPayBackTransferId = cpb.ClaimPayBackTransferId
		INNER JOIN ClaimPayBackDetail cpbd
			ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
	/*Master */
		LEFT JOIN ClaimGroupType cgt
			ON cpb.ClaimGroupTypeId = cgt.ClaimGroupTypeId
		LEFT JOIN [DataCenterV1].[Master].[vw_PersonUser] dmpu
			ON cpb.CreatedByUserId = dmpu.UserId
		LEFT JOIN [DataCenterV1].[Master].[vw_Employee] dme
			ON dmpu.EmployeeId = dme.EmployeeId
		LEFT JOIN [DataCenterV1].[Address].[Branch] dab
			ON cpb.BranchId = dab.Branch_ID
		LEFT JOIN [DataCenterV1].[Product].ProductGroup dppg
			ON cpbd.ProductGroupId = dppg.ProductGroup_ID
	WHERE  cpbt.ClaimPayBackTransferStatusId = 3
		AND cpbt.IsActive = 1
		AND (cpbt.TransferDate >= @DateFrom AND cpbt.TransferDate < @DateTo)
		AND (cpbt.ClaimGroupTypeId = @ClaimGroupTypeId OR @ClaimGroupTypeId IS NULL)
		AND cpbd.IsActive = 1
		AND (cpbd.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL)
		AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL);

/*Setup Data2*/
	SELECT 
		icu.InsuranceCompany_Name
		,t.ClaimGroupType
		,t.ClaimGroupCode
		,t.Branch
		,ssicu.Detail										Hospital
		--,CASE 
		--	WHEN @ClaimGroupTypeId = 4 THEN ssicu.Detail
		--	ELSE @xText	
		--END						Hospital
		,t.ProductGroupDetail	ProductGroupDetailName
		,t.ItemCount
		,t.Amount
		,t.ClaimOnLineCode		COL
		,sssmp.Detail			Province
		,CONCAT(icu.Title,icu.FirstName,' ',icu.LastName)	CustomerName
		,sssmtb.Detail										BankName
		,ssicu.BankAccountName	
		,REPLACE(ssicu.BankAccountNo,'-','')				BankAccountNo
		--,CASE 
		--	WHEN @ClaimGroupTypeId IN (2,6) THEN t.ClaimOnLineCode
		--	ELSE @xText	
		--END						COL
		--,CASE 
		--	WHEN @ClaimGroupTypeId = 4 THEN sssmp.Detail
		--	ELSE @xText	
		--END						Province
		--,CASE 
		--	WHEN @ClaimGroupTypeId IN (2,4,6) THEN CONCAT(icu.Title,icu.FirstName,' ',icu.LastName)
		--	ELSE @xText	
		--END						CustomerName
		--,CASE 
		--	WHEN @ClaimGroupTypeId IN (2,4,6) THEN sssmtb.Detail
		--	ELSE @xText	
		--END						BankName
		--,CASE 
		--	WHEN @ClaimGroupTypeId IN (2,4,6) THEN ssicu.BankAccountName
		--	ELSE @xText	
		--END						BankAccountName
		--,CASE 
		--	WHEN @ClaimGroupTypeId IN (2,4,6) THEN REPLACE(ssicu.BankAccountNo,'-','')
		--	ELSE @xText	
		--END						BankAccountNo
		,@xText					ClaimCompensate
		,icu.ClaimNo
		,@xText					PhoneNo
		,t.CreatedDate			SendDate
		,t.TransferDate			CreatedDate
		,CONCAT(dmeu.EmployeeCode,' ',dmeu.PersonName)  ApprovedUser
		,t.CteatedUser
		,icu.ClaimAdmitType
	FROM #Tmp t
		INNER JOIN 
		(
			SELECT
				chg.Code
				,chg.InsuranceCompany_Name		
				,cat.Detail						ClaimAdmitType
				,chg.Hospital_id
				,chg.CreatedBy_id
				,ch.Code						ClaimNo
				,ct.FirstName
				,ct.LastName
				,tt.Detail						Title
			FROM [SSS].[dbo].[DB_ClaimHeaderGroup] chg
				INNER JOIN [SSS].[dbo].[DB_ClaimHeader] ch
					ON chg.Code = ch.ClaimHeaderGroup_id
				LEFT JOIN [SSS].[dbo].[MT_ClaimAdmitType] cat
					ON chg.ClaimAdmitType_id = cat.Code
				LEFT JOIN [SSS].[dbo].[DB_Customer] ct
					ON ch.App_id = ct.App_id
				LEFT JOIN [SSS].[dbo].[MT_Title] tt
					ON tt.Code = ct.Title_id
		UNION ALL
			SELECT 
				pachg.Code
				,pachg.InsuranceCompany_Name
				,smc.Detail
				,ch.Hospital_id
				,pachg.CreatedBy_id
				,ch.Code
				,cd.FirstName
				,cd.LastName
				,tt.Detail
			FROM [SSSPA].[dbo].[DB_ClaimHeaderGroup] pachg
				INNER JOIN [SSSPA].[dbo].[DB_ClaimHeader] ch
					ON pachg.Code = ch.ClaimheaderGroup_id
				LEFT JOIN [SSSPA].[dbo].[SM_Code] smc
					ON pachg.ClaimTypeGroup_id = smc.Code
				LEFT JOIN [SSSPA].[dbo].[DB_CustomerDetail] cd
					ON ch.CustomerDetail_id = cd.Code
			LEFT JOIN [SSSPA].[dbo].[MT_Title] tt
				ON cd.Title_id = tt.Code
		)icu 
			ON t.ClaimGroupCode = icu.Code
	LEFT JOIN [DataCenterV1].[Master].vw_Employee dmeu
		ON icu.CreatedBy_id  = dmeu.EmployeeCode
	/*Master */
	LEFT JOIN [SSS].[dbo].[MT_Company] ssicu
		ON icu.Hospital_id = ssicu.Code
	LEFT JOIN [SSS].[dbo].[MT_Bank] sssmtb
		ON ssicu.Bank_id = sssmtb.Code
	LEFT JOIN [SSS].[dbo].[DB_Address] sssadr
		ON ssicu.Address_id = sssadr.Code
	LEFT JOIN [SSS].[dbo].[SM_Province] sssmp
		ON sssadr.Province_id = sssmp.Code;


IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;




