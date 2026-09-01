 	-- ===============================================
	DECLARE
	@DateFrom			DATE = '2026-01-01'
	,@DateTo			DATE = '2026-01-14'
	,@InsuranceId		INT = NULL
	,@ProductGroupId	INT = 11
	,@ClaimGroupTypeId	INT = 7;
-- ===============================================
	
	SELECT 11	ProductGroupID
		  ,[ProductType_ID]
		  ,CASE [ProductType_ID]
			WHEN  27 THEN N'PA ชุมชน'
			WHEN  32 THEN N'สไมล์พลัส'
			WHEN  33 THEN N'ประกันเดินทาง'
			WHEN  38 THEN N'PA บุคลากร ยิ้มแฉ่ง'
			WHEN  41 THEN N'PA ครอบครัวอุ่นใจ'
			WHEN  10 THEN N'ประกันบ้าน'
			ELSE [ProductTypeDetail]
		END as Detail
	INTO #TmpProductClaimMisc
	FROM [DataCenterV1].[Product].[ProductType]
	WHERE ProductGroup_ID IN(6,7,9,11)
		AND ProductType_ID IN (10,11,27,32,33,38,41,42)
		AND IsActive = 1 

	DECLARE @ProductGroupTB TABLE 
	(
		ProductGroupID INT,
		ProductType_ID INT,
		ProductGroupDetail NVARCHAR(100)	
	);
	INSERT INTO @ProductGroupTB (ProductGroupID,ProductType_ID, ProductGroupDetail)
	VALUES
		(1,1, N'รอข้อมูล'),
		(2,2, N'PH'),
		(3,3, N'PA'),
		(4,4, N'Motor');
	
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
 
 SELECT DISTINCT   
     cpbd.ClaimGroupCode		ClaimGroupCode
	 ,cgt.ClaimGroupType		ClaimGroupType
	 ,cpbd.ItemCount			ItemCount
     ,cpbd.Amount				Amount
	 ,pg.Detail					ProductGroupDetailName
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
	 LEFT JOIN ClaimGroupType cgt
		ON cpb.ClaimGroupTypeId = cgt.ClaimGroupTypeId
	 INNER JOIN #TmpPersonUser pu
		ON pu.[User_ID] = cpb.CreatedByUserId
	LEFT JOIN
	(
		SELECT
			ClaimHeaderGroupCode
			,ProductGroupId
			,ProductTypeId
		FROM [ClaimMiscellaneous].[misc].[ClaimMisc] 
		WHERE IsActive = 1
	) cm
		ON cm.ClaimHeaderGroupCode = cpbd.ClaimGroupCode
	 LEFT JOIN 
	 (
		SELECT
			* 
		FROM #TmpProductClaimMisc
		UNION ALL
		SELECT
			*
		FROM @ProductGroupTB	 
	 ) pg
		ON pg.ProductType_ID = cpbd.ProductGroupId
			OR pg.ProductType_ID = cm.ProductTypeId
   
 WHERE  cpbt.ClaimPayBackTransferStatusId = 3
		AND cpbt.ClaimGroupTypeId = @ClaimGroupTypeId
		AND cpbt.IsActive = 1
		AND cpbd.IsActive = 1
		AND ((cpbt.TransferDate >= @DateFrom) AND (cpbt.TransferDate < DATEADD(Day,1,@DateTo)))
		AND (pg.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL)
		AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)

IF OBJECT_ID('tempdb..#TmpPersonUser') IS NOT NULL DROP TABLE #TmpPersonUser;
IF OBJECT_ID('tempdb..#TmpProductClaimMisc') IS NOT NULL DROP TABLE #TmpProductClaimMisc;