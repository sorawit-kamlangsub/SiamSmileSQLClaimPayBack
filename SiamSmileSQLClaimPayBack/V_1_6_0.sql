USE [ClaimPayBack]
GO

/****** Object:  StoredProcedure [Claim].[usp_ClaimHeaderGroupDetail_SelectV4]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Nattavut Jaikaew
-- Create date: 20240219 1738
-- Update date: 20250325 Kittisak.Ph Add @CalimAdmitType_2001,@CalimAdmitType_2003
-- Update date: 20250430 Chatchada.R Change Where UserCreate in ProductGroupId = PH(2), ClaimGroupTypeId = เคลมโรงพยาบาล Fax(4)
-- Update date: 20250612 Kittisak.Ph Add Check Status
-- Update date: 20250725 Kittisak.Ph Add Check c.ClaimType_id NOT IN ('4005','4008')
-- Update date: 20250806 Bunchuai Chaiket เพิ่มการ join ClaimOnlineV2.dbo.ClaimOnline ในเงื่อนไข PH/PA เพื่อตรวจสอบสถานะการโอนเงิน
-- Update date: 20250821 Kittisak.Ph เพิ่มวันที่Cutoff (DisabilityCompensationDate) ชดเชยสูญเสียอวัยวะ
-- Update date: 20250902 Krekpon.D เพิ่มจำนวนเงินที่จ่ายของ บส.
-- Update date: 20251021 Sorawit.k change to [usp_ClaimHeaderGroupDetail_SelectV5]
-- Update date: 20261022 Sorawit.k change add Claimmisc
-- Update date: 20251211 Bunchuai.c เปลี่ยนการ filter ข้อมูลของ ClaimMisc filter ข้อมูลตาม ProductTypeId
-- Update date: 20260117 Sorawit.k เพิ่ม Left Join ClaimPaymentType
-- Update date: 20260310 Sorawit.k ปรับปรุง where not exist clammmisc
-- Description:	
-- =============================================
CREATE PROCEDURE [Claim].[usp_ClaimHeaderGroupDetail_SelectV4]
	 @ProductGroupId		INT 			= NULL
	,@InsuranceId			INT				= NULL
	,@ClaimGroupTypeId		INT				= NULL
	,@BranchId				INT				= NULL	
	,@CreateByUser_Code		VARCHAR(20)		= NULL
	,@IndexStart			INT				= NULL	
	,@PageSize				INT				= NULL
	,@SortField				NVARCHAR(MAX)	= NULL
	,@OrderType				NVARCHAR(MAX)	= NULL
	,@SearchDetail			NVARCHAR(MAX)	= NULL 
	,@IsShowDocumentLink	BIT				= NULL
	,@ProductTypeId			INT				= NULL
	,@ClaimPayBackTypeId	INT				= NULL
AS
BEGIN
	SET NOCOUNT ON;

--======= for test =======
	-- DECLARE
	-- @ProductGroupId		INT 			= 11
	--,@InsuranceId			INT				= NULL
	--,@ClaimGroupTypeId		INT				= 7
	--,@BranchId				INT				= NULL	
	--,@CreateByUser_Code		VARCHAR(20)		= NULL
	--,@IndexStart			INT				= 0	
	--,@PageSize				INT				= 20
	--,@SortField				NVARCHAR(MAX)	= NULL
	--,@OrderType				NVARCHAR(MAX)	= NULL
	--,@SearchDetail			NVARCHAR(MAX)	= NULL 
	--,@IsShowDocumentLink	BIT				= NULL
	--,@ProductTypeId			INT				= NULL
	--,@ClaimPayBackTypeId	INT				= NULL;
--==============

DECLARE @pInsCode				VARCHAR(20)		= NULL	/*ถ้าส่ง @InsuranceId จะ set*/
DECLARE @pBranchCode			VARCHAR(20)		= NULL	/*ถ้าส่ง @BranchId จะ set*/
DECLARE @pProductGroupId		INT				= @ProductGroupId
DECLARE @pClaimGroupTypeId		INT				= @ClaimGroupTypeId
DECLARE @pIsValidDoc			BIT				= @IsShowDocumentLink
DECLARE @pCreatedByCode			VARCHAR(20)		= @CreateByUser_Code
DECLARE @pProductTypeId			INT				= @ProductTypeId
DECLARE @pClaimPayBackTypeId	INT				= @ClaimPayBackTypeId

DECLARE @pIndexStart			INT				= @IndexStart
DECLARE @pPageSize				INT				= @PageSize
DECLARE @pSortField				NVARCHAR(MAX)	= @SortField
DECLARE @pOrderType				NVARCHAR(MAX)	= @OrderType
DECLARE @pSearchDetail			NVARCHAR(MAX)	= @SearchDetail


IF @pSearchDetail = '' SET @pSearchDetail = NULL;

DECLARE @pg_2	INT = 2;
DECLARE @pg_3	INT = 3;
DECLARE @B_9901	VARCHAR(20) = '9901';

DECLARE @ClaimType_1000 VARCHAR(20) = '1000';
DECLARE @ClaimType_2000	VARCHAR(20) = '2000';

DECLARE @CalimAdmitType_1001 VARCHAR(20) = '1001';
DECLARE @CalimAdmitType_3001 VARCHAR(20) = '3001';
--DECLARE @CalimAdmitType_2001 VARCHAR(20) = '2001';	-- 20250325 Kittisak.Ph
--DECLARE @CalimAdmitType_2003 VARCHAR(20) = '2003';  -- 20250325 Kittisak.Ph


DECLARE @fix_ClaimCompensateCreatedDatefrom DATETIME = '2023-12-08'	/*ClaimCompensate*/

DECLARE @fix_OpdDateCutoff	DATETIME = '2023-12-08';	/*OpdDateCutoff*/
DECLARE @fix_IpdDateCutoff	DATETIME = '2023-10-26';

DECLARE @fix_CutoffEndDATE	DATETIME = '2024-01-09'	/*CutoffEndDate*/

DECLARE @CreatedDateFrom DATETIME = '2023-11-27';

DECLARE @InsSMICode VARCHAR(20) = '100000000041';
DECLARE @DisabilityCutoffDate DATE = '2025-08-18';

/*
ClaimGroupTypeId	ClaimGroupType
2	เคลมออนไลน์
3	เคลมสาขา
4	เคลมโรงพยาบาล
5	เคลมโอนแยก
6	เคลมเสียชีวิต ทุพพลภาพ
*/

SELECT Code
		,ClaimType_id 
		,CASE Code
			WHEN @CalimAdmitType_1001 THEN 1
			WHEN @CalimAdmitType_3001 THEN 1
			ELSE 0
			END xFlag
INTO #TmpCAT
FROM sss.dbo.MT_ClaimAdmitType WITH (NOLOCK);


SELECT Organize_ID		OrganizeId
		,OrganizeCode	OrganizeCode
INTO #TmpIns
FROM DataCenterV1.Organize.Organize WITH (NOLOCK)
WHERE OrganizeType_ID IN (2,6);


/*Set @pInsCode*/
IF @InsuranceId IS NOT NULL
BEGIN
	SELECT @pInsCode = OrganizeCode 
	FROM #TmpIns
	WHERE OrganizeId = @InsuranceId;
END;


IF @BranchId IS NOT NULL
BEGIN
	SELECT @pBranchCode = tempcode 
	FROM DataCenterV1.Address.Branch
	WHERE Branch_ID = @BranchId;
END;

/*Tmp*/
CREATE TABLE #Tmplst 
(
	ClaimHeaderGroupCode	VARCHAR(30)
	,ClaimHeaderCode		VARCHAR(20)
	,BranchCode				VARCHAR(20)
	,CreatedByCode			VARCHAR(20)
	,CreatedDate			DATETIME
	,InsuranceCompanyCode	VARCHAR(20)
	,InsuranceCompanyName	NVARCHAR(255)
	,ProductGroupId			INT
	,xRevise				VARCHAR(20)
	,Amount					DECIMAL(16,2) 
	,ClaimGroupTypeId		INT
	,TransferAmount			DECIMAL(16,2)
	,ProductTypeDetail		NVARCHAR(100)
);

CREATE TABLE #TmpDoc 
(
	ClaimHeaderGroupCode VARCHAR(20) 
	,ClaimHeaderCode VARCHAR(20)
);

DECLARE @TmpClaimMisc TABLE 
(
	ClaimMiscId				UNIQUEIDENTIFIER
	,ClaimHeaderGroupCode	VARCHAR(30)
	,ClaimHeaderCode		VARCHAR(20)
	,BranchCode				VARCHAR(20)
	,CreatedByCode			VARCHAR(20)
	,CreatedDate			DATETIME
	,InsuranceCompanyCode	VARCHAR(20)
	,InsuranceCompanyName	NVARCHAR(255)
	,ProductGroupId			INT
	,xRevise				VARCHAR(20)
	,Amount					DECIMAL(16,2) 
	,ClaimGroupTypeId		INT
	,TransferAmount			DECIMAL(16,2)
	,ProductTypeDetail		VARCHAR(100)
);
 
IF @pProductGroupId = 2 AND @pClaimGroupTypeId = 5
	BEGIN
	
		INSERT INTO #Tmplst
		        (ClaimHeaderGroupCode
		        ,ClaimHeaderCode
		        ,BranchCode
		        ,CreatedByCode
		        ,CreatedDate
		        ,InsuranceCompanyCode
		        ,InsuranceCompanyName
		        ,ProductGroupId
		        ,xRevise
				,amount 
				,ClaimGroupTypeId
				,TransferAmount
				,ProductTypeDetail)
		SELECT 
				cg.ClaimCompensateGroupCode				ClaimHeaderGroupCode
				,c.ClaimCompensateCode					ClaimHeaderCode		
				,@B_9901								BranchCode
				,cg.CreatedByCode						CreatedByCode
				,cg.CreatedDate							CreatedDate
				,cg.InsuranceCompanyCode				InsuranceCompanyCode
				,cg.InsuranceCompany_Name				InsuranceCompanyName
				,@pg_2									ProductGroupId
				,RIGHT(cg.ClaimCompensateGroupCode,1)	xRevise
				,c.CompensateRemain						amount
				,@pClaimGroupTypeId						ClaimGroupTypeId
				,0										TransferAmount
				,pd.Detail								ProductTypeDetail

		FROM sss.dbo.ClaimCompensate c	WITH (NOLOCK)
			INNER JOIN sss.dbo.ClaimCompensateGroup cg	WITH (NOLOCK)
				ON c.ClaimCompensateGroupId = cg.ClaimCompensateGroupId
			LEFT JOIN (
				SELECT 
					m.Code
					,g.Detail
				FROM [sss].[dbo].[MT_Product] m
					LEFT JOIN [sss].[dbo].[MT_ProductGroup] g 
						ON m.ProductGroup_id = g.Code 
			) pd
				ON c.ProductCode = pd.Code
		WHERE (cg.ItemCount > 0)
		AND (cg.CreatedDate >= @fix_ClaimCompensateCreatedDatefrom)
		AND (cg.InsuranceCompanyCode = @pInsCode OR @pInsCode IS NULL)
		AND (cg.CreatedByCode = @pCreatedByCode OR @pCreatedByCode IS NULL)
		AND (cg.ClaimCompensateGroupCode = @pSearchDetail OR @pSearchDetail IS NULL)
		AND NOT EXISTS	(
							SELECT x.ClaimCode
							FROM dbo.ClaimPayBackXClaim x	WITH(NOLOCK)
							LEFT JOIN dbo.ClaimPayBackDetail cd	WITH(NOLOCK)
								ON x.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
							LEFT JOIN dbo.ClaimPayBack cp
								ON cd.ClaimPayBackId = cp.ClaimPayBackId
							WHERE x.IsActive = 1
							AND cp.ClaimGroupTypeId = @pClaimGroupTypeId
							AND cd.ProductGroupId = @pProductGroupId
							AND x.ClaimCode = c.ClaimHeaderCode
						); 

	END 
-- PH
ELSE IF @pProductGroupId = 2 AND @pClaimGroupTypeId IN (2,3,4,6)
	BEGIN
    
		INSERT INTO #Tmplst
		        (ClaimHeaderGroupCode
		        ,ClaimHeaderCode
		        ,BranchCode
		        ,CreatedByCode
		        ,CreatedDate
		        ,InsuranceCompanyCode
		        ,InsuranceCompanyName
		        ,ProductGroupId
		        ,xRevise
				,amount
				,ClaimGroupTypeId
				,TransferAmount
				,ProductTypeDetail)
		SELECT	
				g.Code														ClaimHeaderGroupCode
				,i.ClaimHeader_id											ClaimHeaderCode
				,g.Branch_id												BranchCode
				,g.CreatedBy_id												CreatedByCode
				,g.CreatedDate												CreatedDate
				,g.InsuranceCompany_id										InsuranceCompanyCode
				,g.InsuranceCompany_Name									InsuranceCompanyName
				,@pg_2														ProductGroupId
				,RIGHT(g.code,1)											xRevise
				,v.PaySS_Total												amount
				,@pClaimGroupTypeId											ClaimGroupTypeId
				,0															TransferAmount
				,mtg.Detail													ProductTypeDetail

		FROM sss.dbo.DB_ClaimHeaderGroupItem i			WITH (NOLOCK)
			INNER JOIN SSS.dbo.DB_ClaimHeaderGroup g	WITH (NOLOCK)
				ON i.ClaimHeaderGroup_id = g.Code
			LEFT JOIN #TmpCAT cat
				ON g.ClaimAdmitType_id = cat.Code
			LEFT JOIN sss.dbo.DB_ClaimHeader cl			WITH (NOLOCK)
				ON i.ClaimHeader_id = cl.Code
			LEFT JOIN sss.dbo.DB_ClaimVoucher v			WITH (NOLOCK)
				ON i.ClaimHeader_id = v.Code
			LEFT JOIN [sss].[dbo].[MT_ProductGroup] mtg
				ON g.ProductGroup_id = mtg.Code
		WHERE (g.InsuranceCompany_id = @pInsCode OR @pInsCode IS NULL)
			AND (g.Branch_id = @pBranchCode OR @pBranchCode IS NULL)
			AND (
					(
						@pClaimGroupTypeId = 4 
						AND cat.xFlag = 1
						AND	cl.ClaimPaybackStatus = 1
						AND	(cl.UpdatedByCode = @pCreatedByCode OR @pCreatedByCode IS NULL)
					)
				 OR (
						cat.xFlag = 0
						AND	(g.CreatedBy_id = @pCreatedByCode OR @pCreatedByCode IS NULL)
					)
				)
			AND (g.Code = @pSearchDetail OR @pSearchDetail IS NULL)				
			AND	(
					(
						@pClaimGroupTypeId = 2	
						AND g.IsClaimOnLine = 1
			
						AND cat.xFlag = 0
						AND g.CreatedDate >= @fix_OpdDateCutoff 
						AND g.ClaimAdmitType_id NOT IN('4000','4001','5001','5002') 
					) 
				OR	(
						@pClaimGroupTypeId = 3	
						AND (g.IsClaimOnLine IS NULL OR g.IsClaimOnLine = 0)
						AND cat.ClaimType_id = @ClaimType_2000	
			
						AND cat.xFlag = 0
						AND g.CreatedDate >= @fix_OpdDateCutoff
					)
				OR	(
						@pClaimGroupTypeId = 4	
						AND (g.IsClaimOnLine IS NULL OR g.IsClaimOnLine = 0)
						AND cat.ClaimType_id = @ClaimType_1000	
						AND (
								(
									cat.xFlag = 0
									AND G.CreatedDate >= @fix_OpdDateCutoff
								)
							OR	(
									cat.xFlag = 1
									AND cl.ClaimPaybackStatus = 1
									AND g.CreatedDate >= @fix_CutoffEndDATE
								)
							)
					)
				OR (
						@pClaimGroupTypeId = 6
						AND g.IsClaimOnLine = 1
						AND cat.xFlag = 0
						AND g.CreatedDate >= @fix_OpdDateCutoff
						AND g.ClaimAdmitType_id IN('4000','4001','5001','5002')
					)
				)
				AND NOT EXISTS	(
									SELECT x.ClaimCode
									FROM dbo.ClaimPayBackXClaim x	WITH(NOLOCK)
									LEFT JOIN dbo.ClaimPayBackDetail cd	WITH(NOLOCK)
										ON x.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
									LEFT JOIN dbo.ClaimPayBack cp
										ON cd.ClaimPayBackId = cp.ClaimPayBackId
									WHERE x.IsActive = 1
									AND cp.ClaimGroupTypeId = @pClaimGroupTypeId
									AND cd.ProductGroupId = @pProductGroupId
									AND x.ClaimCode = i.ClaimHeader_id 
								)  
	
	END
-- PA
ELSE IF @pProductGroupId = 3 AND @pClaimGroupTypeId IN (2,3,4,6)
	BEGIN

		INSERT INTO #Tmplst
		        (ClaimHeaderGroupCode
		        ,ClaimHeaderCode
		        ,BranchCode
		        ,CreatedByCode
		        ,CreatedDate
		        ,InsuranceCompanyCode
		        ,InsuranceCompanyName
		        ,ProductGroupId
		        ,xRevise
				,amount
				,ClaimGroupTypeId
				,TransferAmount
				,ProductTypeDetail)
		SELECT g.Code														ClaimHeaderGroupCode
				,i.ClaimHeader_id											ClaimHeaderCode
				,g.Branch_id												BranchCode
				,g.CreatedBy_id												CreatedByCode
				,g.CreatedDate												CreatedDate
				,g.InsuranceCompany_id										InsuranceCompanyCode
				,g.InsuranceCompany_Name									InsuranceCompanyName 
				,@pg_3														ProductGroupId
				,RIGHT(g.code,1)											xRevise
				,c.PaySS_Total												amount 
				,@pClaimGroupTypeId											ClaimGroupTypeId
				,0															TransferAmount
				,mtg.Detail													ProductTypeDetail

		FROM SSSPA.dbo.DB_ClaimHeaderGroupItem i WITH (NOLOCK)
			INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup g WITH (NOLOCK)
				ON i.ClaimHeaderGroup_id = g.Code
			LEFT JOIN SSSPA.dbo.DB_ClaimHeader c
				ON i.ClaimHeader_id = c.Code
			LEFT JOIN [SSSPA].[dbo].[MT_ProductGroup] mtg
				ON g.ProductGroup_id = mtg.Code
		WHERE (g.InsuranceCompany_id = @pInsCode OR @pInsCode IS NULL)
			AND (g.Branch_id = @pBranchCode OR @pBranchCode IS NULL)
			AND (g.CreatedBy_id = @pCreatedByCode OR @pCreatedByCode IS NULL)
			AND (g.Code = @pSearchDetail OR @pSearchDetail IS NULL)				
			AND	(
					(
						@pClaimGroupTypeId = 2
						AND g.IsClaimOnLine = 1
						AND g.CreatedDate >= @CreatedDateFrom
						AND (c.ClaimType_id IN('4001','4002','4003','4004') OR (c.ClaimType_id='4005' AND c.CreatedDate >@DisabilityCutoffDate))
					)
				OR	(
						@pClaimGroupTypeId = 3
						AND (g.IsClaimOnLine = 0 OR g.IsClaimOnLine IS NULL)
						AND g.ClaimStyle_id IN ('4130','4140')
						AND g.CreatedDate >= @CreatedDateFrom
					)
				OR	(
						@pClaimGroupTypeId = 4
						AND (g.IsClaimOnLine = 0 OR g.IsClaimOnLine IS NULL)
						AND g.ClaimStyle_id IN ('4110','4120')
						AND g.CreatedDate >= @fix_IpdDateCutoff
					)
				OR	(
						@pClaimGroupTypeId = 6
						AND (g.IsClaimOnLine = 1)
						AND c.ClaimType_id IN ('4006','4006_2','4007','4008','4009','4010')
						AND g.CreatedDate >= @fix_IpdDateCutoff
					)
				)
			AND NOT EXISTS	(
								SELECT x.ClaimCode
								FROM dbo.ClaimPayBackXClaim x	WITH(NOLOCK)
								LEFT JOIN dbo.ClaimPayBackDetail cd	WITH(NOLOCK)
									ON x.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
								LEFT JOIN dbo.ClaimPayBack cp
									ON cd.ClaimPayBackId = cp.ClaimPayBackId
								WHERE x.IsActive = 1
								AND cp.ClaimGroupTypeId = @pClaimGroupTypeId
								AND cd.ProductGroupId = @pProductGroupId
								AND x.ClaimCode = i.ClaimHeader_id 
							)
			AND c.Status_id NOT IN ('3570','3580')  
		  
	END
-- ClaimMisc
ELSE IF @pProductGroupId IN (4,11) AND @pClaimGroupTypeId = 7
	BEGIN
		INSERT INTO @TmpClaimMisc
		        (ClaimMiscId
				,ClaimHeaderGroupCode
		        ,ClaimHeaderCode
		        ,BranchCode
		        ,CreatedByCode
		        ,CreatedDate
		        ,InsuranceCompanyCode
		        ,InsuranceCompanyName
		        ,ProductGroupId
		        ,xRevise
				,amount
				,ClaimGroupTypeId
				,TransferAmount
				,ProductTypeDetail)		
		SELECT 
				cm.ClaimMiscId
				,cm.ClaimHeaderGroupCode									ClaimHeaderGroupCode
				,1															ClaimHeaderCode
				,b.tempcode													BranchCode
				,ISNULL(e.EmployeeCode, '00000')							CreatedByCode
				,cm.ApproveDate												CreatedDate
				,cm.InsuranceCompanyCode									InsuranceCompanyCode
				,cm.InsuranceCompanyName									InsuranceCompanyName 
				,cm.ProductGroupId											ProductGroupId
				,'0'														xRevise
				,ISNULL(cm.PayAmount, 0) 									amount 
				,@pClaimGroupTypeId											ClaimGroupTypeId
				,NULL														TransferAmount
				,IIF(@pProductGroupId = 4,cpbType.ClaimPaymentTypeName,pt.ProductTypeDetail)	ProductTypeDetail
		FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			LEFT JOIN [DataCenterV1].[Product].[ProductGroup] pd
				ON cm.ProductGroupId = pd.ProductGroup_ID
			LEFT JOIN [DataCenterV1].[Person].[PersonUser] pu
				ON pu.[User_ID] = cm.CreatedByUserId
			LEFT JOIN [DataCenterV1].[Employee].[Employee] e
				ON pu.Employee_ID = e.Employee_ID
			LEFT JOIN [DataCenterV1].[Address].[Branch] b
				ON cm.BranchId = b.Branch_ID
			LEFT JOIN [DataCenterV1].[Product].[ProductType] pt
				ON cm.ProductTypeId = pt.ProductType_ID
			 LEFT JOIN (
				SELECT DISTINCT
				 h.ClaimMiscId
				 ,cp.ClaimPaymentTypeId
				 ,cp.ClaimPaymentTypeName
				FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] h
				 LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] p
				  ON h.ClaimMiscPaymentHeaderId = p.ClaimMiscPaymentHeaderId
				 LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimPaymentType] cp
				  ON cp.ClaimPaymentTypeId = p.ClaimPaymentTypeId
				 ) cpbType
			  ON cm.ClaimMiscId = cpbType.ClaimMiscId
		WHERE cm.IsActive = 1  
			AND cm.ClaimMiscStatusId = 3  
			AND cm.ClaimHeaderGroupCode IS NOT NULL
			AND (@pInsCode IS NULL OR cm.InsuranceCompanyCode = @pInsCode)
			AND (@pBranchCode IS NULL OR b.tempcode = @pBranchCode)
			AND (@pCreatedByCode IS NULL OR e.EmployeeCode = @pCreatedByCode)
			AND (@pSearchDetail IS NULL OR cm.ClaimHeaderGroupCode = @pSearchDetail)
			AND cm.ProductTypeId NOT IN (34)
			AND 
			(
				(
					@pProductGroupId = 4
					AND 
						(
							(@pClaimPayBackTypeId IS NOT NULL AND cpbType.ClaimPaymentTypeId = @pClaimPayBackTypeId)
							OR
							(@pClaimPayBackTypeId IS NULL AND cm.ProductTypeId = 11)
						)
				)
				OR
				(
					@pProductGroupId = 11 
					AND
						(
							(@pProductTypeId IS NOT NULL AND cm.ProductTypeId = @pProductTypeId)
							OR
							(@pProductTypeId IS NULL AND cm.ProductTypeId IN (10,27,38,41,42,32,33))
						)
				)
			) 
			AND NOT EXISTS	
			(
				SELECT 1
				FROM dbo.ClaimPayBackDetail cd	WITH(NOLOCK)
				WHERE cd.IsActive = 1
					AND cm.ClaimHeaderGroupCode = cd.ClaimGroupCode
			)

		INSERT INTO #Tmplst
		(
			ClaimHeaderGroupCode
			,ClaimHeaderCode
			,BranchCode
			,CreatedByCode
			,CreatedDate
			,InsuranceCompanyCode
			,InsuranceCompanyName
			,ProductGroupId
			,xRevise
			,amount
			,ClaimGroupTypeId
			,TransferAmount
			,ProductTypeDetail)
		SELECT 
			ClaimHeaderGroupCode
			,ClaimHeaderCode
			,BranchCode
			,CreatedByCode
			,CreatedDate
			,InsuranceCompanyCode
			,InsuranceCompanyName
			,ProductGroupId
			,xRevise
			,amount
			,ClaimGroupTypeId
			,TransferAmount
			,ProductTypeDetail
		FROM @TmpClaimMisc

	END

SELECT * 
		,ROW_NUMBER() OVER(ORDER BY (a.ClaimHeaderGroupCode) ASC) rwId
INTO #TmpCondition
FROM #Tmplst a
WHERE a.xRevise = '0';

--เคลมออนไลน์,เคลมสาขา,เคลมโอนแยก,เคลมเสียชีวิต ทุพพลภาพ
IF @pClaimGroupTypeId IN (2,3,5,6)
BEGIN

	INSERT INTO #TmpDoc(ClaimHeaderGroupCode,ClaimHeaderCode)
	SELECT x.ClaimHeaderGroupCode
			,x.ClaimHeaderCode 
	FROM ISC_SmileDoc.dbo.ClaimDocument d WITH (NOLOCK)
		INNER JOIN #TmpCondition x
			ON d.DocumentIndexData = x.ClaimHeaderCode COLLATE DATABASE_DEFAULT
	WHERE d.DocumentStatusId IN (2,4)
	AND d.IsActive = 1
	GROUP BY x.ClaimHeaderGroupCode
			,x.ClaimHeaderCode 
END

/*Set Page*/
IF @pIndexStart		IS NULL	SET @pIndexStart = 0;
IF @pPageSize		IS NULL	SET @pPageSize	 = 10;

SET @pSortField = NULL;
SET @pOrderType = NULL;

SELECT g.ClaimHeaderGroupCode									ClaimHeaderGroup_id  
		,b.Detail												Branch
		,pg.ProductGroupDetail									ProductGroup
		,CONCAT(eC.Code,' ', eC.FirstName,' ', eC.LastName)		CreatedByName
		,d.CreatedDate											CreatedDate
		,cgt.ClaimGroupType										ClaimGroupType
		,g.ItemCount											ItemCount
		,g.Amount												Amount
		,oIns.OrganizeId										InsuranceCompanyId
		,d.InsuranceCompanyName									InsuranceCompany	 
		,COUNT(g.ClaimHeaderGroupCode) OVER ()					TotalCount
		,IIF(g.ItemCount = doc.docCount ,1,0)					DocumentCount	 
		--,1														DocumentCount
		,g.TransferAmount										TransferAmount
		,d.ProductTypeDetail									ProductTypeDetail
FROM
(
	SELECT ClaimHeaderGroupCode			ClaimHeaderGroupCode
			,COUNT(ClaimHeaderCode)		ItemCount
			,SUM(ISNULL(amount,0))		Amount	
			,MIN(rwId)					minId 
			,TransferAmount				TransferAmount
	FROM #TmpCondition
	GROUP BY ClaimHeaderGroupCode,TransferAmount
)g
	INNER JOIN #TmpCondition d
		ON g.minId = d.rwId
	LEFT JOIN 
		(
			SELECT ClaimHeaderGroupCode
					,ISNULL(COUNT(ClaimHeaderGroupCode),0)	docCount
			FROM #TmpDoc 
			GROUP BY ClaimHeaderGroupCode
		)doc
		ON g.ClaimHeaderGroupCode = doc.ClaimHeaderGroupCode
	LEFT JOIN dbo.ClaimGroupType  cgt
		ON d.ClaimGroupTypeId = cgt.ClaimGroupTypeId
	LEFT JOIN [SSS].[dbo].[MT_Branch] b
		ON d.BranchCode = b.Code					COLLATE DATABASE_DEFAULT
	LEFT JOIN sss.dbo.DB_Employee eC
		ON d.CreatedByCode = eC.Code				COLLATE DATABASE_DEFAULT

	LEFT JOIN DataCenterV1.Product.ProductGroup pg
		ON d.ProductGroupId = pg.ProductGroup_ID 
	LEFT JOIN #TmpIns oIns
		ON d.InsuranceCompanyCode = oIns.OrganizeCode COLLATE DATABASE_DEFAULT
WHERE	(
			(
				@pIsValidDoc = 1 
				AND g.ItemCount = doc.docCount
			)
		OR	(
				@pIsValidDoc = 0 
				AND (
						(
							g.ItemCount <> doc.docCount
						)
					OR	(
							doc.docCount IS NULL
						)
					)
			)
		OR	(
				@pIsValidDoc IS NULL
			)
		)
ORDER BY g.ClaimHeaderGroupCode ASC	


OFFSET @pIndexStart ROWS FETCH NEXT @pPageSize ROWS ONLY;


IF OBJECT_ID('tempdb..#TmpDoc') IS NOT NULL  DROP TABLE #TmpDoc;	
IF OBJECT_ID('tempdb..#TmpCondition') IS NOT NULL  DROP TABLE #TmpCondition;	
IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;	
IF OBJECT_ID('tempdb..#TmpCAT') IS NOT NULL  DROP TABLE #TmpCAT;	
IF OBJECT_ID('tempdb..#TmpIns') IS NOT NULL  DROP TABLE #TmpIns;		

--DECLARE @DefaultDate AS DATETIME = '2021-10-08 08:22'
--	DECLARE @amount		AS DECIMAL
-- SELECT 
--				 N''							ClaimHeaderGroup_id
--				,''							Branch
--				,''							ProductGroup	
--				,''							 CreatedByName
--				,@DefaultDate					CreatedDate
--	            ,''								ClaimGroupType
--				,1							ItemCount
--				,@amount					Amount
--				,1							InsuranceCompanyId
--				,''								InsuranceCompany
--				,1							DocumentCount
--				,1							TotalCount

END;
GO

/****** Object:  StoredProcedure [Claim].[usp_ClaimHeaderGroupItem_Select]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		supattra
-- Create date: 2021-10-07
-- Update date: 2023-09-21 golffy Add ClaomCompensate
--				2025-10-21 Sorawit kamlangsub Add ClaimMisc 
--				2026-01-22 Sorawit kamlangsub Update Prod Url 
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [Claim].[usp_ClaimHeaderGroupItem_Select] 
	 @ClaimGroupCode		NVARCHAR(255)
	,@ProductGroupId		INT
	,@ClaimGroupTypeId		INT

	,@IndexStart					INT = NULL 
	,@PageSize						INT = NULL 
	,@SortField						NVARCHAR(MAX) = NULL
	,@OrderType						NVARCHAR(MAX) = NULL
	,@SearchDetail					NVARCHAR(MAX) = NULL
AS
BEGIN
	
	SET NOCOUNT ON;

	 ----------------------------------------------------------------------------
	IF @IndexStart IS NULL			BEGIN	SET @IndexStart			= 0		END	;
	IF @PageSize IS NULL			BEGIN	SET @PageSize			= 10	END	;
	IF @SearchDetail IS NULL		BEGIN	SET @SearchDetail		= ''	END	;
	----------------------------------------------------------------------------
 	
--Get URL in ProgramConfig
DECLARE @SSSURL			NVARCHAR(250);
DECLARE @SSSPAURL		NVARCHAR(250);
DECLARE @ClaimMiscURL	NVARCHAR(250);

DECLARE @SSSPath	NVARCHAR(250) = 'SSS_URL'
DECLARE @SSSPAPath	NVARCHAR(250) = 'SSSPA_URL'

SELECT @SSSURL = ValueString
FROM dbo.ProgramConfig 
WHERE ParameterName = @SSSPath

SELECT @SSSPAURL = ValueString
FROM dbo.ProgramConfig 
WHERE ParameterName = @SSSPAPath

-- Set URL
SET @SSSURL =	CONCAT(@SSSURL,'Modules/Claim/frmClaimApproveOverview.aspx?clm=');
SET @SSSPAURL = CONCAT(@SSSPAURL,'Modules/Claim/frmClaimPA_New.aspx?clm=');
SET @ClaimMiscURL = 'https://claimmisc.siamsmile.co.th/viewclaimdetails?id=';


DECLARE @tmpClg TABLE (
	ClaimHeaderGroup_id VARCHAR(20),
	ClaimHeader_id VARCHAR(20)
);

DECLARE @tmpCliamMisc TABLE 
(
	ClaimCode			VARCHAR(255)
	,URLLink			VARCHAR(255)
	,Product_Id			VARCHAR(255)
	,[Product]			VARCHAR(255)
	,Hospital_Id		VARCHAR(255)
	,Hospital			VARCHAR(255)
	,ClaimAdmitType_Id	VARCHAR(255)
	,ClaimAdmitType		VARCHAR(255)
	,ChiefComplain_id	VARCHAR(255)
	,ChiefComplain		VARCHAR(255)
	,ICD10				VARCHAR(255)
	,ICD10_Detail		VARCHAR(255)
)
	
	-- Compenstate
	IF @ProductGroupId = 2 AND @ClaimGroupTypeId = 5
		BEGIN
		    
			INSERT INTO @tmpClg -- 20230921
			(
			    ClaimHeaderGroup_id
			  , ClaimHeader_id
			)
			SELECT ccg.ClaimCompensateGroupCode
				, cc.ClaimHeaderCode
			FROM sss.dbo.ClaimCompensateGroup ccg
			LEFT JOIN sss.dbo.ClaimCompensate cc
				ON ccg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
			WHERE ccg.ClaimCompensateGroupCode = @ClaimGroupCode

		END

	IF @ProductGroupId IN (4,5,6,7,8,9,10,11) AND @ClaimGroupTypeId = 7
		BEGIN
			INSERT INTO @tmpCliamMisc
			(
				ClaimCode			
				,URLLink			
				,Product_Id			
				,[Product]			
				,Hospital_Id		
				,Hospital			
				,ClaimAdmitType_Id	
				,ClaimAdmitType		
				,ChiefComplain_id	
				,ChiefComplain		
				,ICD10				
				,ICD10_Detail					
			)
			SELECT
				cm.ClaimMiscNo														ClaimCode
				,CONCAT(@ClaimMiscURL,cm.ClaimMiscId)								URLLink
				,CAST(cm.ProductTypeId AS VARCHAR(20))								Product_Id
				,pt.ProductTypeName													[Product]
				,CAST(cm.HospitalId AS VARCHAR(20))									Hospital_Id
				,cm.HospitalName													Hospital
				,NULL																ClaimAdmitType_Id
				,STUFF((
					SELECT DISTINCT
						   ',' + cat.ClaimAdmitTypeName
					FROM [ClaimMiscellaneous].[misc].[ClaimMiscXClaimAdmitType] cxt
					LEFT JOIN 
					(
						SELECT 
							ClaimAdmitTypeId
							,ClaimAdmitTypeName
						FROM [ClaimMiscellaneous].[misc].[ClaimAdmitType] 
						WHERE IsActive = 1
					) cat
					  ON cat.ClaimAdmitTypeId = cxt.ClaimAdmitTypeId
					WHERE cxt.IsActive = 1
					  AND cxt.ClaimMiscId = cm.ClaimMiscId
					FOR XML PATH(''), TYPE
				).value('.','nvarchar(max)'), 1, 1, '')									ClaimAdmitType 
				,CAST(cm.ChiefComplainId AS VARCHAR(20))								ChiefComplain_id
				,chf.ChiefComplainName													ChiefComplain
				,NULL																	ICD10
				,NULL																	ICD10_Detail			
			FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
				LEFT JOIN 
				(
					SELECT 
						ProductTypeId
						,ProductTypeName
					FROM [ClaimMiscellaneous].[misc].[ProductType] 
					WHERE IsActive = 1
				) pt
				ON pt.ProductTypeId = cm.ProductTypeId
				LEFT JOIN
				(
					SELECT
						ChiefComplainId
						,ChiefComplainName
					FROM [ClaimMiscellaneous].[misc].[ChiefComplain]
					WHERE IsActive = 1
				) chf
				ON chf.ChiefComplainId = cm.ChiefComplainId

			WHERE cm.IsActive = 1
			AND cm.ClaimHeaderGroupCode = @ClaimGroupCode



		END
	
	-- Ph And Pa
	ELSE
		BEGIN
		    
			INSERT INTO @tmpClg
			(
			    ClaimHeaderGroup_id
			  , ClaimHeader_id
			)
			SELECT 
					A.ClaimHeaderGroup_id
					,A.ClaimHeader_id
			FROM (
					SELECT t.ClaimHeaderGroup_id
						,t.ClaimHeader_id
					FROM  sss.dbo.DB_ClaimHeaderGroupItem t
					WHERE (t.ClaimHeaderGroup_id = @ClaimGroupCode)
				UNION  
					SELECT 	 item.ClaimHeaderGroup_id
							,item.ClaimHeader_id
					FROM ssspa.dbo.DB_ClaimHeaderGroupItem item
					WHERE (item.ClaimHeaderGroup_id = @ClaimGroupCode)
				)A 	

		END


		
   SELECT * INTO #tmpDetal
	  FROM (
			 SELECT  
				   Cl.Code ClaimCode
				  ,CONCAT(@SSSURL,dbo.uFnStringToBase64(Cl.Code))  URLLink
				  ,Cl.Product_Id
				  ,Cl.Product
				  ,Cl.Hospital_Id
				  ,Cl.Hospital
				  ,Cl.ClaimAdmitType_Id
				  ,Cl.ClaimAdmitType
				  ,Cl.ChiefComplain_id
				  ,Cl.ChiefComplain
				  ,Cl.ICD10
				  ,Cl.ICD10_Detail
				FROM sss.[dbo].[rpt_ClaimBenefit_NetAndPay]	 Cl
					INNER JOIN @tmpClG t
						ON 	cl.Code = t.ClaimHeader_id
		UNION
		   SELECT 
		   		 vw.Code ClaimCode
				,CONCAT(@SSSPAURL,dbo.uFnStringToBase64(vw.Code))	 URLLink
		   		,vw.ClaimProduct_Id
		   		,vw.ClaimProduct
		   		,vw.Hospital_Id
		   		,vw.Hospital
		   		,vw.ClaimType_Id
		   		,vw.ClaimType
		   		,vw.AccidentCause_Id
		   		,vw.AccidentCause
		   		,vw.ICD10
		   		,vw.ICD10Detail
		    FROM sssPA.dbo.vw_ClaimHeaderDetail_For_DataExport  vw
		   	INNER JOIN @tmpClG t
				ON vw.Code = t.ClaimHeader_id
		UNION
			SELECT
				*
			FROM @tmpCliamMisc
	)#tmpDetal
		

	 SELECT 
			 ClaimCode
			,Product_Id
			,Product
			,Hospital_Id
			,Hospital
			,ClaimAdmitType_Id
			,ClaimAdmitType
			,ChiefComplain_id
			,ChiefComplain
			,ICD10
			,ICD10_Detail
			,URLLink
			,COUNT(ClaimCode) OVER() TotalCount
	 FROM #tmpDetal		
	   ORDER BY CASE WHEN @SortField IS NULL AND @OrderType IS NULL THEN ClaimCode END DESC 
		 OFFSET @IndexStart ROWS FETCH NEXT @PageSize ROWS ONLY
	
	DELETE FROM @tmpClG
	DROP TABLE #tmpDetal	

	 --SELECT 
		--	 N''					ClaimCode
		--	,N''					Product_Id
		--	,N''					Product
		--	,N''					Hospital_Id
		--	,N''					Hospital
		--	,N''					ClaimAdmitType_Id
		--	,N''					ClaimAdmitType
		--	,N''					ChiefComplain_id
		--	,N''					ChiefComplain
		--	,N''					ICD10
		--	,N''					ICD10_Detail
		--	,N''					URLLink
		--	,1						TotalCount




 
END



GO

/****** Object:  StoredProcedure [Claim].[usp_ClaimPayBackDetail_InsertV4]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Kittisak.Ph (อ้างอิง usp_ClaimPayBackDetail_InsertV3)
-- Description:	Add ClaimHospital and ClaimCompensate บันทึกตั้งเบิกเคลม
-- Create date: 2024-10-09
-- Update date: 2025-02-26 เพิ่มเช็คบันทึกสถานะส่งตั้งเบิกเฉพาะเคลมออนไลน์ 
-- Update date: 2025-08-11 Krekpon.D 
-- Description: ClaimGroupType 6 When is PA
-- Update date: 2025-09-02 08:57 Bunchuai Chaiket
-- Description: Change condition SELECT #TmpX IF InsCode = @InsuranceCompanyId SET GroupId = 2
-- Update date: 2025-10-21 13:48 Sorawit Kamlangsub
-- Description: Change to EXECUTE usp_ClaimPayBackDetail_InsertV5
-- Update date: 2025-10-22 13:48 Sorawit Kamlangsub
-- Description: Add ClaimMisc
-- Update date: 2025-11-06 Kittisak.Ph Add RoundNumber to ClaimWithdrawal
-- Update date: 2025-11-27 Sorawit Kamlangsub Add ClaimMisc
-- Update date: 2025-12-4 Sorawit Kamlangsub แก้ไข @TmpD เพิ่มขนาด Field ProductCode จาก 20 เป็น 255
-- Update date: 2025-12-9 Sorawit Kamlangsub แก้ไข ClaimMisc เพิ่ม Left Join DataCenterV1 ด้วย cm.InsCode เอา Organize_Id มาเก็บใน InsId
-- Update date: 2026-02-17 Sorawit Kamlangsub เพิ่ม ClaimPaymentTypeId
-- =============================================
CREATE PROCEDURE [Claim].[usp_ClaimPayBackDetail_InsertV4]
	@ClaimGroupCodeList		NVARCHAR(MAX)
	  , @ProductGroupId			INT
	  , @ClaimGroupTypeId		INT 
	  , @CreatedByUserId		INT 
AS
BEGIN
	
	SET NOCOUNT ON;

	-- Start Test --
	--DECLARE
	--@ClaimGroupCodeList		NVARCHAR(MAX) = 'BUHO-811-68110007-0'
	--  , @ProductGroupId			INT = 2
	--  , @ClaimGroupTypeId		INT = 2
	--  , @CreatedByUserId		INT = 1; 
	-- End Test --
	
	DECLARE @IsResult	BIT				= 1;
	DECLARE @Result		VARCHAR(100)	= '';
	DECLARE @Msg		NVARCHAR(500)	= '';

	IF @IsResult = 0 SET @Msg = 'Not allowed to use';

	DECLARE @D DATETIME						  = GETDATE()
	DECLARE @ProductGroupId_PH INT			  = 2	--PH
	DECLARE @ProductGroupId_PA INT			  = 3	--PA 
	DECLARE @CountDuplicate INT
	DECLARE @InsuranceCompanyCode VARCHAR(30) = '100000000041' --'100000000019'
	DECLARE @SMICutOffDate DATE				  = '2024-10-01'	--'2024-09-01'
	DECLARE @InsuranceCompanyId INT			  = 699804 


	DECLARE @TmpD TABLE (
		ClaimHeaderGroupCode VARCHAR(30),
		ProductGroupId INT,
		BranchCode VARCHAR(20),
		BranchId INT,
		ClaimGroupTypeId INT,
		InsCode VARCHAR(20),
		InsId INT,
		ClaimCode VARCHAR(20),
		Amount DECIMAL(16, 2),
		ProductCode VARCHAR(255),
		[Product] NVARCHAR(255),
		HospitalCode VARCHAR(20),
		Hospital NVARCHAR(255),
		ClaimAdmitTypeCode VARCHAR(20),
		ClaimAdmitType NVARCHAR(255),
		ChiefComplainCode VARCHAR(20),
		ChiefComplain NVARCHAR(max),
		ICD10Code VARCHAR(20),
		ICD10 NVARCHAR(max),
		ClaimOnLineCode VARCHAR(20),
		CustomerName NVARCHAR(255),
		AdmitDate DATETIME,
		SchoolName NVARCHAR(255),
		GroupId INT,
		ClaimPaymentTypeId INT
	);

	DECLARE @TmpGroup TABLE (
		ClaimGroupTypeId INT,
		BranchId INT,
		gId INT,
		sumPremium DECIMAL(16, 2),
		ClaimPaybackCode VARCHAR(50),
		GroupId int
	);

	DECLARE @TmpH TABLE (
		ClaimHeaderGroupCode VARCHAR(30),
		ClaimGroupTypeId INT,
		ProductGroupId INT,
		BranchId INT,
		InsId INT,
		ItemCount INT,
		SumAmount DECIMAL(16, 2),
		ClaimOnLineCode VARCHAR(20),
		hId INT,
		HospitalCode VARCHAR(20),
		GroupId INT,
		ClaimPaymentTypeId INT
	);

----------------Kittisak.Ph 2024-04-05-------------------------------------------
	DECLARE @TmpXClaim TABLE(
			ClaimOnLineId UNIQUEIDENTIFIER
			,ClaimOnLineItemId UNIQUEIDENTIFIER
			,ClaimCode NVARCHAR(50)
			,ClaimPay DECIMAL(16,2)
			,ClaimPayBackXClaimCreatedByUserId INT
			,ClaimPayBackXClaimCreatedDate DATETIME2
			,RoundNo int
		);
---------------------------------------------------------------------------------

	SELECT DISTINCT Element
	INTO #Tmplst
	from dbo.func_SplitStringToTable(@ClaimGroupCodeList,',');

	SELECT @CountDuplicate = COUNT(pb.ClaimGroupCode)
	FROM dbo.ClaimPayBackDetail  pb
	INNER JOIN #Tmplst lstrS
			   ON (pb.ClaimGroupCode = lstrS.Element)
	WHERE pb.IsActive = 1;


	IF @IsResult = 1
	BEGIN
		IF @CountDuplicate > 0
		BEGIN
			SET @IsResult = 0;
			SET @Msg = 'ClaimHeaderGroupCode Data duplication';
		END	
	END	

	IF @IsResult = 1
	BEGIN
	
		IF @ProductGroupId = 2 AND @ClaimGroupTypeId = 5
			BEGIN

				INSERT INTO @TmpD
				(
				    ClaimHeaderGroupCode
				  , ProductGroupId
				  , BranchId
				  , ClaimGroupTypeId
				  , InsCode
				  , InsId
				  , ClaimCode
				  , Amount
				  , ProductCode
				  , [Product]
				  , HospitalCode
				  , Hospital
				  , ClaimAdmitTypeCode
				  , ClaimAdmitType
				  , ChiefComplainCode
				  , ChiefComplain
				  , ICD10Code
				  , ICD10
				  , ClaimOnLineCode
				  , CustomerName
				  ,	AdmitDate
				  ,	SchoolName 
				  , GroupId 
				  , ClaimPaymentTypeId
				)
				SELECT ccg.ClaimCompensateGroupCode	ClaimHeaderGroupCode
					, @ProductGroupId				ProductGroupId
					, 70							BranchId
					, @ClaimGroupTypeId				ClaimGroupTypeId
					, cc.InsuranceCompanyCode		InsCode
					, o.Organize_ID					InsId
					, cc.ClaimHeaderCode			ClaimCode
					, cc.CompensateRemain			Amount
					, cc.ProductCode
					, p.Detail						[Product]
					, cc.HospitalCode				
					, hos.Detail					Hospital
					, cl.ClaimAdmitType_id			ClaimAdmitTypeCode
					, cat.Detail					ClaimAdmitType
					, cl.ChiefComplain_id			ChiefComplainCode
					, ccp.Detail					ChiefComplain
					, cl.ICD10_1					ICD10Code
					, icd.Detail_Thai				ICD10
					, cl.ClaimOnLineCode		
					, NULL
					, NULL
					, NULL
					,1		GroupId
					,3		ClaimPaymentTypeId
				FROM sss.dbo.ClaimCompensate cc
				INNER JOIN sss.dbo.ClaimCompensateGroup ccg
					ON cc.ClaimCompensateGroupId = ccg.ClaimCompensateGroupId
				INNER JOIN #Tmplst lst
					ON ccg.ClaimCompensateGroupCode = lst.Element
				LEFT JOIN sss.dbo.DB_ClaimHeader cl
					ON cc.ClaimHeaderCode = cl.Code
				LEFT JOIN DataCenterV1.Organize.Organize o
					ON cc.InsuranceCompanyCode = o.OrganizeCode
				LEFT JOIN sss.dbo.MT_Product p
					ON cc.ProductCode = p.Code
				LEFT JOIN sss.dbo.MT_Company hos
					ON cc.HospitalCode = hos.Code
				LEFT JOIN sss.dbo.MT_ClaimAdmitType cat
					ON cl.ClaimAdmitType_id = cat.Code
				LEFT JOIN sss.dbo.MT_ChiefComplain ccp
					ON cl.ChiefComplain_id = ccp.Code
				LEFT JOIN SSS.dbo.MT_ICD10 icd
					ON cl.ICD10_1 = icd.Code


				INSERT INTO @TmpGroup
				(
				    ClaimGroupTypeId
				  , BranchId
				  , gId
				  , sumPremium
				  ,GroupId
				)
				SELECT @ClaimGroupTypeId		ClaimGroupTypeId
					, 70						BranchId
					, 1							gId
					, SUM(Amount)				sumPremium
					,1
				FROM @TmpD
				GROUP BY ClaimGroupTypeId, BranchId


				INSERT INTO @TmpH
				(
				    ClaimHeaderGroupCode
				  , ClaimGroupTypeId
				  , ProductGroupId
				  , BranchId
				  , InsId
				  , ItemCount
				  , SumAmount
				  , ClaimOnLineCode
				  , hId
				  , HospitalCode
				  ,GroupId
				  ,ClaimPaymentTypeId
				)
				SELECT g.ClaimHeaderGroupCode
					, g.ClaimGroupTypeId
					, g.ProductGroupId
					, g.BranchId
					, g.InsId
					, s.ItemCount
					, s.SumAmount
					, s.ClaimOnLineCode
					, ROW_NUMBER() OVER(ORDER BY (g.ClaimHeaderGroupCode) asc ) hId
					, g.HospitalCode
					,1	GroupId
					,3	ClaimPaymentTypeId
				FROM
					(
						SELECT ClaimHeaderGroupCode
							, ClaimGroupTypeId
							, ProductGroupId 
							, BranchId
							, InsId
							, HospitalCode
						FROM @TmpD
						GROUP BY ClaimHeaderGroupCode
								, ClaimGroupTypeId
								, ProductGroupId
								, BranchId
								, InsId
								, HospitalCode

					)g
				LEFT JOIN 
					(
						SELECT ClaimHeaderGroupCode
							, COUNT(ClaimCode)		ItemCount
							, SUM(Amount)			SumAmount
							, MAX(ClaimOnLineCode)	ClaimOnLineCode
						FROM @TmpD
						GROUP BY ClaimHeaderGroupCode
					)s
					ON g.ClaimHeaderGroupCode = s.ClaimHeaderGroupCode		

                        END
        ELSE IF @ProductGroupId IN (4,11) AND @ClaimGroupTypeId = 7
                BEGIN
                                                                                        
                        INSERT INTO @TmpD
                        (
                            ClaimHeaderGroupCode
                          , ProductGroupId
                          , BranchCode
                          , BranchId
                          , ClaimGroupTypeId
                          , InsCode
                          , InsId
                          , ClaimCode
                          , Amount
                          , ProductCode
                          , [Product]
                          , HospitalCode
                          , Hospital
                          , ClaimAdmitTypeCode
                          , ClaimAdmitType
                          , ChiefComplainCode
                          , ChiefComplain
                          , ICD10Code
                          , ICD10
                          , ClaimOnLineCode
                          , CustomerName
                          , AdmitDate
                          , SchoolName
                          , GroupId
						  , ClaimPaymentTypeId
                        )
                        SELECT
                                cm.ClaimHeaderGroupCode
                                ,pd.ProductGroup_ID			ProductGroupId
                                ,NULL						BranchCode
                                ,cm.BranchId
                                ,@ClaimGroupTypeId			ClaimGroupTypeId
                                ,cm.InsuranceCompanyCode	InsCode
                                ,ins.Organize_ID			InsId
                                ,cm.ClaimMiscNo				ClaimCode
                                ,ISNULL(cm.PayAmount, 0)	Amount
                                ,cm.ProductCode
                                ,pd.ProductGroupDetail		[Product]
                                ,h.HospitalCode				HospitalCode
                                ,h.HospitalName				Hospital
                                ,NULL						ClaimAdmitTypeCode
                                ,cxa.ClaimAdmitType			ClaimAdmitType
                                ,NULL						ChiefComplainCode
                                ,c.ChiefComplainName		ChiefComplain
                                ,NULL						ICD10Code
                                ,NULL						ICD10
                                ,cm.ClaimOnLineCode
                                ,cm.CustomerName
                                ,cm.DateIn					AdmitDate
                                ,NULL						SchoolName
                                ,1							GroupId
								,cpbType.ClaimPaymentTypeId	ClaimPaymentTypeId
                        FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
                                LEFT JOIN [DataCenterV1].[Product].[ProductGroup] pd
                                        ON cm.ProductGroupId = pd.ProductGroup_ID
                                LEFT JOIN  
                                        (
                                                SELECT
                                                        HospitalId
                                                        ,HospitalName
                                                        ,HospitalCode
                                                FROM [ClaimMiscellaneous].[misc].[Hospital]
                                                WHERE IsActive = 1
                                        ) h
                                        ON h.HospitalId = cm.HospitalId
                                LEFT JOIN
                                        (
                                                SELECT
                                                        ChiefComplainId
                                                        ,ChiefComplainName
                                                FROM [ClaimMiscellaneous].[misc].[ChiefComplain]
                                                WHERE IsActive = 1
                                        ) c
                                        ON c.ChiefComplainId = cm.ChiefComplainId
                                INNER JOIN #Tmplst lst
                                        ON cm.ClaimHeaderGroupCode = lst.Element
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
								LEFT JOIN 
								(
									SELECT 
										OrganizeCode
										,Organize_ID
									FROM [DataCenterV1].[Organize].[Organize]
									WHERE IsActive = 1
								) ins
									ON ins.OrganizeCode = cm.InsuranceCompanyCode
								 LEFT JOIN (
									SELECT DISTINCT
									 h.ClaimMiscId
									 ,cp.ClaimPaymentTypeId
									 ,cp.ClaimPaymentTypeName
									FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] h
									 LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] p
									  ON h.ClaimMiscPaymentHeaderId = p.ClaimMiscPaymentHeaderId
									 LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimPaymentType] cp
									  ON cp.ClaimPaymentTypeId = p.ClaimPaymentTypeId
									 ) cpbType
								  ON cm.ClaimMiscId = cpbType.ClaimMiscId
									
                        WHERE cm.IsActive = 1                                        
                        SELECT x.ClaimHeaderGroupCode
                                  ,x.ProductGroupId
                                  ,x.BranchCode
                                  ,x.BranchId			BranchId
                                  ,x.ClaimGroupTypeId
                                  ,x.InsCode
                                  ,x.InsId				InsId
                                  ,x.ClaimCode
                                  ,x.ClaimOnLineCode
                                  ,1					GroupId
								  ,ClaimPaymentTypeId
                        INTO #TmpX2
                        FROM @TmpD x
                        INSERT INTO @TmpGroup
                        (
                            ClaimGroupTypeId
                          , BranchId
                          , gId
                          , sumPremium
                          ,GroupId
                        )
                        SELECT @ClaimGroupTypeId	ClaimGroupTypeId
                                , BranchId			BranchId
                                , 1					gId
                                , SUM(Amount)		sumPremium
                                ,1
                        FROM @TmpD
                        GROUP BY ClaimGroupTypeId, BranchId
                        INSERT INTO @TmpH
                        (
							ClaimHeaderGroupCode
                          , ClaimGroupTypeId
                          , ProductGroupId
                          , BranchId
                          , InsId
                          , ItemCount
                          , SumAmount
                          , ClaimOnLineCode
                          , hId
                          , HospitalCode
                          , GroupId
						  , ClaimPaymentTypeId
                        )
                        SELECT g.ClaimHeaderGroupCode
                                  ,g.ClaimGroupTypeId
                                  ,g.ProductGroupId
                                  ,g.BranchId
                                  ,g.InsId
                                  ,s.ItemCount
                                  ,s.SumAmount
                                  ,s.ClaimOnLineCode
                                  ,ROW_NUMBER() OVER(ORDER BY (g.ClaimHeaderGroupCode) asc ) hId
                                  ,s.HospitalCode
                                  ,GroupId
								  ,ClaimPaymentTypeId
                        FROM
                        (
                        SELECT ClaimHeaderGroupCode
                                        ,ClaimGroupTypeId
                                  ,ProductGroupId
                                  ,BranchId
                                  ,InsId
                                  ,GroupId
								  ,ISNULL(ClaimPaymentTypeId,3)	ClaimPaymentTypeId
                        FROM #TmpX2
                        GROUP BY ClaimHeaderGroupCode
                                        ,ClaimGroupTypeId
                                        ,ProductGroupId
                                        ,BranchId
                                        ,InsId
                                        ,GroupId
										,ClaimPaymentTypeId
                        )g
                        LEFT JOIN
                                (
                                        SELECT ClaimHeaderGroupCode
                                                        ,COUNT(ClaimCode)		ItemCount
                                                        ,SUM(Amount)			SumAmount
                                                        ,MAX(ClaimOnLineCode)	ClaimOnLineCode
                                                        ,HospitalCode
                                        FROM @TmpD
                                        GROUP BY ClaimHeaderGroupCode, HospitalCode
                                )s
                                ON g.ClaimHeaderGroupCode = s.ClaimHeaderGroupCode
					
			END
		ELSE
			BEGIN
			    
				SELECT x.ClaimHeaderGroupCode
					  ,x.ProductGroupId
					  ,x.BranchCode
					  ,b.Branch_ID			BranchId
					  ,x.ClaimGroupTypeId
					  ,x.InsCode
					  ,o.Organize_ID		InsId
					  ,x.ClaimCode
					  ,x.ClaimOnLineCode
					  ,CASE WHEN x.InsCode = @InsuranceCompanyCode AND x.CreatedDate >= @SMICutOffDate THEN 2
							--WHEN x.InsCode = @InsuranceCompanyCode AND @ClaimGroupTypeId = 4 THEN 2 AND @ClaimGroupTypeId = 2
						ELSE 1 END AS GroupId
				INTO #TmpX
				FROM
				( 
					SELECT 
							g.Code					ClaimHeaderGroupCode
							,@ProductGroupId_PH		ProductGroupId	--2PH 3PA
							,g.Branch_id			BranchCode
							,@ClaimGroupTypeId		ClaimGroupTypeId
							,g.InsuranceCompany_id	InsCode
							,i.ClaimHeader_id		ClaimCode
							,g.ClaimOnLineCode		ClaimOnLineCode
							,cl.CreatedDate	
	
					FROM sss.dbo.DB_ClaimHeaderGroupItem i
						INNER JOIN #Tmplst lst
							ON i.ClaimHeaderGroup_id = lst.Element
						INNER JOIN sss.dbo.DB_ClaimHeaderGroup g
							ON lst.Element = g.Code
						INNER JOIN sss.dbo.DB_ClaimHeader cl
						ON cl.Code = i.ClaimHeader_id
	
				UNION ALL
	
				SELECT
						g.Code					ClaimHeaderGroupCode
						,@ProductGroupId_PA		ProductGroupId	--2PH 3PA
						,g.Branch_id			BranchCode
						,CASE   
							WHEN @ClaimGroupTypeId = 3 AND ISNULL(g.IsClaimOnLine,0) = 0 THEN 3
							WHEN @ClaimGroupTypeId = 6 AND ISNULL(g.IsClaimOnLine,0) = 1 THEN 6 -- Krekpon.D 20250811 Update ClaimGroupType 6 When is PA
							WHEN ISNULL(g.IsClaimOnLine,0) = 1 THEN 2
							WHEN @ClaimGroupTypeId = 4 THEN 4
						 END ClaimGroupTypeId
						,g.InsuranceCompany_id	InsCode
						,i.ClaimHeader_id		ClaimCode
						,g.ClaimOnLineCode		ClaimOnLineCode
						,cl.CreatedDate
	
				FROM ssspa.dbo.DB_ClaimHeaderGroupItem i
					INNER JOIN #Tmplst lst
						ON i.ClaimHeaderGroup_id = lst.Element
					INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup g
						ON lst.Element = g.Code
					INNER JOIN SSSPA.dbo.DB_ClaimHeader cl
					ON cl.Code = i.ClaimHeader_id
				)x
					LEFT JOIN DataCenterV1.Organize.Organize o
						ON x.InsCode = o.OrganizeCode
					LEFT JOIN DataCenterV1.Address.Branch b
						ON x.BranchCode = b.tempcode;
	
	
				INSERT INTO @TmpD
				(
				    ClaimHeaderGroupCode
				  , ProductGroupId
				  , BranchCode
				  , BranchId
				  , ClaimGroupTypeId
				  , InsCode
				  , InsId
				  , ClaimCode
				  , Amount
				  , ProductCode
				  , [Product]
				  , HospitalCode
				  , Hospital
				  , ClaimAdmitTypeCode
				  , ClaimAdmitType
				  , ChiefComplainCode
				  , ChiefComplain
				  , ICD10Code
				  , ICD10
				  , ClaimOnLineCode
				  , CustomerName
				  ,	AdmitDate
				  ,	SchoolName 
				  , GroupId
				  , ClaimPaymentTypeId
				)
				SELECT d.ClaimHeaderGroupCode
					  ,d.ProductGroupId
					  ,d.BranchCode
					  ,d.BranchId
					  ,d.ClaimGroupTypeId
					  ,d.InsCode
					  ,d.InsId
					  ,d.ClaimCode
					  ,d.Amount
					  ,d.ProductCode
					  ,d.[Product]
					  ,d.HospitalCode
					  ,d.Hospital
					  ,d.ClaimAdmitTypeCode
					  ,d.ClaimAdmitType
					  ,d.ChiefComplainCode
					  ,d.ChiefComplain
					  ,d.ICD10Code
					  ,d.ICD10
					  ,d.ClaimOnLineCode
					  ,d.CustomerName
					  ,d.AdmitDate
					  ,d.SchoolName 
					  ,d.GroupId
					  ,d.ClaimPaymentTypeId
				FROM
				(
					SELECT 
							 lst.ClaimHeaderGroupCode
							,lst.ProductGroupId
							,lst.BranchCode
							,lst.BranchId
							,lst.ClaimGroupTypeId
							,lst.InsCode
							,lst.InsId
							,lst.ClaimCode
							--,(ISNULL(cv.Pay,0) + ISNULL(cv.Compensate_net,0) ) Amount
							--,IIF(ISNULL(cv.net,0) <> 0 ,ISNULL(cv.Pay_Total,0),ISNULL(cv.Compensate_net,0))  Amount  --เงื่อนไขใน บส.  ปรับให้ออกเหมือน บส. คอนเฟริมกับพี่โบว์แล้ว
							,ISNULL(cv.PaySS_Total,0)   Amount  -- เปลี่ยนไปใช้ PaySS_Total รวมหักส่วนลดแล้ว 20231227
							,cl.Product_id				ProductCode
							,p.Detail					[Product]
							,cl.Hospital_id				HospitalCode
							,hos.Detail					Hospital
							,cl.ClaimAdmitType_id		ClaimAdmitTypeCode
							,cat.Detail					ClaimAdmitType
							,cl.ChiefComplain_id		ChiefComplainCode
							,ccp.Detail					ChiefComplain
							,cl.ICD10_1					ICD10Code
							,icd.Detail_Thai			ICD10
							,lst.ClaimOnLineCode		ClaimOnLineCode	
							,ci.AdmitDate				AdmitDate								--Update Chanadol 2023-12-07
							,CONCAT(tt.Detail, cm.FirstName, ' ', cm.LastName)	 AS CustomerName --Update Chanadol 2023-12-07
							,NULL						SchoolName
							--,IIF(lst.InsCode ='100000000004' AND cl.CreatedDate <'2024-08-01', 1, 2) GroupId
							,CASE WHEN lst.InsCode = @InsuranceCompanyCode AND cl.CreatedDate >= @SMICutOffDate  THEN 2
								  --WHEN lst.InsCode =@InsuranceCompanyCode AND @ClaimGroupTypeId =4 THEN 2 AND @ClaimGroupTypeId = 2
							ELSE 1 END AS GroupId
							,3	ClaimPaymentTypeId
					FROM sss.dbo.DB_ClaimHeader cl
						INNER JOIN sss.dbo.DB_ClaimVoucher cv
							ON cl.Code = cv.Code
						INNER JOIN 
							(
								SELECT ClaimHeaderGroupCode
									  ,ProductGroupId
									  ,BranchCode
									  ,BranchId
									  ,ClaimGroupTypeId
									  ,InsCode
									  ,InsId
									  ,ClaimCode
									  ,ClaimOnLineCode
								FROM #TmpX
								WHERE ProductGroupId = 2
							)lst
							ON cl.Code = lst.ClaimCode
						LEFT JOIN sss.dbo.MT_Product p
							ON cl.Product_id = p.Code
						LEFT JOIN sss.dbo.MT_Company hos
							ON cl.Hospital_id = hos.Code
						LEFT JOIN sss.dbo.MT_ClaimAdmitType cat
							ON cl.ClaimAdmitType_id = cat.Code
						LEFT JOIN sss.dbo.MT_ChiefComplain ccp
							ON cl.ChiefComplain_id = ccp.Code
						LEFT JOIN SSS.dbo.MT_ICD10 icd
							ON cl.ICD10_1 = icd.Code
						-- Update Chanadol 2023-12-07
						LEFT JOIN SSS.dbo.DB_ClaimInvoice ci
							ON cl.Code = ci.ClaimHeader_id
						LEFT JOIN SSS.dbo.DB_Customer     cm
							ON cl.App_id = cm.App_id
						LEFT JOIN SSS.dbo.MT_Title        tt
							ON cm.Title_id = tt.Code
	
					UNION ALL
	
					SELECT 
							 lst.ClaimHeaderGroupCode
							,lst.ProductGroupId
							,lst.BranchCode
							,lst.BranchId
							,lst.ClaimGroupTypeId
							,lst.InsCode
							,lst.InsId
							,lst.ClaimCode
							--,ISNULL(cl.Amount_Net,0)	Amount
							,ISNULL(cl.PaySS_Total,0)	Amount -- 20231227
							,cl.Product_id				ProductCode
							,pp.Detail					[Product]
							,cl.Hospital_id				HospitalCode
							,hos.Detail					Hospital	
							,cl.ClaimType_id			ClaimAdmitTypeCode
							,clt.Detail					ClaimAdmitType
							,cl.AccidentCause_id		ChiefComplainCode
							,adc.Detail					ChiefComplain		
							,cl.ICD10_1					ICD10Code
							,icd.Detail_Thai			ICD10	
							,lst.ClaimOnLineCode		ClaimOnLineCode	
							,cl.DateIn					AdmitDate									--Update Chanadol 2023-12-07
							,CONCAT(tt.Detail, cd.FirstName, ' ', cd.LastName)	 AS CustomerName	--Update Chanadol 2023-12-07
							,CONCAT(ISNULL(c.CompanyTitle, ''), c.Detail)		 AS SchoolName	
							--,IIF(lst.InsCode ='100000000004' AND cl.CreatedDate <'2024-08-01', 1, 2) GroupId
							,CASE WHEN lst.InsCode =@InsuranceCompanyCode AND cl.CreatedDate >= @SMICutOffDate   THEN 2
								  -- WHEN lst.InsCode =@InsuranceCompanyCode AND @ClaimGroupTypeId = 4 THEN 2 AND @ClaimGroupTypeId = 2
							ELSE 1 END AS GroupId
							,3	ClaimPaymentTypeId
					FROM SSSPA.dbo.DB_ClaimHeader cl
						INNER JOIN 
							(
								SELECT ClaimHeaderGroupCode
									  ,ProductGroupId
									  ,BranchCode
									  ,BranchId
									  ,ClaimGroupTypeId
									  ,InsCode
									  ,InsId
									  ,ClaimCode
									  ,ClaimOnLineCode
								FROM #TmpX
								WHERE ProductGroupId = 3
							)lst
							ON cl.Code = lst.ClaimCode
						LEFT JOIN ssspa.dbo.SM_Code clt
							ON cl.ClaimType_id = clt.Code
						LEFT JOIN ssspa.dbo.MT_AccidentCause adc
							ON cl.AccidentCause_id = adc.Code
						--LEFT JOIN ssspa.dbo.vw_ICD10 icd
						--	ON cl.ICD10_1 = icd.Code
						LEFT JOIN SSS.dbo.MT_ICD10 icd
							ON cl.ICD10_1 = icd.Code
						LEFT JOIN sss.dbo.MT_Company hos
							ON cl.Hospital_id = hos.Code
						LEFT JOIN ssspa.dbo.MT_Product pp
							ON cl.Product_id =pp.Code
						--Update Chanadol 2023-12-07
						LEFT JOIN SSSPA.dbo.DB_CustomerDetail   cd
							ON cl.CustomerDetail_id = cd.Code
						LEFT JOIN SSSPA.dbo.MT_Title      tt
							ON cd.Title_id = tt.Code
						LEFT JOIN ssspa.dbo.DB_Customer			cm
							ON cd.Application_id = cm.App_id
						LEFT JOIN SSSPA.dbo.MT_Company c
							ON cm.School_id = c.Code
					)d;
	
					
				INSERT INTO @TmpGroup
				(
				    ClaimGroupTypeId
				  , BranchId
				  , gId
				  , sumPremium
				  ,GroupId
				)
				SELECT DISTINCT h.ClaimGroupTypeId
					  ,h.BranchId
					  ,s.gId
					  ,s.sumPremium
					  ,s.GroupId
				FROM
				(
					SELECT ClaimGroupTypeId
						  ,BranchId
						  ,GroupId
						  --,ROW_NUMBER() OVER(ORDER BY ClaimGroupTypeId ASC,BranchId ASC ) gId
					FROM #TmpX
					--GROUP BY ClaimGroupTypeId,BranchId
				)h
				LEFT JOIN 
					(
						--SELECT ClaimGroupTypeId,BranchId,SUM(Amount) sumPremium
						SELECT 
							ClaimGroupTypeId
							,BranchId
							,SUM(Amount) sumPremium
							,GroupId
							,ROW_NUMBER() OVER(ORDER BY ClaimGroupTypeId ASC,BranchId ASC ) gId
						FROM @TmpD
						GROUP BY ClaimGroupTypeId, BranchId, GroupId
					)s
						ON  h.ClaimGroupTypeId = s.ClaimGroupTypeId
							AND h.BranchId = s.BranchId;	
	
			--เคลมออนไลน์ ไม่ต้อง save HospitalCode Update --2023-12-12
			IF @ClaimGroupTypeId <> 2
				BEGIN
					    INSERT INTO @TmpH
						(
							ClaimHeaderGroupCode
						  , ClaimGroupTypeId
						  , ProductGroupId
						  , BranchId
						  , InsId
						  , ItemCount
						  , SumAmount
						  , ClaimOnLineCode
						  , hId
						  , HospitalCode
						  ,GroupId
						  ,ClaimPaymentTypeId
						)
						SELECT g.ClaimHeaderGroupCode
							  ,g.ClaimGroupTypeId
							  ,g.ProductGroupId
							  ,g.BranchId
							  ,g.InsId
							  ,s.ItemCount
							  ,s.SumAmount
							  ,s.ClaimOnLineCode
							  ,ROW_NUMBER() OVER(ORDER BY (g.ClaimHeaderGroupCode) asc ) hId
							  ,s.HospitalCode
							  ,GroupId
							  ,3	ClaimPaymentTypeId
						FROM
						(
						SELECT ClaimHeaderGroupCode
								,ClaimGroupTypeId
							  ,ProductGroupId
							  ,BranchId
							  ,InsId
							  ,GroupId
						FROM #TmpX
						GROUP BY ClaimHeaderGroupCode
								,ClaimGroupTypeId
								,ProductGroupId
								,BranchId
								,InsId
								,GroupId
						)g
						LEFT JOIN 
							(
								SELECT ClaimHeaderGroupCode
										,COUNT(ClaimCode)	ItemCount
										,SUM(Amount)		SumAmount
										,MAX(ClaimOnLineCode) ClaimOnLineCode
										,HospitalCode
								FROM @TmpD
								GROUP BY ClaimHeaderGroupCode, HospitalCode
							)s
							ON g.ClaimHeaderGroupCode = s.ClaimHeaderGroupCode
				END
				ELSE	
				BEGIN
				    INSERT INTO @TmpH
					(
						ClaimHeaderGroupCode
					  , ClaimGroupTypeId
					  , ProductGroupId
					  , BranchId
					  , InsId
					  , ItemCount
					  , SumAmount
					  , ClaimOnLineCode
					  , hId
					  ,GroupId
					  ,ClaimPaymentTypeId
					)
					SELECT g.ClaimHeaderGroupCode
						  ,g.ClaimGroupTypeId
						  ,g.ProductGroupId
						  ,g.BranchId
						  ,g.InsId
						  ,s.ItemCount
						  ,s.SumAmount
						  ,s.ClaimOnLineCode
						  ,ROW_NUMBER() OVER(ORDER BY (g.ClaimHeaderGroupCode) asc ) hId
						  ,GroupId
						  ,3	ClaimPaymentTypeId
					FROM
					(
					SELECT ClaimHeaderGroupCode
							,ClaimGroupTypeId
						  ,ProductGroupId
						  ,BranchId
						  ,InsId
						  ,GroupId
					FROM #TmpX
					GROUP BY ClaimHeaderGroupCode
							,ClaimGroupTypeId
							,ProductGroupId
							,BranchId
							,InsId
							,GroupId
					)g
						LEFT JOIN 
							(
								SELECT ClaimHeaderGroupCode
										,COUNT(ClaimCode)	ItemCount
										,SUM(Amount)		SumAmount
										,MAX(ClaimOnLineCode) ClaimOnLineCode
								FROM @TmpD
								GROUP BY ClaimHeaderGroupCode
							)s
							ON g.ClaimHeaderGroupCode = s.ClaimHeaderGroupCode
				END
			END		
		
	--Group
		DECLARE @g_TransactionCodeControlTypeDetail varchar(6) = 'CPBG'
		DECLARE @g_Total int
		DECLARE @g_YY varchar(2)
		DECLARE @g_MM varchar(2)
		DECLARE @g_RunningFrom int
		DECLARE @g_RunningTo INT
		DECLARE @g_lenght	INT = 6
		SELECT @g_Total = MAX(gId) 

		FROM @TmpGroup;
	
		EXECUTE [dbo].[usp_GenerateCode_FromTo] 
		   @g_TransactionCodeControlTypeDetail
		  ,@g_Total
		  ,@g_YY OUTPUT
		  ,@g_MM OUTPUT
		  ,@g_RunningFrom OUTPUT
		  ,@g_RunningTo OUTPUT
	
		--Header
		DECLARE @h_TransactionCodeControlTypeDetail varchar(6) = 'CPBH'
		DECLARE @h_Total int
		DECLARE @h_YY varchar(2)
		DECLARE @h_MM varchar(2)
		DECLARE @h_RunningFrom int
		DECLARE @h_RunningTo INT
		DECLARE @h_lenght	INT = 6
		SELECT @h_Total = MAX(hId)
		FROM @TmpH
	
		EXECUTE [dbo].[usp_GenerateCode_FromTo] 
		   @h_TransactionCodeControlTypeDetail
		  ,@h_Total
		  ,@h_YY OUTPUT
		  ,@h_MM OUTPUT
		  ,@h_RunningFrom OUTPUT
		  ,@h_RunningTo OUTPUT
	
		DECLARE @TmpOutGroup TABLE(ClaimGroupTypeId	INT,BranchId	INT,gId	INT,GroupId INT, ClaimPayBackCode VARCHAR(20))
		DECLARE @TmpOutD TABLE (ClaimHeaderGroupCode VARCHAR(50),cdId INT,ClaimPayBackId INT, ClaimCode VARCHAR(20),InsuranceCompanyId INT)
		DECLARE @TmpOutXClaim TABLE (ClaimCode VARCHAR(30),cxId INT,cdId INT) --Kittisak.Ph 2024-04-05
	
		-----------------------------------
		-- start process recheck
		DECLARE @CountDuplicateClaim INT;

		SELECT @CountDuplicateClaim = COUNT(pb.ClaimGroupCode)
		FROM dbo.ClaimPayBackDetail  pb
			INNER JOIN #Tmplst lstrS
				ON (pb.ClaimGroupCode = lstrS.Element)
		WHERE pb.IsActive = 1;
		IF @CountDuplicateClaim IS NULL SET @CountDuplicateClaim = 0;
	
		IF @CountDuplicateClaim > 0
		BEGIN
			SET @IsResult = 0
			SET @Msg = 'ClaimHeaderGroupCode Data Duplicate'
		END	


----------------Kittisak.Ph 2024-04-05-------------------------------------------
	--เคลมออนไลน์
	IF @ClaimGroupTypeId  IN (2,6,7)				--Update Chanadol 2025-02-26 
	BEGIN

	DECLARE @roundAmount INT = 5;
	DECLARE @lastNumber INT;
	DECLARE @startNumber INT;
	DECLARE @total INT;
	
	SELECT TOP 1 @lastNumber = cw.RoundNo
	FROM [ClaimOnlineV2].[dbo].ClaimWithdrawal cw
	WHERE cw.ClaimPayBackXClaimCreatedDate = (
		SELECT MAX(ClaimPayBackXClaimCreatedDate)
		FROM [ClaimOnlineV2].[dbo].ClaimWithdrawal
	)
	ORDER BY cw.RoundNo DESC;

	SELECT @total = COUNT(ClaimCode) from @TmpD

	--SELECT @lastNumber lastNumber
	SET @startNumber = ISNULL(@lastNumber, 0) + 1;
	--SELECT @startNumber
		
		--ปรับ IsActive รายการที่ส่งตั้งเบิกครั้งก่อน 2025-11-12 By Kittisak.Ph
		--SELECT *
		UPDATE cwd
		SET cwd.IsActive=0
		FROM ClaimOnlineV2.dbo.ClaimWithdrawal cwd
		INNER JOIN @TmpD tmpd 
		ON tmpd.ClaimCode = cwd.ClaimCode

	    INSERT INTO @TmpXClaim(
			ClaimOnLineId 
			,ClaimOnLineItemId 
			,ClaimCode 
			,ClaimPay 
			,ClaimPayBackXClaimCreatedByUserId 
			,ClaimPayBackXClaimCreatedDate 
			,RoundNo
		)
		SELECT
			ci.ClaimOnLineId
			,ci.ClaimOnLineItemId
			,d.ClaimCode
			,d.Amount ClaimPay
			,@CreatedByUserId AS ClaimPayBackXClaimCreatedByUserId
			,@D ClaimPayBackXClaimCreatedDate
			,(( (@startNumber - 1) + (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1) ) % @roundAmount) + 1	RoundNo
		FROM @TmpD d
			INNER JOIN ClaimOnlineV2.dbo.ClaimOnlineItem ci
				ON d.ClaimCode = ci.ClaimCode
		WHERE ci.IsActive = 1

	END
	ELSE	
	BEGIN
	    INSERT INTO @TmpXClaim(
			ClaimOnLineId 
			,ClaimOnLineItemId 
			,ClaimCode 
			,ClaimPay 
			,ClaimPayBackXClaimCreatedByUserId 
			,ClaimPayBackXClaimCreatedDate 
		)
		SELECT
			NULL
			,NULL
			,d.ClaimCode
			,d.Amount ClaimPay
			,@CreatedByUserId AS ClaimPayBackXClaimCreatedByUserId
			,@D ClaimPayBackXClaimCreatedDate
	FROM @TmpD d
	END
	
---------------------------------------------------------------------------------
	
		IF @IsResult = 1
		BEGIN
	    
	
		-----------------------------------
		BEGIN TRY
			Begin TRANSACTION
	
	
				INSERT INTO dbo.ClaimPayBack
						(ClaimPayBackCode
						,Amount
						,ClaimPayBackStatusId
						,ClaimGroupTypeId
						,BranchId
						,ClaimPayBackTransferId
						,IsActive
						,CreatedByUserId
						,CreatedDate
						,UpdatedByUserId
						,UpdatedDate
						,GroupId
						)
				OUTPUT Inserted.ClaimGroupTypeId,Inserted.BranchId,Inserted.ClaimPayBackId,Inserted.GroupId,Inserted.ClaimPayBackCode INTO @TmpOutGroup(ClaimGroupTypeId,BranchId,gId,GroupId,ClaimPayBackCode) --Update Chanadol 20241112
				SELECT 
						CONCAT(@g_TransactionCodeControlTypeDetail,@g_YY,@g_MM ,dbo.func_ConvertIntToString((@g_RunningFrom + ig.gId - 1),@g_lenght)) ClaimPayBackCode
						,ig.sumPremium					Amount
						--,2
						,IIF(ig.GroupId = 2, 5, 2)		ClaimPayBackStatusId
						,ig.ClaimGroupTypeId
						,ig.BranchId
						,NULL							ClaimPayBackTransferId
						,1								IsActive
						,@CreatedByUserId				CreatedByUserId
						,@D								CreatedDate
						,@CreatedByUserId				UpdatedByUserId
						,@D								UpdatedDate
						,ig.GroupId
				FROM @TmpGroup ig
				ORDER BY ig.gId;
			
			
				INSERT INTO dbo.ClaimPayBackDetail
						(ClaimPayBackDetailCode
						,ClaimPayBackId
						,ClaimGroupCode
						,ItemCount
						,Amount
						,ProductGroupId
						,InsuranceCompanyId
						,CancelRemark
						,IsActive
						,CreatedByUserId
						,CreatedDate
						,UpdatedByUserId
						,UpdatedDate
						,ClaimOnLineCode
						,HospitalCode
						,ClaimPaymentTypeId
						)
				OUTPUT Inserted.ClaimGroupCode,Inserted.ClaimPayBackDetailId,Inserted.ClaimPayBackId,Inserted.InsuranceCompanyId INTO @TmpOutD (ClaimHeaderGroupCode,cdId,ClaimPayBackId,InsuranceCompanyId)
				SELECT	
						CONCAT(@h_TransactionCodeControlTypeDetail,@h_YY,@h_MM ,dbo.func_ConvertIntToString((@h_RunningFrom + h.hId - 1),@h_lenght)) ClaimPayBackDetailCode
						,o.gId						ClaimPayBackId
						,h.ClaimHeaderGroupCode		ClaimGroupCode
						,h.ItemCount
						,h.SumAmount				Amount
						,h.ProductGroupId
						,h.InsId					InsuranceCompanyId
						,NULL						CancelRemark
						,1							IsActive
						,@CreatedByUserId			CreatedByUserId
						,@D							CreatedDate
						,@CreatedByUserId			UpdatedByUserId
						,@D							UpdatedDate
						,h.ClaimOnLineCode
						,h.HospitalCode
						,h.ClaimPaymentTypeId
				FROM @TmpH h
					LEFT JOIN @TmpOutGroup o
						ON h.ClaimGroupTypeId = o.ClaimGroupTypeId
						AND h.BranchId = o.BranchId AND o.GroupId = h.GroupId
				ORDER BY h.hId;
			
			
				INSERT INTO dbo.ClaimPayBackXClaim
						(ClaimPayBackDetailId
						,ClaimCode
						,ProductCode
						,ProductName
						,HospitalCode
						,HospitalName
						,ClaimAdmitTypeCode
						,ClaimAdmitType
						,ChiefComplainCode
						,ChiefComplain
						,ICD10Code
						,ICD10
						,ClaimPay
						,ClaimTransfer
						,IsActive
						,CreatedByUserId
						,CreatedDate
						,UpdatedByUserId
						,UpdatedDate
						,CustomerName
						,AdmitDate
						,SchoolName)
						OUTPUT Inserted.ClaimCode,Inserted.ClaimPayBackXClaimId,Inserted.ClaimPayBackDetailId INTO @TmpOutXClaim (ClaimCode,cxId,cdId) --Kittisak.Ph 2024-04-05
				SELECT o.cdId					ClaimPayBackDetailId
						,d.ClaimCode
						,d.ProductCode
						,d.[Product]			ProductName
						,d.HospitalCode
						,d.Hospital				HospitalName
						,d.ClaimAdmitTypeCode
						,d.ClaimAdmitType
						,d.ChiefComplainCode
						,d.ChiefComplain
						,d.ICD10Code
						,d.ICD10
						,d.Amount				ClaimPay
						,0						ClaimTransfer
						,1						IsActive
						,@CreatedByUserId		CreatedByUserId
						,@D						CreatedDate
						,@CreatedByUserId		UpdatedByUserId
						,@D						UpdatedDate
						,d.CustomerName				
						,d.AdmitDate
						,d.SchoolName
				FROM @TmpD d
					LEFT JOIN @TmpOutD o
						ON d.ClaimHeaderGroupCode = o.ClaimHeaderGroupCode
				ORDER BY o.cdId;
	
----------------Kittisak.Ph 2024-04-05-------------------------------------------
--บันทึกสถานะส่งตั้งเบิกเฉพาะเคลมออนไลน์ 
	IF @ClaimGroupTypeId IN (2,7)				--Update Kittisak.Ph 2025-02-25 
	BEGIN

		INSERT INTO [ClaimOnlineV2].[dbo].[ClaimWithdrawal]
		(
		[ClaimWithdrawalId]
      ,[ClaimOnLineId]
      ,[ClaimOnLineItemId]
      ,[ClaimPayBackXClaimId]
      ,[ClaimCode]
      ,[ClaimPay]
      ,[IsActive]
      ,[ClaimPayBackXClaimCreatedByUserId]
      ,[ClaimPayBackXClaimCreatedDate]
      ,[RoundNo]
	  )
		SELECT NEWID()							ClaimWithdrawalId
		,ClaimOnLineId
			,ClaimOnLineItemId
			,x.cxId								ClaimPayBackXClaimId
			,tx.ClaimCode
			,tx.ClaimPay
			,1									IsActive
			,ClaimPayBackXClaimCreatedByUserId
			,ClaimPayBackXClaimCreatedDate
			,tx.RoundNo
		FROM @TmpXClaim tx
		LEFT JOIN @TmpOutXClaim x ON tx.ClaimCode = x.ClaimCode

	END

---------------------------------------------------------------------------------

------------------------------------- Krekpon.D Mind 06588 2024-06-27 -------------------------------------------
	IF @ClaimGroupTypeId = 4
		BEGIN
				INSERT INTO [dbo].[ClaimPayBackDetailReport]
		           ([ClaimGroupCode]
		           ,[HospitalName]
		           ,[ClaimCode]
		           ,[CustomerName]
		           ,[Amount]
		           ,[SendDate]
		           ,[PaymentDate]
		           ,[ClaimGroupTypeId]
		           ,[IsActive]
		           ,[CreatedByUserId]
		           ,[CreatedDate]
		           ,[UpdatedByUserId]
		           ,[UpdatedDate])
				SELECT  claimD.Code AS ClaimGroupCode,
							sssHospital.Detail AS HospitalName,
							claimD.CLCode AS ClaimCode,
							claimD.CustomerName AS CustomerName,
							claimD.Amount AS Amount,
							GETDATE()  AS SendDate,
							NULL AS PaymentDate,
							@ClaimGroupTypeId AS ClaimGroupTypeId,
							1 AS IsActive,
							@CreatedByUserId AS CreatedByUserId,
							GETDATE() AS CreatedDate,
							@CreatedByUserId AS UpdatedByUserId,
							GETDATE() AS UpdatedDate
					 FROM (
					
							SELECT chg.Code AS Code
								, chg.Hospital_id AS Hospital_id
								, sch.Code AS CLCode
								, scv.PaySS_Total AS Amount
								,CONCAT(mtt.Detail, cust.FirstName, ' ' , cust.LastName ) AS CustomerName
							 
					        FROM sss.dbo.DB_ClaimHeaderGroup chg
					         INNER JOIN sss.dbo.DB_ClaimHeader sch
								ON chg.code = sch.ClaimHeaderGroup_id 
					         INNER JOIN sss.dbo.DB_Customer cust
								ON sch.App_id = cust.App_id
					         INNER JOIN sss.dbo.MT_Title mtt
								ON cust.Title_id = mtt.Code
					         INNER JOIN sss.dbo.DB_ClaimVoucher scv
								ON sch.code = scv.Code
							 INNER JOIN #Tmplst tchc
								ON chg.Code = tchc.Element
				
					        UNION ALL
					
					        SELECT pachg.Code AS Code
					         , pachg.Hospital_id AS Hospital_id
					         , pach.Code AS CLCode
							 , pach.PaySS_Total AS Amount
					         ,CONCAT(pamtt.Detail, pacustd.FirstName, ' ' , pacustd.LastName ) AS CustomerName
				
					        FROM SSSPA.dbo.DB_ClaimHeaderGroup pachg
								INNER JOIN SSSPA.dbo.DB_ClaimHeader pach
									ON pachg.Code = pach.ClaimheaderGroup_id
								INNER JOIN SSSPA.dbo.DB_CustomerDetail pacustd
									ON pach.CustomerDetail_id = pacustd.Code
								INNER JOIN SSSPA.dbo.MT_Title pamtt
									ON pacustd.Title_id = pamtt.Code
								INNER JOIN #Tmplst tchc
									ON pachg.Code = tchc.Element 
						) claimD
							INNER JOIN SSS.dbo.MT_Company sssHospital
								ON claimD.Hospital_id = sssHospital.Code
				
					IF OBJECT_ID('tempdb..#TmpClaimHeaderCode') IS NOT NULL  DROP TABLE #TmpClaimHeaderCode;
					
			END		
-----------------------------------------------------------------------------------------------------------

			SET @IsResult	= 1;
			SET @Msg		= 'บันทึก สำเร็จ';
	
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
	
			SET @IsResult	= 0;
			SET @Msg		= ERROR_MESSAGE()
	
			IF @@Trancount > 0 ROLLBACK;
		END CATCH

		END
	END


	IF @IsResult = 1 BEGIN	SET @Result = IIF(1=0,1,0) END	
	ELSE BEGIN				SET @Result = 'Failure' END;	

	--SELECT @IsResult IsResult
	--		,@Result Result
	--		,@Msg	 Msg; 

	SELECT DISTINCT @IsResult IsResult
		,@Result Result
		,@Msg	 Msg
		,txc.ClaimOnLineId
		,txc.ClaimOnLineItemId
		,tog.ClaimPayBackCode
		,tod.ClaimHeaderGroupCode   ClaimGroupCode
		,toc.cxId					ClaimPayBackXClaimId
		,txc.ClaimCode
		,txc.ClaimPay
		,5 AS ReceiveTypeId
		,9 AS TransferTypeId ----SMI โอนให้ลูกค้า
		,tod.InsuranceCompanyId
		,@CreatedByUserId AS UpdatedByUserId		
		,@D AS UpdatedDate 
	FROM @TmpOutGroup tog
	LEFT JOIN @TmpOutD tod
		ON tog.gId = tod.ClaimPayBackId AND	tod.InsuranceCompanyId = @InsuranceCompanyId
	LEFT JOIN @TmpOutXClaim toc
		ON tod.cdId = toc.cdId
	LEFT JOIN @TmpXClaim txc
		ON toc.ClaimCode = txc.ClaimCode
	--INNER JOIN dbo.vw_ClaimOnlineItem vcol
	--	ON txc.ClaimCode = vcol.ClaimCode
	--WHERE tod.InsuranceCompanyId = @InsuranceCompanyId

	IF OBJECT_ID('tempdb..#TmpX') IS NOT NULL  DROP TABLE #TmpX;	
	IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;	
	IF OBJECT_ID('tempdb..#TmpX2') IS NOT NULL  DROP TABLE #TmpX2;

	IF OBJECT_ID('tempdb..@TmpH') IS NOT NULL  DELETE FROM @TmpH;	
	IF OBJECT_ID('tempdb..@TmpGroup') IS NOT NULL  DELETE FROM @TmpGroup;	
	IF OBJECT_ID('tempdb..@TmpD') IS NOT NULL  DELETE FROM @TmpD;

	--DECLARE @N INT = NULL;
	--DECLARE @G UNIQUEIDENTIFIER
	--DECLARE @DE DECIMAL(16, 2)

	--SELECT DISTINCT @IsResult IsResult
	--	,@Result Result
	--	,@Msg	 Msg
	--	,@G ClaimOnLineId
	--	,@G ClaimOnLineItemId
	--	,'' ClaimPayBackCode
	--	,'' ClaimGroupCode
	--	,@N	ClaimPayBackXClaimId
	--	,''	ClaimCode
	--	,@DE ClaimPay
	--	,1 ReceiveTypeId
	--	,1 TransferTypeId
	--	,@N InsuranceCompanyId
	--	,1 UpdatedByUserId		
	--	,@D AS UpdatedDate 

	END
GO

/****** Object:  StoredProcedure [dbo].[usp_BillingRequest_ClaimMisc_Insert]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Sorawit Kamlangsub
-- Create date: 2025-12-16  15:43
-- Update date: Sorawit Kamlangsub 2026-01-29 17:00
--				เปลี่ยนเลขรัน BQG 5 หลัก
-- Description:
-- =============================================
CREATE PROCEDURE [dbo].[usp_BillingRequest_ClaimMisc_Insert]
		@GroupTypeId				INT
		,@ClaimTypeCode				VARCHAR(20)
		,@InsuranceCompanyId		INT
		,@CreatedByUserId			INT
		,@BillingDate				DATE
		,@ClaimHeaderGroupTypeId	INT
		,@InsuranceCompanyName		NVARCHAR(300)
		,@NewBillingDate			DATE
		,@CreatedDateFrom			DATE
		,@CreatedDateTo				DATE
		,@ProductTypeShortName		VARCHAR(20)
		,@ProductTypeId				INT

AS
BEGIN
	SET NOCOUNT ON;

--DECLARE
--		@GroupTypeId				INT				= 3
--		,@ClaimTypeCode				VARCHAR(20)		= '2000'
--		,@InsuranceCompanyId		INT				= 18
--		,@CreatedByUserId			INT				= 6772
--		,@BillingDate				DATE			= '2025-12-16'
--		,@ClaimHeaderGroupTypeId	INT				= 6
--		,@InsuranceCompanyName		NVARCHAR(300)	= 'บริษัท ชับบ์สามัคคีประกันภัย จำกัด (มหาชน)'
--		,@NewBillingDate			DATE			= '2025-12-16'
--		,@CreatedDateFrom			DATE			= '2025-12-16'
--		,@CreatedDateTo				DATE			= '2025-12-16'
--		,@ProductTypeShortName		VARCHAR(20)		= 'SP'
--		,@ProductTypeId				INT				= 32	
--		;


DECLARE @IsResult	BIT			 = 1;
DECLARE @Result		VARCHAR(100) = '';
DECLARE @Msg		NVARCHAR(500)= '';

IF (@IsResult = 0) SET @Msg = N'ปิดใช้งาน';

DECLARE @productShortName VARCHAR(20)			= @ProductTypeShortName;
DECLARE @productId VARCHAR(20)					= @ProductTypeId;
DECLARE @pGroupTypeId			INT				= @GroupTypeId;
DECLARE @pInsuranceCompanyId	INT				= @InsuranceCompanyId;
DECLARE @UserId					INT				= @CreatedByUserId;

DECLARE @D2						DATETIME2		= SYSDATETIME();

DECLARE @Date					DATE = @D2;

DECLARE	@BillindDueDate			DATE;
DECLARE @DaysToAdd				INT				= 15;
DECLARE @TransactionDetail		NVARCHAR(500)	= N'Generate Group เสร็จสิ้น';

--IF @CreatedDateTo IS NOT NULL SET @CreatedDateTo = DATEADD(DAY,1,@CreatedDateTo);

SET @BillindDueDate = DATEADD(	DAY
								,@DaysToAdd + ((@DaysToAdd - 1) / 5) * 2 
								+ CASE 
									WHEN DATEPART(WEEKDAY, @NewBillingDate) + (@DaysToAdd - 1) % 5 >= 7 THEN 1
									WHEN DATEPART(WEEKDAY, @NewBillingDate) = 6 AND (@DaysToAdd - 1) % 5 = 0 THEN 1
									ELSE 0 
									END
								,@NewBillingDate);

IF (@IsResult = 0) SET @Msg = N'ปิดใช้งาน';

/*SetUp Tmplst*/
	SELECT	
		i.ClaimHeaderGroupImportId
		,i.ClaimHeaderGroupCode
		,i.ClaimHeaderGroupImportStatusId
		,i.InsuranceCompanyId
		,i.BillingRequestGroupId
		,f.ClaimHeaderGroupTypeId
		,cm.ProductTypeId
		,ROW_NUMBER() OVER(ORDER BY ClaimHeaderGroupImportId ASC) rwId
		,i.TotalAmount
	INTO #Tmplst
	FROM dbo.ClaimHeaderGroupImport i
		INNER JOIN dbo.ClaimHeaderGroupImportFile f
			ON i.ClaimGroupImportFileId = f.ClaimHeaderGroupImportFileId
		INNER JOIN 
		(
			SELECT
				cm.ClaimHeaderGroupCode
				,cm.ProductTypeId
				,pt.ProductTypeShortName
			FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
				LEFT JOIN [ClaimMiscellaneous].[misc].[ProductType] pt
					ON pt.ProductTypeId = cm.ProductTypeId
			WHERE cm.IsActive = 1
		) cm
			ON cm.ClaimHeaderGroupCode = i.ClaimHeaderGroupCode
	WHERE f.IsActive = 1
	AND i.IsActive = 1
	AND i.ClaimHeaderGroupImportStatusId = 2
	AND i.BillingRequestGroupId IS NULL
	AND i.InsuranceCompanyId = @pInsuranceCompanyId
	AND (i.ClaimTypeCode = @ClaimTypeCode)
	AND	i.CreatedDate >= @CreatedDateFrom
	AND	i.CreatedDate < @CreatedDateTo
	AND f.ClaimHeaderGroupTypeId = @ClaimHeaderGroupTypeId
	AND cm.ProductTypeId = @productId

/*SetUp TmpX*/
	SELECT	
		d.ClaimHeaderGroupImportDetailId
		,d.ClaimHeaderGroupImportId
		,d.ClaimCode
		,d.PaySS_Total
		,d.ClaimHeaderGroupCode
		,lst.TotalAmount
	INTO #TmpX
	FROM dbo.ClaimHeaderGroupImportDetail d
		INNER JOIN #Tmplst lst
			ON d.ClaimHeaderGroupImportId = lst.ClaimHeaderGroupImportId
	WHERE d.IsActive = 1;

/*SetUp TmpCover*/
	SELECT	
		d.BillingRequestResultDetailId
		,d.ClaimCode
		,d.CoverAmount
	INTO #TmpCover
	FROM dbo.BillingRequestResultDetail d
		INNER JOIN dbo.BillingRequestResultHeader h
			ON d.BillingRequestResultHeaderId = h.BillingRequestResultHeaderId
		LEFT JOIN 
		(
			SELECT cs.ClaimCompensateCode
				,cs.ClaimHeaderCode
			FROM SSS.dbo.ClaimCompensate cs
			WHERE cs.IsActive = 1	
		)cs
			ON d.ClaimCode = cs.ClaimHeaderCode
		INNER JOIN #TmpX x
			ON d.ClaimCode = x.ClaimCode
		INNER JOIN dbo.ClaimHeaderGroupImportDetail cid
			ON cid.ClaimHeaderGroupImportDetailId = d.ClaimHeaderGroupImportDetailId
		INNER JOIN dbo.ClaimHeaderGroupImport ci
			ON ci.ClaimHeaderGroupImportId = cid.ClaimHeaderGroupImportId
	WHERE h.IsActive = 1
		AND	d.IsActive = 1
		AND ci.IsActive = 1
		AND cid.IsActive = 1
		AND	
		(
			@ClaimHeaderGroupTypeId IN (2,4)
			OR
			@ClaimHeaderGroupTypeId NOT IN (2,4) AND cs.ClaimCompensateCode IS NULL
		);

/*SetUp Sort*/
SELECT 
	d.*
    ,''	P1
    ,0	P2
    ,0	P3
    ,0	P4
INTO #TmpX2
FROM #TmpX d;

/*SetUp TmpDetail*/
	SELECT	
		d.ClaimHeaderGroupImportDetailId
		,d.ClaimHeaderGroupImportId
		,d.ClaimCode
		,d.TotalAmount							 PaySS_Total
		,ISNULL(c.SumCover,0)					 SumCover
		,(d.TotalAmount - ISNULL(c.SumCover,0))  TotalAmount
		,ROW_NUMBER() OVER (ORDER BY d.P1, d.P2, d.P3, d.P4) AS rwId
		,d.ClaimHeaderGroupCode
	INTO #TmpDetail
	FROM #TmpX2 d
		LEFT JOIN 
		(
			SELECT ClaimCode
					,SUM(CoverAmount)	 SumCover
			FROM #TmpCover 
			GROUP BY ClaimCode
		) c
			ON d.ClaimCode = c.ClaimCode
	ORDER BY
		d.P1, d.P2, d.P3, d.P4;

IF (@IsResult = 1)
BEGIN

	DECLARE @Code_G	VARCHAR(20);
	DECLARE @Code_D	VARCHAR(20);
	
	DECLARE @Last2numbersOfInsurance VARCHAR(2);
	DECLARE @ClaimHeaderGroupCodeIndex3 VARCHAR(1);
	DECLARE @ClaimType VARCHAR(1);
	DECLARE @InsuranceCompanyCode VARCHAR(30);
	DECLARE @IsSFTP BIT = 0;

	SELECT 
		@InsuranceCompanyCode = o.OrganizeCode 
		,@IsSFTP =
			CASE 
				WHEN sfd.SFTPConfigId IS NOT NULL THEN 
					CASE 
						WHEN p.IsSFTP = 1 THEN 1
						WHEN p.IsSFTP = 0 THEN 0
					ELSE 1
				END
			ELSE 0
		END
	FROM DataCenterV1.Organize.Organize o
			LEFT JOIN (
				SELECT
					InsuranceCompanyCode
					,SFTPConfigId
				FROM dbo.SFTPConfig 
				WHERE IsActive = 1
			)sfd
				ON sfd.InsuranceCompanyCode = o.OrganizeCode
			LEFT JOIN (
				SELECT 
					InsuranceCompanyCode
					,ProductTypeId
					,IsSFTP
				FROM dbo.SFTPConfigProduct
				WHERE IsActive = 1
				AND ProductTypeId = @ClaimHeaderGroupTypeId
			) p
				ON p.InsuranceCompanyCode = o.OrganizeCode
	WHERE o.Organize_ID = @InsuranceCompanyId

	SET @Last2numbersOfInsurance = RIGHT(@InsuranceCompanyCode,2);

	SELECT @ClaimHeaderGroupCodeIndex3 = (SELECT TOP(1) RIGHT(LEFT(ClaimHeaderGroupCode, 4) ,1) FROM #Tmplst);

	IF (@ClaimHeaderGroupCodeIndex3 = 'H' or @ClaimHeaderGroupTypeId = 4)
	BEGIN
		SET @ClaimType= 'H'
	END
	ELSE
	BEGIN
		SET @ClaimType= 'B'
	END;

	SET @Code_G = CONCAT('BQG',@productShortName, @Last2numbersOfInsurance, @ClaimType)
	SET @Code_D = CONCAT('BQI',@productShortName)
	
	DECLARE @G_RunningLenght			INT			= 3
	DECLARE @G_TT						VARCHAR(8)	= @Code_G;
	DECLARE @BillingRequestGroupCode	VARCHAR(20)
	
	DECLARE @D_Lenght					INT			= 6;
	DECLARE @D_TT						VARCHAR(6)	= @Code_D;
	DECLARE @D_Total					INT			= (SELECT MAX(rwId) FROM #TmpDetail);
	DECLARE @D_YY						VARCHAR(2)
	DECLARE @D_MM						VARCHAR(2)
	DECLARE @D_RunningFrom				INT
	DECLARE @D_RunningTo				INT
	
	DECLARE @Offset INT = 0;
	DECLARE @BatchSize INT = @D_Total;
	DECLARE @TotalRows INT = 1;

/*Check SFTP For Loop */
	IF @IsSFTP = 0
	BEGIN 
		SET @TotalRows = @D_Total;
		SET @BatchSize = 20;
		SET @G_RunningLenght = 5;
	END
	
/* Generate Code */
		EXECUTE dbo.usp_GenerateCode_FromTo 
				 @D_TT
				,@D_Total
				,@D_YY OUTPUT
				,@D_MM OUTPUT
				,@D_RunningFrom OUTPUT
				,@D_RunningTo OUTPUT

			SELECT	
				CONCAT(@D_TT, @D_YY, @D_MM, dbo.func_ConvertIntToString((@D_RunningFrom + rwId - 1), @D_Lenght))	BillingRequestItemCode
				,*
			INTO #TmpDt_
			FROM #TmpDetail;

		SET @D2 = GETDATE();
	-----------------------------------
	BEGIN TRY
		Begin TRANSACTION

	WHILE @Offset < @TotalRows
	BEGIN
		DECLARE @ItemCount		INT = NULL;
		DECLARE @PaySS_Total	DECIMAL(16,2);
		DECLARE @CoverAmount	DECIMAL(16,2);

		SELECT	@ItemCount		= COUNT(ClaimHeaderGroupImportDetailId)
				,@PaySS_Total	= SUM(PaySS_Total)
				,@CoverAmount	= SUM(SumCover)
		FROM	#TmpDetail	
		WHERE rwId > @Offset 
			AND rwId <= @Offset + @BatchSize;

		SET @BillingRequestGroupCode = NULL;
		DECLARE @BillingRequestGroupId INT = NULL;

/* Generate Code */
		IF @IsSFTP = 0
		BEGIN 
			
			EXECUTE dbo.usp_GenerateCodeV2 
					 @G_TT
					,@G_RunningLenght
					,@BillingRequestGroupCode OUTPUT;

		END
		ELSE
		BEGIN
			EXECUTE dbo.usp_GenerateCode 
					 @G_TT
					,@G_RunningLenght
					,@BillingRequestGroupCode OUTPUT;
		END

			--EXECUTE dbo.usp_GenerateCode 
			--		 @G_TT
			--		,@G_RunningLenght
			--		,@BillingRequestGroupCode OUTPUT;

/* Insert BillingRequestGroup*/
			INSERT INTO dbo.BillingRequestGroup
			        (BillingRequestGroupCode
			        ,InsuranceCompanyId
			        ,ItemCount
			        ,PaySS_Total
			        ,CoverAmount
			        ,TotalAmount
			        ,BillingRequestGroupStatusId
			        ,BillingDate
			        ,IsActive
			        ,CreatedDate
			        ,CreatedByUserId
			        ,UpdatedDate
			        ,UpdatedByUserId
					,ClaimTypeCode
					,BillingDueDate
					,ClaimHeaderGroupTypeId
					,InsuranceCompanyName)
			SELECT @BillingRequestGroupCode				BillingRequestGroupCode
					,@InsuranceCompanyId				InsuranceCompanyId
					,@ItemCount							ItemCount
					,@PaySS_Total						PaySS_Total
					,@CoverAmount						CoverAmount
					,(@PaySS_Total - @CoverAmount)		TotalAmount
					,2									BillingRequestGroupStatusId
					,@NewBillingDate					BillingDate
					,1									IsActive
					,@D2								CreatedDate
					,@UserId							CreatedByUserId
					,@D2								UpdatedDate
					,@UserId							UpdatedByUserId
					,@ClaimTypeCode						ClaimTypeCode
					,@BillindDueDate					BillindDueDate
					,@ClaimHeaderGroupTypeId			ClaimHeaderGroupTypeId
					,@InsuranceCompanyName	
				
			SET @BillingRequestGroupId = SCOPE_IDENTITY();				
			
/* Insert BillingRequestItem */
			INSERT INTO dbo.BillingRequestItem
			        (BillingRequestItemCode
			        ,BillingRequestGroupId
			        ,ClaimHeaderGroupImportDetailId
			        ,PaySS_Total
			        ,CoverAmount
			        ,AmountTotal
			        ,IsActive
			        ,CreatedDate
			        ,CreatedByUserId
			        ,UpdatedDate
			        ,UpdatedByUserId)
			SELECT	
				i.BillingRequestItemCode
				,@BillingRequestGroupId				BillingRequestGroupId
				,i.ClaimHeaderGroupImportDetailId
				,i.PaySS_Total						PaySS_Total
				,i.SumCover							CoverAmount
				,i.TotalAmount						AmountTotal
				,1									IsActive
				,@D2								CreatedDate
				,@UserId							CreatedByUserId
				,@D2								UpdatedDate
				,@UserId							UpdatedByUserId
			FROM #TmpDt_ i
			WHERE i.rwId > @Offset 
				AND i.rwId <= @Offset + @BatchSize;
	
/* Update ClaimHeaderGroupImport */
			--SELECT *
			UPDATE	m 
				SET m.ClaimHeaderGroupImportStatusId	= 3
				,m.BillingRequestGroupId			= @BillingRequestGroupId
				,m.UpdatedDate						= @D2
				,m.UpdatedByUserId					= @UserId
				,m.BillingDate						= @NewBillingDate
			FROM dbo.ClaimHeaderGroupImport m
				INNER JOIN #Tmplst u
					ON m.ClaimHeaderGroupImportId = u.ClaimHeaderGroupImportId
			WHERE u.rwId > @Offset 
				AND u.rwId <= @Offset + @BatchSize ;
				
/* Insert BillingRequestGroupXResultDetail */
			INSERT INTO dbo.BillingRequestGroupXResultDetail
					(BillingRequestGroupId
					,BillingRequestResultDetailId)
			SELECT	
				@BillingRequestGroupId			BillingRequestGroupId
				,i.BillingRequestResultDetailId
			FROM #TmpCover i;

/* Insert BillingExport */
			INSERT INTO ClaimPayBack.dbo.BillingExport
					(BillingDate
					,BillingDueDate
					,BranchCode
					,Branch
					,ClaimHeaderGroupCode
					,PolicyNo
					,ApplicationCode
					,ClaimCode
					,Province
					,SchoolName
					,CustomerDetailCode
					,IdentityCard
					,CustName
					,SchoolLevel
					,DateHappen
					,Accident
					,ChiefComplain
					,Orgen
					,Pay
					,Compensate_Include
					,Compensate_Out
					,Amount_Pay
					,Amount_Dead
					,Pay_Total
					,ClaimAdmitType
					,HospitalId
					,HospitalName
					,ICD10_1Code
					,ICD10
					,Remark
					,DateIn
					,DateOut
					,ClaimType
					,BillingRequestGroupCode
					,BillingRequestItemCode
					,DocumentLink
					,InsuranceCompanyId
					,InsuranceCompanyName
					,StartCoverDate
					,IPDCount
					,ICUCount
					,ClaimHeaderGroupTypeId
					,ProductId
					,[Product]
					,CreatedByUserId
					,CreatedDate
					,BillingBankId
					,BankAccountNumber)
			SELECT 
				@NewBillingDate		BillingDate
				,g.BillingDueDate
				,c.CreatedByBranchId BranchCode
				,br.BranchDetail Branch
				,c.ClaimHeaderGroupCode		
				,c.PolicyNo				
				,c.ApplicationCode	
				,c.ClaimCode	
				,c.Province									
				,c.SchoolName									
				,c.CustomerDetailCode
				,c.IdentityCard	
				,c.CustName		
				,c.SchoolLevel		
				,c.DateHappen
				,c.Accident		
				,c.ChiefComplain	
				,c.Orgen	
				,(c.Pay	- ISNULL(b.CoverAmount,0))			Pay
				,c.Amount_Compensate_in						Compensate_Include		
				,c.Amount_Compensate_out					Compensate_Out	
				,c.Amount_Pay	
				,c.Amount_Dead	
				,(c.PaySS_Total - ISNULL(b.CoverAmount,0))	Pay_Total 	
				,c.ClaimAdmitType
				,c.HospitalId
				,c.HospitalName		
				,c.ICD10_1Code		
				,c.ICD10				
				,c.Remark
				,c.DateIn										
				,c.DateOut	
				,c.ClaimType	
				,g.BillingRequestGroupCode
				,b.BillingRequestItemCode
				,''							DocumentLink	
				,@pInsuranceCompanyId	
				,@InsuranceCompanyName
				,c.StartCoverDate
				,c.IPDCount
				,c.ICUCount
				,g.ClaimHeaderGroupTypeId
				,c.ProductId
				,c.[Product]
				,@CreatedByUserId
				,@D2
				,bb.BillingBankId
				,bb.BankAccountNumber
			FROM dbo.BillingRequestItem AS b	
				LEFT JOIN dbo.ClaimHeaderGroupImportDetail AS c	
					ON b.ClaimHeaderGroupImportDetailId = c.ClaimHeaderGroupImportDetailId
				LEFT JOIN dbo.BillingRequestGroup AS g	
					ON b.BillingRequestGroupId = g.BillingRequestGroupId
				LEFT JOIN dbo.BillingRequestResultDetail rrd 
					ON c.ClaimHeaderGroupImportDetailId = rrd.ClaimHeaderGroupImportDetailId
				LEFT JOIN dbo.ClaimHeaderGroupImport i	
					ON c.ClaimHeaderGroupImportId = i.ClaimHeaderGroupImportId
				LEFT JOIN [DataCenterV1].[Address].[Branch] br
					ON C.CreatedByBranchId = br.Branch_ID
				LEFT JOIN dbo.BillingBank bb
					ON i.ClaimTypeCode = bb.ClaimTypeCode	
			WHERE c.IsActive = 1
				AND i.IsActive = 1
				AND (g.BillingRequestGroupId = @BillingRequestGroupId);
				 
			/* Insert ClaimHeaderGroupImportCancel */
			INSERT INTO [dbo].[ClaimHeaderGroupImportCancel]
			      ([ClaimHeaderGroupImportId]
			      ,[CancelDetail]
			      ,[IsActive]
			      ,[CreatedByUserId]
			      ,[CreatedDate])
			SELECT 
				i.ClaimHeaderGroupImportId	ClaimHeaderGroupImportId
				,@TransactionDetail			CancelDetail
				,1							IsActive
				,@UserId					CreatedByUserId
				,@D2						CreatedDate
			FROM #Tmplst i;

 /* Move to next batch */
		SET @Offset = @Offset + @BatchSize;

	END
		
		SET @IsResult	= 1;
		SET @Msg		= 'บันทึก สำเร็จ';
	
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
	
		SET @IsResult	= 0;
		SET @Msg		= 'บันทึก ไม่สำเร็จ';
	
		IF @@Trancount > 0 ROLLBACK;
	END CATCH
	-----------------------------------
END;

RESULT:

IF OBJECT_ID('tempdb..#TmpX') IS NOT NULL  DROP TABLE #TmpX;	
IF OBJECT_ID('tempdb..#TmpDetail') IS NOT NULL  DROP TABLE #TmpDetail;	
IF OBJECT_ID('tempdb..#TmpCover') IS NOT NULL  DROP TABLE #TmpCover;	
IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;
IF OBJECT_ID('tempdb..#TmpDt_') IS NOT NULL  DROP TABLE #TmpDt_;
IF OBJECT_ID('tempdb..#TmpX2') IS NOT NULL  DROP TABLE #TmpX2;
IF OBJECT_ID('tempdb..#TmpDt_Group') IS NOT NULL  DROP TABLE #TmpDt_Group;


IF (@IsResult = 1) 
	BEGIN	
		SET @Result = 'Success';
	END	
ELSE
	BEGIN
		SET @Result = 'Failure';
	END;	

SELECT @IsResult IsResult
		,@Result Result
		,@Msg	 Msg;

END;


GO

/****** Object:  StoredProcedure [dbo].[usp_ClaimHeaderGroupImport_Insert]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
--	Author:		Siriphong Narkphung
--	Create date: 2022-11-01
--	Update date: 2023-02-02 Add Parameter @BillingDate and save it to ClaimHeaderGroupImport in column BillingDate
--				 2023-03-24 เพิ่ม join [vw_CodeGroup_ClaimStyle] 06958 
--				 2023-07-03 เพิ่ม insert InsuranceCompanyName from ClaimHeaderGroupImport 06958
--	UpdatedDate: bell 20230815 0857  เพิ่ม CreatedByBranchCode 
--	UpdatedDate: 2023-10-17 change select TmpDetail from union to If
--	UpdatedDate: 2025-04-11 Wetpisit.P เพิ่ม where tmp.IsValid = 1 เอาเฉพาะรายการที่ไม่ติด validate,เอาเงื่อนไขเช็ค xResult ออกเนื่องจากมีการเปลี่ยนเงื่อนไขการ validate
--	UpdatedDate: 2025-09-25 08:38 (Bunchuai Chaiket) 
--				 - เพิ่มการ Insert การสร้างรายการลง ClaimHeaderGroupImportCancel
--				 - เพิ่ม parameters @ImportFrom เพื่อแยกว่ารายการที่ Import มาจากช่องทางไหน กำหนด 1 ImportExcel 2 Import จากการตั้งเบิก
-- UpdateDate:	2025-11-06 15:20 Sorawit Kamlangsub
--				- Add ClaimMisc
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[usp_ClaimHeaderGroupImport_Insert]
	-- Add the parameters for the stored procedure here
	@TmpCode VARCHAR(20) 
	,@FileName NVARCHAR(255)
	,@CreateByUseId INT
	,@ImportFrom INT
AS
BEGIN
--WAITFOR DELAY '00:05:00';
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE
--	@TmpCode VARCHAR(20)  = 'IMCHG6810000133'
--	,@FileName NVARCHAR(255) = 'EX_importBillingRequestGroup.xlsx'
--	,@CreateByUseId INT = 0
--	,@ImportFrom INT = 1;

DECLARE @ClaimHeaderSSS INT = 2;
DECLARE @ClaimHeaderSSSPA INT = 3;
DECLARE @ClaimCompensate INT = 4;
DECLARE @ClaimHeaderPA30 INT = 5;
DECLARE @Compensate_Include DECIMAL(16,2) = 0;
DECLARE @CountItemFile INT;
DECLARE @D DATETIME2 = SYSDATETIME();
DECLARE @ClaimHeaderGroupImportFileId INT;
DECLARE @IsResult    BIT             = 1;		
DECLARE @Result        VARCHAR(100) = '';
DECLARE @xIsResult BIT=0;
DECLARE @xResult VARCHAR(100)='0';
DECLARE @Msg        NVARCHAR(500)= '';
DECLARE @DiscountSS_PA DECIMAL(16,2) = 0;
DECLARE @Orgen DECIMAL(16,2) = 0;
DECLARE @CancelDetail1 NVARCHAR(500)= N'Import บ.ส. เรียบร้อย อยู่ระหว่างรอการ Generate Group วางบิล';
DECLARE @CancelDetail2 NVARCHAR(500)= N'ได้รับข้อมูล บ.ส. เรียบร้อย อยู่ระหว่างรอการ Generate Group วางบิล';

DECLARE @TmpOut TABLE (ClaimHeaderGroupImportId INT ,ClaimHeaderGroupCode VARCHAR(30)) 
----------------------------------------------

IF @IsResult = 1
BEGIN


	DECLARE @TmpResultVaildate TABLE (xIsResult BIT,xResult VARCHAR(100),xMsg NVARCHAR(max));

	INSERT INTO @TmpResultVaildate( xIsResult , xResult , xMsg )
	EXECUTE dbo.usp_TmpClaimHeaderGroupImport_Validate_V2 @TmpCode;

	SELECT @xIsResult = xIsResult
			,@xResult = xResult
	FROM @TmpResultVaildate;

	IF (@xIsResult <> 1)
		BEGIN
			SET @IsResult = 0;
			SET @Msg = N'กรุณาตรวจสอบข้อมูลใหม่อีกครั้ง';
		END	
END	
---------------------------------------------------------------------


IF @IsResult = 1								
	BEGIN	

		DECLARE @ClaimHeaderGroupTypeId INT;
		
		SELECT 
			tmp.TmpClaimHeaderGroupImportId
			,tmp.TmpCode
			,tmp.ClaimHeaderGroupCode
			,tmp.ItemCount
			,tmp.TotalAmount
			,tmp.BillingDate
			,tmp.IsValid
			,tmp.ValidateResult
			,tmp.InsuranceCompanyId
			,tmp.ClaimHeaderGroupTypeId
			,tmp.ClaimTypeCode
		INTO #Tmp
		FROM dbo.TmpClaimHeaderGroupImport tmp
		WHERE tmp.TmpCode = @TmpCode AND tmp.IsValid = 1


		SELECT h.ClaimHeaderGroup_id
               ,h.InsuranceCompany_Name 
		INTO #TmpCompany
		FROM 
			(
		SELECT g.ClaimHeaderGroup_id,
               g.InsuranceCompany_Name 
		FROM #Tmp m
			INNER JOIN 
				(
					SELECT ClaimHeaderGroup_id,InsuranceCompany_Name 
					FROM sss.dbo.DB_ClaimHeader 
					GROUP BY ClaimHeaderGroup_id,InsuranceCompany_Name
				)g
				ON m.ClaimHeaderGroupCode = ClaimHeaderGroup_id

			UNION

			SELECT g.ClaimCompensateGroupCode
				,g.InsuranceCompany_Name
			FROM #Tmp m
				INNER JOIN SSS.dbo.ClaimCompensateGroup g
					ON m.ClaimHeaderGroupCode = g.ClaimCompensateGroupCode
			UNION

			SELECT g.Code
				,g.InsuranceCompany_Name
			FROM #Tmp m
				INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup g
					ON m.ClaimHeaderGroupCode = g.Code

			UNION

			SELECT 
				g.ClaimHeaderGroupCode
				,g.InsuranceCompanyName	InsuranceCompany_Name
			FROM #Tmp m
				INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] g
					ON m.ClaimHeaderGroupCode = g.ClaimHeaderGroupCode

				) h

		SELECT @ClaimHeaderGroupTypeId = MIN(ClaimHeaderGroupTypeId)
		FROM #Tmp
		
			DECLARE @TmpDetail TABLE (
				ClaimHeaderGroupCode VARCHAR(30)
				 ,ClaimCode VARCHAR(20)
				 ,Province NVARCHAR(100)
				 ,IdentityCard VARCHAR(20)
				 ,CustName NVARCHAR(500)
				 ,DateHappen DATETIME
				 ,Pay FLOAT
				 ,HospitalId INT 
				 ,HospitalName NVARCHAR(250)
				 ,DateIn DATETIME
				 ,DateOut DATETIME
				 ,ApplicationCode VARCHAR(20)
				 ,ProductId INT
				 ,Product NVARCHAR(255)
				 ,DateNotice DATETIME
				 ,StartCoverDate DATE
				 ,ClaimAdmitTypeCode VARCHAR(20)
				 ,ClaimAdmitType NVARCHAR(255)
				 ,ClaimType NVARCHAR(255)
				 ,ICD10_1Code VARCHAR(20)
				 ,ICD10 NVARCHAR(255)
				 ,IPDCount INT
				 ,ICUCount INT
				 ,Net FLOAT
				 ,Compensate_Include FLOAT
				 ,Pay_Total FLOAT
				 ,DiscountSS DECIMAL(16, 2)
				 ,PaySS_Total DECIMAL(16, 2)
				 ,PolicyNo VARCHAR(50)
				 ,SchoolName NVARCHAR(255)
				 ,CustomerDetailCode VARCHAR(20)
				 ,SchoolLevel NVARCHAR(200)
				 ,Accident NVARCHAR(255)
				 ,ChiefComplain NVARCHAR(200)
				 ,Orgen DECIMAL(16, 2)
				 ,Amount_Compeasate_in FLOAT
				 ,Amount_Compeasate_out FLOAT
				 ,Amount_Pay FLOAT
				 ,Amount_Dead FLOAT
				 ,Remark NVARCHAR(500)
				 ,CreatedByBranchCode VARCHAR(20)
			);

		----- PH , PA30 -----
		IF @ClaimHeaderGroupTypeId IN(2,5)
			BEGIN
				INSERT INTO @TmpDetail
				(
				    ClaimHeaderGroupCode,
				    ClaimCode,
				    Province,
				    IdentityCard,
				    CustName,
				    DateHappen,
				    Pay,
				    HospitalId,
				    HospitalName,
				    DateIn,
				    DateOut,
				    ApplicationCode,
				    ProductId,
				    Product,
				    DateNotice,
				    StartCoverDate,
				    ClaimAdmitTypeCode,
				    ClaimAdmitType,
				    ClaimType,
				    ICD10_1Code,
				    ICD10,
				    IPDCount,
				    ICUCount,
				    Net,
				    Compensate_Include,
				    Pay_Total,
				    DiscountSS,
				    PaySS_Total,
				    PolicyNo,
				    SchoolName,
				    CustomerDetailCode,
				    SchoolLevel,
				    Accident,
				    ChiefComplain,
				    Orgen,
				    Amount_Compeasate_in,
				    Amount_Compeasate_out,
				    Amount_Pay,
				    Amount_Dead,
				    Remark,
				    CreatedByBranchCode
				)
				SELECT 	
					h.ClaimHeaderGroup_id AS ClaimHeaderGroupCode
					,h.Code AS ClaimCode
					,pv.Detail AS Province
					,c.ZCard_id AS IdentityCard
					,CONCAT(ct.Detail,c.FirstName,' ',c.LastName) AS CustName
					,h.DateHappen
					,v.Pay
					,hos.Organize_ID AS HospitalId
					,hos.OrganizeDetail AS HospitalName
					,ci.AdmitDate AS DateIn
					,ci.LeaveDate AS DateOut
					,h.App_id AS ApplicationCode
					,pro.Product_ID AS ProductId
					,pro.ProductDetail AS Product
					,h.DateNotice
					,c.StartCoverDate
					,h.ClaimAdmitType_id AS ClaimAdmitTypeCode
					,cat.Detail AS ClaimAdmitType
					,clt.Detail AS ClaimType
					,h.ICD10_1 AS ICD10_1Code
					,icd10.Detail_Thai AS ICD10
					,ci.IPDCount
					,ci.ICUCount
					,v.net AS Net
					,v.Compensate_Include
					,v.Pay_Total
					,v.DiscountSS
					,v.PaySS_Total
					,NULL AS PolicyNo
					,NULL AS SchoolName
					,NULL AS CustomerDetailCode
					,NULL AS SchoolLevel
					,NULL AS Accident
					,cf.Detail AS ChiefComplain
					,NULL AS Orgen
					,NULL AS Amount_Compeasate_in
					,NULL AS Amount_Compeasate_out
					,NULL AS Amount_Pay
					,NULL AS Amount_Dead
					,NULL AS Remark
					,ci.BranchID		CreatedByBranchCode	
				FROM #Tmp t
					LEFT JOIN SSS.dbo.DB_ClaimHeader AS h
						ON t.ClaimHeaderGroupCode = h.ClaimHeaderGroup_id
					LEFT JOIN SSS.dbo.DB_Customer AS c
						ON h.App_id = c.App_id
					LEFT JOIN SSS.dbo.DB_Payer AS py
						ON c.Payer_id = py.Code
					LEFT JOIN SSS.dbo.DB_Address AS ad
						ON py.WorkAddress_id = ad.Code
					LEFT JOIN SSS.dbo.SM_Tumbol AS sd
						ON ad.Tumbol_id = sd.Code
					LEFT JOIN SSS.dbo.SM_Amphoe AS d
						ON sd.Amphoe_id = d.Code
					LEFT JOIN SSS.dbo.SM_Province AS pv
						ON d.Province_id = pv.Code
					LEFT JOIN SSS.dbo.MT_Title AS ct
						ON c.Title_id = ct.Code
					LEFT JOIN SSS.dbo.DB_ClaimVoucher AS v
						ON h.Code = v.Code
					LEFT JOIN DataCenterV1.Organize.Organize AS hos
						ON h.Hospital_id = hos.OrganizeCode
					LEFT JOIN SSS.dbo.DB_ClaimInvoice AS ci
						ON h.Code = ci.ClaimHeader_id
					LEFT JOIN DataCenterV1.Product.Product AS pro
						ON h.Product_id = pro.ProductCode
					LEFT JOIN SSS.dbo.MT_ClaimAdmitType AS cat
						ON h.ClaimAdmitType_id = cat.Code
					LEFT JOIN SSS.dbo.MT_ClaimType AS clt
						ON h.ClaimType_id = clt.Code
					LEFT JOIN SSS.dbo.MT_ICD10 AS icd10
						ON h.ICD10_1 = icd10.Code
					LEFT JOIN SSS.dbo.MT_ChiefComplain cf
						ON h.ChiefComplain_id = cf.Code
					LEFT JOIN SSS.dbo.MT_Product p
						ON h.Product_id = p.Code
				--WHERE @ClaimHeaderGroupTypeId IN (@ClaimHeaderSSS,@ClaimHeaderPA30)						
			END
		----- PA -----
		ELSE IF @ClaimHeaderGroupTypeId = 3
			BEGIN
				-------------------------------------------SSSPA---------------------------------------------
				INSERT INTO @TmpDetail
				(
				    ClaimHeaderGroupCode,
				    ClaimCode,
				    Province,
				    IdentityCard,
				    CustName,
				    DateHappen,
				    Pay,
				    HospitalId,
				    HospitalName,
				    DateIn,
				    DateOut,
				    ApplicationCode,
				    ProductId,
				    Product,
				    DateNotice,
				    StartCoverDate,
				    ClaimAdmitTypeCode,
				    ClaimAdmitType,
				    ClaimType,
				    ICD10_1Code,
				    ICD10,
				    IPDCount,
				    ICUCount,
				    Net,
				    Compensate_Include,
				    Pay_Total,
				    DiscountSS,
				    PaySS_Total,
				    PolicyNo,
				    SchoolName,
				    CustomerDetailCode,
				    SchoolLevel,
				    Accident,
				    ChiefComplain,
				    Orgen,
				    Amount_Compeasate_in,
				    Amount_Compeasate_out,
				    Amount_Pay,
				    Amount_Dead,
				    Remark,
				    CreatedByBranchCode
				)
				SELECT 
					hg.Code															AS ClaimHeaderGroupCode
					,h.Code															AS ClaimCode
					,pv.Detail														AS Province
					,cd.ZCard_ID													AS IdentityCard
					,CONCAT(cdt.Detail,cd.FirstName,' ',cd.LastName)				AS CustName
					,h.DateHappen													AS DateHappen
					,h.Amount_Total													AS Pay
					,hos.Organize_ID												AS HospitalId
					,hos.OrganizeDetail												AS HospitalName
					,h.DateIn														AS DateIn
					,h.DateOut														AS DateOut
					,c.App_id														AS ApplicationCode
					,NULL															AS ProductId
					,p.Detail														AS Product
					,NULL															AS DateNotice
					,NULL															AS StartCoverDate
					,h.ClaimType_id													AS ClaimAdmitTypeCode ---xxxx
					,ctpa.Detail													AS ClaimAdmitType---xxxx
					,CASE 
						WHEN cst.Code = '4110' OR cst.Code = '4120' THEN 'เคลมโรงพยาบาล'  
						ELSE 'เคลมลูกค้า' 
					END AS ClaimType  --2023-03-24 06958
					,icd.Code														AS ICD10_1Code
					,icd.Detail_Thai												AS ICD10
					,NULL															AS IPDCount
					,NULL															AS ICUCount
					,NULL															AS Net
					,NULL															AS Compensate_Include
					,h.Amount_Net													AS Pay_Total
					,h.DiscountSS													AS DiscountSS
					,h.PaySS_Total													AS PaySS_Total
					,ISNULL(CASE h.ClaimType_id
								WHEN '4009' THEN ccy.[9602]
								WHEN '4010' THEN ccy.[9604]
								ELSE ccy.[9601]
							END,ccy.[9605])											AS PolicyNo
					,sch.Detail														AS SchoolName
					,h.CustomerDetail_id											AS CustomerDetailCode
					,lvl.Detail														AS SchoolLevel
					,acc.Detail														AS Accident
					,cco.Detail														AS ChiefComplain
					,@Orgen															AS Orgen
					,h.Amount_Compensate_in											AS Amount_Compeasate_in
					,h.Amount_Compensate_out										AS Amount_Compeasate_out
					,h.Amount_Pay													AS Amount_Pay
					,CASE 
						WHEN h.ClaimType_id = '4006' THEN h.Amount_Compensate
						WHEN h.ClaimType_id = '4006_2' THEN h.Amount_Compensate
						WHEN h.ClaimType_id = '4007' THEN h.Amount_Compensate
						ELSE 0
					END																AS Amount_Dead
					,h.Remark														AS Remark
					,h.CreatedByBranch_id											CreatedByBranchCode
				FROM #Tmp t
					LEFT JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg
						ON t.ClaimHeaderGroupCode = hg.Code
					LEFT JOIN SSSPA.dbo.DB_ClaimHeader AS h
						ON hg.Code = h.ClaimheaderGroup_id
					LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS cd
						ON h.CustomerDetail_id = cd.Code
					LEFT JOIN SSSPA.dbo.DB_Customer AS c
						ON cd.Application_id = c.App_id
					LEFT JOIN SSSPA.dbo.MT_Company AS sch
						ON c.School_id = sch.Code
					LEFT JOIN SSSPA.dbo.MT_Product AS p
						ON c.Product_id = p.Code
					LEFT JOIN SSS.dbo.SM_Tumbol AS sd
						ON sch.Tumbol_id = sd.Code
					LEFT JOIN SSS.dbo.SM_Amphoe AS d
						ON sd.Amphoe_id = d.Code
					LEFT JOIN SSS.dbo.SM_Province AS pv
						ON d.Province_id = pv.Code
					LEFT JOIN SSSPA.dbo.MT_Title AS cdt
						ON cd.Title_id = cdt.Code
					LEFT JOIN DataCenterV1.Organize.Organize AS hos
						ON h.Hospital_id = hos.OrganizeCode
					LEFT JOIN SSS.dbo.MT_ICD10 icd
						ON h.ICD10_1 = icd.Code
					LEFT JOIN 
						(
							SELECT p.App_id
								,p.[9605]
								,p.[9604]
								,p.[9603]
								,p.[9602]
								,p.[9601] 
							FROM 
							(SELECT 
								cp.App_id
								,cp.PolicyType_id
								,cp.Detail
							FROM SSSPA.dbo.DB_CustomerPolicy cp
							)d 
							PIVOT
							(
								 MAX(Detail)FOR PolicyType_id IN([9601],[9602],[9603],[9604],[9605])
							)p
						)ccy
						ON c.App_id = ccy.App_id
					--------------------------------------------------------------------
					LEFT JOIN (
						SELECT * FROM SSSPA.dbo.SM_Code WHERE CodeGroup_id = '8600'
					) AS lvl
						ON c.LevelSchool_id = lvl.Code
					LEFT JOIN (
						SELECT * FROM SSSPA.dbo.SM_Code WHERE CodeGroup_id = '4000'
					) AS ctpa
						ON h.ClaimType_id = ctpa.Code
					LEFT JOIN SSSPA.dbo.MT_AccidentCause AS acc
						ON h.AccidentCause_id = acc.Code
					LEFT JOIN SSS.dbo.MT_ChiefComplain AS cco
						ON h.ChiefComplain_id = cco.Code
					LEFT JOIN [SSSPA].[dbo].[vw_CodeGroup_ClaimStyle] cst
						ON h.ClaimStyle_id = cst.Code
				--WHERE @ClaimHeaderGroupTypeId = @ClaimHeaderSSSPA
			END
		----- ClaimCompensate -----
		ELSE IF @ClaimHeaderGroupTypeId = 4
			BEGIN
				-----ClaimCompensate-----------------------------------
				INSERT INTO @TmpDetail
				(
				    ClaimHeaderGroupCode,
				    ClaimCode,
				    Province,
				    IdentityCard,
				    CustName,
				    DateHappen,
				    Pay,
				    HospitalId,
				    HospitalName,
				    DateIn,
				    DateOut,
				    ApplicationCode,
				    ProductId,
				    Product,
				    DateNotice,
				    StartCoverDate,
				    ClaimAdmitTypeCode,
				    ClaimAdmitType,
				    ClaimType,
				    ICD10_1Code,
				    ICD10,
				    IPDCount,
				    ICUCount,
				    Net,
				    Compensate_Include,
				    Pay_Total,
				    DiscountSS,
				    PaySS_Total,
				    PolicyNo,
				    SchoolName,
				    CustomerDetailCode,
				    SchoolLevel,
				    Accident,
				    ChiefComplain,
				    Orgen,
				    Amount_Compeasate_in,
				    Amount_Compeasate_out,
				    Amount_Pay,
				    Amount_Dead,
				    Remark,
				    CreatedByBranchCode
				)
				SELECT	
					cg.ClaimCompensateGroupCode						AS ClaimHeaderGroupCode
					,cc.ClaimHeaderCode								AS ClaimCode
					,pv.Detail										AS Province
					,c.ZCard_id										AS IdentityCard
					,CONCAT(ct.Detail,c.FirstName,' ',c.LastName)	AS CustName
					,cc.DateHappen
					,cc.CompensateRemain							AS Pay
					,hos.Organize_ID								AS HospitalId
					,hos.OrganizeDetail								AS HospitalName
					,cc.DateIn										AS DateIn
					,cc.DateOut										AS DateOut
					,h.App_id										AS ApplicationCode
					,pro.Product_ID									AS ProductId
					,pro.ProductDetail								AS Product
					,cc.DateNotice
					,c.StartCoverDate
					,cc.ClaimAdmitTypeCode							AS ClaimAdmitTypeCode
					,cat.Detail										AS ClaimAdmitType
					,clt.Detail										AS ClaimType
					,cc.ICD10Code									AS ICD10_1Code
					,icd10.Detail_Thai								AS ICD10
					,ci.IPDCount
					,ci.ICUCount
					,cc.CompensateRemain							AS Net
					,@Compensate_Include							AS Compensate_Include
					,cc.CompensateRemain							AS Pay_Total
					,@DiscountSS_PA									AS DiscountSS
					,cc.CompensateRemain							AS PaySS_Total
					,NULL											AS PolicyNo
					,NULL											AS SchoolName
					,NULL											AS CustomerDetailCode
					,NULL											AS SchoolLevel
					,NULL											AS Accident
					,cf.Detail										AS ChiefComplain
					,NULL											AS Orgen
					,NULL											AS Amount_Compeasate_in
					,NULL											AS Amount_Compeasate_out
					,NULL											AS Amount_Pay
					,NULL											AS Amount_Dead
					,NULL											AS Remark	
					,'9901'											AS CreatedByBranchCode  -- 10-04-2024 Fix Branch สำนักงานใหญ่ type โอนแยก cc.CreatedByBranchCode	
				FROM #Tmp AS t
					LEFT JOIN SSS.dbo.ClaimCompensateGroup AS cg
						ON t.ClaimHeaderGroupCode = cg.ClaimCompensateGroupCode
					LEFT JOIN 
						(
							SELECT c1.*
									,t.Branch_id		CreatedByBranchCode
							FROM SSS.dbo.ClaimCompensate c1
								LEFT JOIN sss.dbo.DB_Team t
									ON c1.CreatedByCode = t.Code
							WHERE c1.IsActive = 1
						)	AS cc
						ON cg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
					LEFT JOIN SSS.dbo.DB_ClaimHeader AS h
						ON cc.ClaimHeaderCode = h.Code
				---------------------------------------
					LEFT JOIN SSS.dbo.DB_Customer AS c
						ON h.App_id = c.App_id
					LEFT JOIN SSS.dbo.DB_Payer AS py
						ON c.Payer_id = py.Code
					LEFT JOIN SSS.dbo.DB_Address AS ad
						ON py.WorkAddress_id = ad.Code
					LEFT JOIN SSS.dbo.SM_Tumbol AS sd
						ON ad.Tumbol_id = sd.Code
					LEFT JOIN SSS.dbo.SM_Amphoe AS d
						ON sd.Amphoe_id = d.Code
					LEFT JOIN SSS.dbo.SM_Province AS pv
						ON d.Province_id = pv.Code
				----------------------------------------
					LEFT JOIN SSS.dbo.MT_Title AS ct
						ON c.Title_id = ct.Code
					LEFT JOIN DataCenterV1.Organize.Organize AS hos
						ON cc.HospitalCode = hos.OrganizeCode
					LEFT JOIN SSS.dbo.DB_ClaimInvoice AS ci
						ON cc.ClaimHeaderCode = ci.ClaimHeader_id
					LEFT JOIN DataCenterV1.Product.Product AS pro
						ON cc.ProductCode = pro.ProductCode
					LEFT JOIN SSS.dbo.MT_ClaimAdmitType AS cat
						ON cc.ClaimAdmitTypeCode = cat.Code
					LEFT JOIN SSS.dbo.MT_ClaimType AS clt
						ON h.ClaimType_id = clt.Code
					LEFT JOIN SSS.dbo.MT_ICD10 AS icd10
						ON cc.ICD10Code= icd10.Code
					LEFT JOIN SSS.dbo.MT_ChiefComplain cf
						ON h.ChiefComplain_id = cf.Code
				--WHERE @ClaimHeaderGroupTypeId = @ClaimCompensate
			END

		--ClaimMisc
		ELSE IF @ClaimHeaderGroupTypeId = 6
			BEGIN
				INSERT INTO @TmpDetail
				(
				    ClaimHeaderGroupCode,
				    ClaimCode,
				    Province,
				    IdentityCard,
				    CustName,
				    DateHappen,
				    Pay,
				    HospitalId,
				    HospitalName,
				    DateIn,
				    DateOut,
				    ApplicationCode,
				    ProductId,
				    Product,
				    DateNotice,
				    StartCoverDate,
				    ClaimAdmitTypeCode,
				    ClaimAdmitType,
				    ClaimType,
				    ICD10_1Code,
				    ICD10,
				    IPDCount,
				    ICUCount,
				    Net,
				    Compensate_Include,
				    Pay_Total,
				    DiscountSS,
				    PaySS_Total,
				    PolicyNo,
				    SchoolName,
				    CustomerDetailCode,
				    SchoolLevel,
				    Accident,
				    ChiefComplain,
				    Orgen,
				    Amount_Compeasate_in,
				    Amount_Compeasate_out,
				    Amount_Pay,
				    Amount_Dead,
				    Remark,
				    CreatedByBranchCode
				)
				SELECT	
					cm.ClaimHeaderGroupCode							ClaimHeaderGroupCode
					,cm.ClaimMiscNo									ClaimCode
					,NULL											Province
					,cm.CitizenId									IdentityCard
					,cm.CustomerName								CustName
					,cm.DateHappen									DateHappen
					,cm.ClaimAmount									Pay
					,cm.HospitalId									HospitalId
					,cm.HospitalName								HospitalName
					,cm.DateIn										DateIn
					,cm.DateOut										DateOut
					,cm.ApplicationCode								ApplicationCode
					,cm.ProductGroupId								ProductId
					,pd.ProductGroupDetail							[Product]
					,cm.DateNotice									DateNotice
					,cm.StartCoverDate								StartCoverDate
					,NULL											ClaimAdmitTypeCode
					,cxa.ClaimAdmitType								ClaimAdmitType
					,'เคลมลูกค้า'										ClaimType
					,NULL											ICD10_1Code
					,NULL											ICD10
					,NULL											IPDCount
					,cm.ICUCount									ICUCount
					,cm.ClaimAmount									Net
					,@Compensate_Include							Compensate_Include
					,cm.ClaimAmount									Pay_Total
					,NULL											DiscountSS
					,cm.ClaimAmount									PaySS_Total
					,cm.PolicyNo									PolicyNo
					,NULL											SchoolName
					,NULL											CustomerDetailCode
					,NULL											SchoolLevel
					,NULL											Accident
					,chp.ChiefComplainName							ChiefComplain
					,NULL											Orgen
					,NULL											Amount_Compeasate_in
					,NULL											Amount_Compeasate_out
					,cm.ClaimAmount									Amount_Pay
					,NULL											Amount_Dead
					,cm.RemarkClaim									Remark	
					,dtB.tempcode									CreatedByBranchCode  
				FROM #Tmp t
				LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm
					ON cm.ClaimHeaderGroupCode = t.ClaimHeaderGroupCode
				LEFT JOIN [DataCenterV1].[Product].[ProductGroup] pd
					ON cm.ProductGroupId = pd.ProductGroup_ID
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
						).value('.', 'nvarchar(255)'), 1, 1, '')	ClaimAdmitType
					FROM [ClaimMiscellaneous].[misc].[ClaimMiscXClaimAdmitType] x
					WHERE x.IsActive = 1
					GROUP BY x.ClaimMiscId
				) cxa
					ON cxa.ClaimMiscId = cm.ClaimMiscId
				LEFT JOIN 
					(
						SELECT
							ChiefComplainId
							,ChiefComplainName
						FROM [ClaimMiscellaneous].[misc].[ChiefComplain]
						WHERE IsActive = 1
					) chp
					ON chp.ChiefComplainId = cm.ChiefComplainId
				LEFT JOIN DataCenterV1.Address.Branch dtB
					ON cm.BranchId = dtB.Branch_ID;

			END


		SELECT m.ClaimCode
				,dcr.PolicyNo
		INTO #TmpDcrPolicyNo
		FROM 
		(
		SELECT ClaimCode
				,CAST( FORMAT(DateHappen,'yyyy-MM-01') AS DATE) PeriodDateHappen 
				,ApplicationCode
		FROM @TmpDetail
		)m
			INNER JOIN sss.dbo.DB_DCR dcr
				ON m.ApplicationCode = dcr.App_Id
				AND m.PeriodDateHappen = dcr.Period;

		------------------------------------------------------
		SELECT @CountItemFile = COUNT(TmpCode) 
		FROM #Tmp;

		BEGIN TRY								
			BEGIN TRANSACTION

				---INSERT File------
				INSERT INTO dbo.ClaimHeaderGroupImportFile
						 (
							 [FileName]
							 ,ItemCount
							 ,ClaimHeaderGroupTypeId
							 ,IsActive
							 ,CreatedDate
							 ,CreatedByUserId
							 ,UpdatedDate
							 ,UpdatedByUserId
						 )
				SELECT @FileName				[FileName]
					,@CountItemFile				ItemCount
					,@ClaimHeaderGroupTypeId	ClaimHeaderGroupTypeId
					,1							IsActive
					,@D							CreatedDate
					,@CreateByUseId				CreatedByUserId
					,@D							UpdatedDate
					,@CreateByUseId				UpdatedByUserId

				SET @ClaimHeaderGroupImportFileId = SCOPE_IDENTITY();

				---INSERT GROUP-----
				INSERT INTO dbo.ClaimHeaderGroupImport
						 (
							 ClaimHeaderGroupCode
							 ,ClaimGroupImportFileId
							 ,ItemCount
							 ,TotalAmount
							 ,BillingDate
							 ,ClaimHeaderGroupImportStatusId
							 ,InsuranceCompanyId
							 ,BillingRequestGroupId
							 ,IsActive
							 ,CreatedDate
							 ,CreatedByUserId
							 ,UpdatedDate
							 ,UpdatedByUserId
							 ,ClaimTypeCode
							 ,InsuranceCompanyName
						 )
				OUTPUT Inserted.ClaimHeaderGroupImportId , Inserted.ClaimHeaderGroupCode INTO @TmpOut
				SELECT t1.ClaimHeaderGroupCode
					,@ClaimHeaderGroupImportFileId	ClaimGroupImportFileId
					,t1.ItemCount					
					,t1.TotalAmount					
					
					,t1.BillingDate					
					,2								ClaimHeaderGroupImportStatusId
					,t1.InsuranceCompanyId
					,NULL							BillingRequestGroupId
					,1								IsActive
					,@D								CreatedDate
					,@CreateByUseId					CreatedByUserId
					,@D								UpdatedDate
					,@CreateByUseId					CreatedByUserId
					,t1.ClaimTypeCode
					,tc.InsuranceCompany_Name
				FROM #Tmp t1
					LEFT JOIN #TmpCompany tc
						ON t1.ClaimHeaderGroupCode = tc.ClaimHeaderGroup_id

				---INSERT DETAIL-----
				INSERT INTO dbo.ClaimHeaderGroupImportDetail
						 (
							 ClaimHeaderGroupImportId
							 ,ClaimCode
							 ,ClaimHeaderGroupCode
							 ,Province
							 ,IdentityCard
							 ,CustName
							 ,DateHappen
							 ,Pay
							 ,HospitalId
							 ,HospitalName
							 ,DateIn
							 ,DateOut
							 ,ApplicationCode
							 ,ProductId
							 ,Product
							 ,DateNotice
							 ,StartCoverDate
							 ,ClaimAdmitTypeCode
							 ,ClaimAdmitType
							 ,ClaimType
							 ,ICD10_1Code
							 ,ICD10
							 ,IPDCount
							 ,ICUCount
							 ,Net
							 ,Compensate_Include
							 ,Pay_Total
							 ,DiscountSS
							 ,PaySS_Total
							 ,PolicyNo
							 ,SchoolName
							 ,CustomerDetailCode
							 ,SchoolLevel
							 ,Accident
							 ,ChiefComplain
							 ,Orgen
							 ,Amount_Compensate_in
							 ,Amount_Compensate_out
							 ,Amount_Pay
							 ,Amount_Dead
							 ,Remark
							 ,IsActive
							 ,CreatedDate
							 ,CreatedByUserId
							 ,UpdatedDate
							 ,UpdatedByUserId
							 ,CreatedByBranchId
						 )
				SELECT 
					u.ClaimHeaderGroupImportId
					,m.ClaimCode
					,m.ClaimHeaderGroupCode
					,m.Province
					,m.IdentityCard
					,m.CustName
					,m.DateHappen
					,m.Pay
					,m.HospitalId
					,m.HospitalName
					,m.DateIn
					,m.DateOut
					,m.ApplicationCode
					,m.ProductId
					,m.Product
					,m.DateNotice
					,m.StartCoverDate
					,m.ClaimAdmitTypeCode
					,m.ClaimAdmitType
					,m.ClaimType
					,m.ICD10_1Code
					,m.ICD10
					,m.IPDCount
					,m.ICUCount
					,m.Net
					,m.Compensate_Include
					,m.Pay_Total
					,m.DiscountSS
					,m.PaySS_Total
					--,m.PolicyNo
					,CASE 	
						WHEN @ClaimHeaderGroupTypeId IN (2,4,5) THEN p.PolicyNo
						ELSE m.PolicyNo
						END	PolicyNo
					,m.SchoolName
					,m.CustomerDetailCode
					,m.SchoolLevel
					,m.Accident
					,m.ChiefComplain
					,m.Orgen
					,m.Amount_Compeasate_in
					,m.Amount_Compeasate_out
					,m.Amount_Pay
					,m.Amount_Dead
					,m.Remark
					,1						IsActive
					,@D						CreatedDate
					,@CreateByUseId			CreatedByUserId
					,@D						UpdatedDate
					,@CreateByUseId			UpdatedByUserId
					,dtB.Branch_ID			BranchId
				FROM @TmpDetail m
					LEFT JOIN @TmpOut u
						ON m.ClaimHeaderGroupCode = u.ClaimHeaderGroupCode
					LEFT JOIN #TmpDcrPolicyNo p 
						ON m.ClaimCode = p.ClaimCode
					LEFT JOIN DataCenterV1.Address.Branch dtB
						ON m.CreatedByBranchCode = dtB.tempcode;

				--Delete TmpClaimHeaderGroupImport
				--SELECT *
				DELETE m
				FROM dbo.TmpClaimHeaderGroupImport m 
				WHERE m.TmpCode = @TmpCode;

				-- Insert ClaimHeaderGroupImportCancel
				INSERT INTO [dbo].[ClaimHeaderGroupImportCancel]
						      ([ClaimHeaderGroupImportId]
						      ,[CancelDetail]
						      ,[IsActive]
						      ,[CreatedByUserId]
						      ,[CreatedDate])
						SELECT 
							i.ClaimHeaderGroupImportId								ClaimHeaderGroupImportId
							,IIF(@ImportFrom = 1, @CancelDetail1, @CancelDetail2)	CancelDetail
							,1														IsActive
							,@CreateByUseId											CreatedByUserId
							,@D														CreatedDate
						FROM @TmpOut i;

			SET @IsResult = 1			  					
			SET @Msg = 'บันทึก สำเร็จ'	 						
										  					
			COMMIT TRANSACTION			  					
		END TRY							  					
		BEGIN CATCH						  					
										  					
			SET @IsResult = 0			  					
			SET @Msg = 'บันทึก ไม่สำเร็จ'		
							
			IF @@TRANCOUNT > 0 ROLLBACK	  					
		END CATCH


		IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;
		IF OBJECT_ID('tempdb..#TmpFile') IS NOT NULL  DROP TABLE #TmpFile;
		IF OBJECT_ID('tempdb..#TmpGroup') IS NOT NULL  DROP TABLE #TmpGroup;
		IF OBJECT_ID('tempdb..#TmpCompany') IS NOT NULL  DROP TABLE #TmpCompany;
		IF OBJECT_ID('tempdb..#TmpDcrPolicyNo') IS NOT NULL  DROP TABLE #TmpDcrPolicyNo;	
		IF OBJECT_ID('tempdb..@TmpDetail') IS NOT NULL  DELETE FROM @TmpDetail;
	END	;

										  					
IF @IsResult = 1 BEGIN	SET @Result = 'Success'; END;	
ELSE BEGIN	SET @Result = 'Failure'; END ;				
							  								
            							  					
       SELECT @IsResult IsResult		  					
		,@Result Result					  					
		,@Msg	 Msg 					  					

END
GO

/****** Object:  StoredProcedure [dbo].[usp_ClaimHeaderGroupValidateAmountPay_Select]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Mr.Bunchuai chaiket
-- Create date: 2025-09-03 14:32
-- Update date:	2025-09-11 15:42
--				เพิ่มขั้นตอนการตรวจสอบ Customer policy กรณี Product เป็น PA
-- Update date: 2025-10-16 11:06
--				แก้ไขการ SELECT ยอดเงิน NPL
-- Update date: 2025-10-16 16:49
--				ตัดเงื่อนไข ไม่ตรวจสอบเลขกรมธรรม์ กรณีเป็น PA และเคลมโรงพยาบาล
-- Update date: 2025-10-22 10:30 Bunchuai Chaiket
--				เพิ่ม validate ข้อมูลจาก ClaimMisc
-- Update date: 2025-10-27 12:28 Sorawit kamlangsub
--				change THEN NULL To ''
-- Update date: 2025-12-19 09:55
--				เพิ่มการตรวจสอบสถานะของ Claim online
-- Update date: 2026-03-11 13:39 Bunchaui chaiket
--				LEFT JOIN DB_Customer PA
-- Description:	Function สำหรับ Validate ยอดเงิน บ.ส. และยอดเงินโอน
-- =============================================
CREATE PROCEDURE [dbo].[usp_ClaimHeaderGroupValidateAmountPay_Select]  
	@ProductGroupId				INT
	,@ClaimGroupTypeId			INT
	,@ClaimHeaderGroupCode		VARCHAR(MAX)
AS
BEGIN
SET NOCOUNT ON;

-- =============================================
--DECLARE @ProductGroupId				INT				= 3;
--DECLARE @ClaimGroupTypeId			INT				= 3; 
--DECLARE @ClaimHeaderGroupCode		VARCHAR(MAX)	= 'TSAN-888-69030001-0';
-- =============================================

-- Set message 
DECLARE @AmountWarning					NVARCHAR(MAX) = N'ยอด บ.ส.ไม่เท่ากับยอดโอน';	
DECLARE @PolicyWarning					NVARCHAR(MAX) = N'ไม่มีเลขที่กรมธรรม์';
DECLARE @PolicyStatusWarning			NVARCHAR(MAX) = N'ตรวจสอบสถานะกรมธรรม์';	
DECLARE @ClaimHeaderGroupAmountWarning	NVARCHAR(MAX) = N'ยอดเงินตาม บ.ส.ไม่ถูกต้อง';
DECLARE @ClaimHeaderPaymentWarning		NVARCHAR(MAX) = N'บ.ส.นี้อยู่ระหว่างดำเนินการโอนเงิน';
DECLARE @ClaimOnlineStatusWarning		NVARCHAR(MAX) = N'สถานะ ClaimOnline ยกเลิก';
DECLARE @InsuranceCompanyId				VARCHAR(20) = '100000000041';

-- Create temp table
SELECT DISTINCT Element
INTO #Tmp
FROM dbo.func_SplitStringToTable(@ClaimHeaderGroupCode,',');

CREATE TABLE #Tmplst
(
	ClaimHeaderGroupCode	VARCHAR(30)
	,TransferAmount			DECIMAL(16,2)
	,Amount					DECIMAL(16,2)
	,NPLAmount				DECIMAL(16,2)
	,WarningMessage			NVARCHAR(MAX)
);

-- PH
IF @ProductGroupId = 2

	BEGIN

		INSERT INTO #Tmplst(
			ClaimHeaderGroupCode
			,TransferAmount
			,Amount
			,NPLAmount 
			,WarningMessage
		)
		SELECT 
			chg.code								ClaimHeaderGroupCode
			,ISNULL(colPH.TotalAmount, 0)			TotalAmount
			,cv.PaySS_Total							Amount
			,ISNULL(nplds.NPLAmount, 0)				NPLAmount
			,CASE 
				WHEN  ISNULL(cv.PaySS_Total, 0) = 0	THEN @ClaimHeaderGroupAmountWarning
				WHEN @ClaimGroupTypeId IN(2,6)															
					AND (
						(ISNULL(colPH.TotalAmount, 0) = 0 AND cv.PaySS_Total = 0) OR ISNULL(colPH.TotalAmount, 0) <> (cv.PaySS_Total + ISNULL(nplds.NPLAmount, 0))
					)								THEN @AmountWarning
			ELSE NULL END  AS WarningMessage
		FROM sss.dbo.DB_ClaimHeaderGroup chg
			INNER JOIN #Tmp ts
				ON chg.Code = ts.Element
			LEFT JOIN SSS.dbo.DB_ClaimHeaderGroupItem cgi 
				ON chg.Code = cgi.ClaimHeaderGroup_id
			LEFT JOIN sss.dbo.DB_ClaimHeader ch
				ON cgi.ClaimHeader_id = ch.Code
			LEFT JOIN sss.dbo.DB_ClaimVoucher cv
				ON cgi.ClaimHeader_id = cv.Code
			LEFT JOIN
			(
				SELECT
					co.ClaimOnLineCode
					,co.ClaimOnLineId
					,SUM(cg.TotalAmount)	TotalAmount
				FROM ClaimOnlineV2.dbo.ClaimOnline co
					LEFT JOIN ClaimOnlineV2.dbo.ClaimPayGroup cg
						ON cg.ClaimOnLineId = co.ClaimOnLineId
				WHERE co.IsActive = 1  
					AND cg.IsActive = 1
					AND cg.PaymentStatusId = 4
				GROUP BY  co.ClaimOnLineCode, co.ClaimOnLineId
			) colPH
				ON colPH.ClaimOnLineCode = ch.ClaimOnLineCode
			LEFT JOIN (
				SELECT 
					ClaimOnLineId
					,SUM(npld.Amount)	NPLAmount
				FROM ClaimOnlineV2.dbo.NPLHeader nplh
					INNER JOIN ClaimOnlineV2.dbo.NPLDetail npld
						ON nplh.NPLHeaderId = npld.NPLHeaderId
				WHERE nplh.IsActive = 1
					AND npld.IsActive = 1
				GROUP BY ClaimOnLineId
			)nplds
				ON nplds.ClaimOnLineId = colPH.ClaimOnLineId

			WHERE  chg.InsuranceCompany_id <> @InsuranceCompanyId				

	END

-- PA
ELSE IF @ProductGroupId = 3

	BEGIN
    
		INSERT INTO #Tmplst(
			ClaimHeaderGroupCode
			,TransferAmount
			,Amount
			,NPLAmount
			,WarningMessage
		)
		SELECT 
			chgPA.Code							ClaimHeaderGroupCode
			,ISNULL(colPA.TotalAmount, 0)		TransferAmount
			,ISNULL(chPA.PaySS_Total, 0)		Amount
			,ISNULL(nplds.NPLAmount, 0)			NPLAmount
			,(
				ISNULL(
					CASE 
						WHEN @ClaimGroupTypeId <> 4
							AND (ctmpPA.Code IS NULL AND ctm.App_id IS NULL)
							THEN @PolicyWarning + ' , '
					END, ''
				)
				+
				ISNULL(
					CASE 
						WHEN ctm.App_id IS NULL
							THEN @PolicyStatusWarning + ' , '
					END, ''
				)
				+
				ISNULL(
					CASE 
						WHEN ISNULL(chPA.PaySS_Total, 0) = 0
							THEN CONCAT(@ClaimHeaderGroupAmountWarning, ' , ')
						ELSE ''
					END, NULL
				)
				+
				ISNULL(
					CASE 
						WHEN @ClaimGroupTypeId IN (2,6)
							AND (
								ISNULL(colPA.TotalAmount, 0) <> (chPA.PaySS_Total + ISNULL(nplds.NPLAmount, 0))
							)
						THEN @AmountWarning + ' , ' 
						ELSE ''
					END, NULL
				)
			) AS WarningMessage
				
		FROM SSSPA.dbo.DB_ClaimHeaderGroupItem cgiPA
			LEFT JOIN SSSPA.dbo.DB_ClaimHeaderGroup chgPA
				ON cgiPA.ClaimHeaderGroup_id = chgPA.Code
			INNER JOIN #Tmp ts
				ON chgPA.Code = ts.Element
			LEFT JOIN SSSPA.dbo.DB_ClaimHeader chPA
				ON cgiPA.ClaimHeader_id = chPA.Code 
			LEFT JOIN (
				SELECT *
				FROM SSSPA.dbo.DB_CustomerDetail
				WHERE IsActive = 1
			) ctmdPA
				ON chPA.CustomerDetail_id = ctmdPA.Code
			LEFT JOIN (
				SELECT * 
				FROM SSSPA.dbo.DB_CustomerPolicy
				WHERE PolicyType_id <> '9605'
			) ctmpPA
				ON ctmdPA.Application_id = ctmpPA.App_id 
			LEFT JOIN (
				SELECT *
				FROM SSSPA.dbo.DB_Customer
				WHERE IsActive = 1
					AND Status_id = '3040' 
			)ctm
				ON ctmdPA.Application_id = ctm.App_id
			LEFT JOIN
			(
				SELECT  
					co.ClaimOnLineCode 
					,co.ClaimOnLineId
					,SUM(cg.TotalAmount)    TotalAmount
				FROM ClaimOnlineV2.dbo.ClaimOnline co
					LEFT JOIN (
						SELECT 
							ClaimOnLineId
							,IsActive
							,PaymentStatusId
							,SUM(ISNULL(TotalAmount, 0)) TotalAmount
						FROM ClaimOnlineV2.dbo.ClaimPayGroup
						GROUP BY ClaimOnLineId
							,IsActive
							,PaymentStatusId
					)cg
						ON cg.ClaimOnLineId = co.ClaimOnLineId
				WHERE co.IsActive = 1
					AND cg.IsActive = 1  
					AND cg.PaymentStatusId = 4
				GROUP BY  co.ClaimOnLineCode,co.ClaimOnLineId

			) colPA
				ON colPA.ClaimOnLineCode = chPA.ClaimOnLineCode 
			LEFT JOIN (
				SELECT 
					ClaimOnLineId
					,SUM(npld.Amount)	NPLAmount
				FROM ClaimOnlineV2.dbo.NPLHeader nplh
					INNER JOIN ClaimOnlineV2.dbo.NPLDetail npld
						ON nplh.NPLHeaderId = npld.NPLHeaderId
				WHERE nplh.IsActive = 1
					AND npld.IsActive = 1
				GROUP BY ClaimOnLineId
			)nplds
				ON nplds.ClaimOnLineId = colPA.ClaimOnLineId

		WHERE chgPA.InsuranceCompany_id <> @InsuranceCompanyId
	
	END

-- Claim Misc
ELSE IF @ProductGroupId > 3

	BEGIN

		INSERT INTO #Tmplst(
			ClaimHeaderGroupCode
			,TransferAmount
			,Amount
			,NPLAmount
			,WarningMessage
		)
		SELECT 
				cm.ClaimHeaderGroupCode				ClaimHeaderGroupCode
				,cph.PayAmount						TransferAmount
				,ISNULL(cm.PayAmount, 0)			Amount
				,ISNULL(colnlp.NPLAmount, 0)		NPLAmount 
				,(
					ISNULL(
						CASE 
							WHEN ISNULL(cm.PayAmount, 0) = 0 
								THEN @ClaimHeaderGroupAmountWarning + ' , ' 
							ELSE ''
						END, NULL
					)
					+
					ISNULL(
						CASE 
							WHEN ISNULL(cph.PayAmount, 0) <> (ISNULL(cm.PayAmount, 0) + ISNULL(colnlp.NPLAmount, 0))
								THEN CONCAT(@AmountWarning, ' , ')
							ELSE ''
						END, NULL
					)
					+
					ISNULL(
						CASE 
							WHEN NULLIF(cm.PolicyNo ,'')  IS NULL
								THEN CONCAT(@PolicyWarning, ' , ')
							ELSE ''
						END, NULL
					)
					+
					ISNULL(
						CASE 
							WHEN (cph.ClaimMiscId IS NULL OR phxcmp.PaymentStatusId IS NOT NULL)
								THEN CONCAT(@ClaimHeaderPaymentWarning, ' , ')
							ELSE ''
						END, NULL
					) 
					+
					ISNULL(
						CASE 
							WHEN cls.ClaimOnLineStatusId = 4
								THEN CONCAT(@ClaimOnlineStatusWarning, ' , ')
							ELSE ''
						END, NULL
					)
				 ) AS WarningMessage  
				 --,cph.*
		FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			INNER JOIN #Tmp t
				ON cm.ClaimHeaderGroupCode = t.Element
			LEFT JOIN (
				-- NPL
				SELECT 
					nplh.ClaimOnLineId
					,SUM(npld.Amount)	NPLAmount
				FROM ClaimOnlineV2.dbo.NPLHeader nplh
					LEFT JOIN ClaimOnlineV2.dbo.NPLDetail npld
						ON nplh.NPLHeaderId = npld.NPLHeaderId
				WHERE nplh.IsActive = 1
					AND npld.IsActive = 1
				GROUP BY nplh.ClaimOnLineId
			)colnlp
				ON colnlp.ClaimOnLineId = cm.ClaimOnLineId 
			INNER JOIN 
			(
				-- โอนเงิน
				SELECT 
					pv.ClaimMiscId
					--,ISNULL(pv.[2],0)			[FirstBlood]
					--,ISNULL(pv.[3]	,0)			[DoubleKill]
					--,ISNULL(pv.[4]	,0)			[Denie]
					,(ISNULL(pv.[2],0) + ISNULL(pv.[3],0) - ISNULL(pv.[4],0)) PayAmount
				FROM
				(
					SELECT 
						ph.ClaimMiscId		ClaimMiscId 
						,ph.SumAmount		PayAmount
						,ph.PaymentTypeId
					FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] ph
					WHERE ph.IsActive = 1
						AND ph.PaymentTypeId IN (2,3,4)
					GROUP BY ph.ClaimMiscId	
						,ph.PaymentTypeId
						,ph.SumAmount
				)m 
				PIVOT(
					SUM(m.PayAmount) FOR m.PaymentTypeId IN([2],[3],[4])
				)pv
			)
			cph
				ON cm.ClaimMiscId = cph.ClaimMiscId
			LEFT JOIN (
				-- ตรวจสอบสถานะการโอนเงิน
				SELECT 
					cl.ClaimOnLineStatusId
					,cl.ClaimOnLineId
				FROM [ClaimOnlineV2].[dbo].ClaimOnline cl
				WHERE cl.IsActive = 1
			)cls
				ON cm.ClaimOnLineId = cls.ClaimOnLineId
			LEFT JOIN (
				SELECT 
					cmp.PaymentStatusId
					,ph.ClaimMiscId
				FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] ph
					LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] cmp
						ON ph.ClaimMiscPaymentHeaderId = cmp.ClaimMiscPaymentHeaderId
				WHERE ph.IsActive = 1
					AND cmp.IsActive = 1
					AND cmp.PaymentStatusId NOT IN (4,5)
			)phxcmp
				ON cm.ClaimMiscId = phxcmp.ClaimMiscId
		WHERE cm.IsActive = 1
			 
 	END

-- set result
SELECT  
	 tmp.ClaimHeaderGroupCode											ClaimHeaderGroupCode 
	,tmp.Amount															Amount
	,tmp.NPLAmount														NPLAmount
	,tmp.TransferAmount													TransferAmount
	,IIF(tmp.WarningMessage IS NULL OR tmp.WarningMessage = '', 1, 0)	IsValid 
	,tmp.WarningMessage													WarningMessage
FROM #Tmplst tmp
GROUP BY  tmp.ClaimHeaderGroupCode	
		 ,tmp.Amount				
		 ,tmp.NPLAmount
		 ,tmp.TransferAmount		
		 ,tmp.WarningMessage		
		 

IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;	
IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;

 
--DECLARE @TransferAmount		DECIMAL(16,2)	= NULL;
--DECLARE @Amount				DECIMAL(16,2)	= NULL;
--DECLARE @NPLAmount			DECIMAL(16,2)	= NULL;
--DECLARE @WarningMessage		NVARCHAR(MAX)	= NULL;
--DECLARE @IsValid              INT             = NULL;

--SELECT
--	 @ClaimHeaderGroupCode	ClaimHeaderGroupCode
--	 ,@Amount				Amount
--	 ,@TransferAmount 		TransferAmount
--	 ,@NPLAmount			NPLAmount
--	 ,@WarningMessage		WarningMessage
--	 ,@IsValid              IsValid 

END;
GO

/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackForGroupTransfer_Select]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Prattana  Phiwkaew
-- Create date: 2021-10-07 10:03
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[usp_ClaimPayBackForGroupTransfer_Select]
	-- Add the parameters for the stored procedure here
	 @CreatedDateFrom		DATE 
	,@CreatedDateTo			DATE 
	,@ClaimGroupTypeId		INT = NULL


	,@IndexStart			INT = NULL 
	,@PageSize				INT = NULL 
	,@SortField				NVARCHAR(MAX) = NULL
	,@OrderType				NVARCHAR(MAX) = NULL
	,@SearchDetail			NVARCHAR(MAX) = NULL

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
----------------------------------------------------------

DECLARE @l_IndexStart INT				= @IndexStart;
DECLARE @l_PageSize INT				= @PageSize;
DECLARE @l_SortField NVARCHAR(MAX)	= @SortField;
DECLARE @l_OrderType NVARCHAR(MAX)	= @OrderType;
DECLARE @l_SearchDetail NVARCHAR(MAX)	= @SearchDetail;	

----------------------------------------------------------------------------
IF @l_IndexStart IS NULL SET @l_IndexStart = 0;
IF @l_PageSize IS NULL SET @l_PageSize = 10;
IF @l_SearchDetail IS NULL SET @l_SearchDetail = '';
----------------------------------------------------------------------------

IF @CreatedDateTo IS NOT NULL SET @CreatedDateTo = DATEADD(DAY,1,@CreatedDateTo)

---------------------------------------------------------------------------

SELECT b.ClaimPayBackId
      ,b.ClaimPayBackCode
      ,b.Amount
      ,b.ClaimPayBackStatusId
	  ,cp_sts.ClaimPayBackStatus
      ,b.ClaimGroupTypeId
	  ,cg_t.ClaimGroupType
      ,b.BranchId
	  ,brh.BranchDetail					Branch
      ,b.ClaimPayBackTransferId
      ,b.IsActive
      ,b.CreatedByUserId
	  ,CONCAT(pu.EmployeeCode,' ',pu.PersonName)	CreatedByName
      ,b.CreatedDate
      ,b.UpdatedByUserId
      ,b.UpdatedDate 
	  ,t.CreatedDate					TransferCreatedDate
	  ,t.UpdatedDate					TransferUpdatedDate
	   ,COUNT(b.ClaimPayBackId) OVER ( ) AS TotalCount
FROM dbo.ClaimPayBack b
	LEFT JOIN dbo.ClaimPayBackTransfer t
		ON b.ClaimPayBackTransferId = t.ClaimPayBackTransferId
	LEFT JOIN dbo.ClaimPayBackStatus cp_sts
		ON b.ClaimPayBackStatusId = cp_sts.ClaimPayBackStatusId
	LEFT JOIN dbo.ClaimGroupType cg_t
		ON b.ClaimGroupTypeId = cg_t.ClaimGroupTypeId
	LEFT JOIN DataCenterV1.Address.Branch brh
		ON b.BranchId = brh.Branch_ID
	LEFT JOIN DataCenterV1.Person.vw_PersonUser pu
		ON b.CreatedByUserId = pu.UserId
WHERE (b.CreatedDate >= @CreatedDateFrom AND  b.CreatedDate < @CreatedDateTo )
AND (b.ClaimGroupTypeId = @ClaimGroupTypeId OR @ClaimGroupTypeId IS NULL)
AND (b.ClaimPayBackStatusId = 2)	--2 รอดำเนินการ
AND (b.IsActive = 1)

--AND (b.ClaimPayBackCode LIKE N'%'+ @l_SearchDetail + '%' OR @l_SearchDetail IS NULL)

ORDER BY CASE WHEN @l_OrderType IS NULL AND @l_SortField IS NULL THEN b.ClaimPayBackId END ASC 
,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'ClaimPayBackCode' THEN b.ClaimPayBackId END ASC 
,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'ClaimPayBackCode' THEN b.ClaimPayBackId END DESC 
OFFSET @l_IndexStart ROWS FETCH NEXT @l_PageSize ROWS ONLY;



END


GO

/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackReportNonClaimCompensate_Select]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO







-- =============================================
-- Author:		06588 Krekpon Dokkamklang Mind
-- Create date: 2024-06-20
-- Description:	ClaimPayBackReport รายงานส่งการเงินที่ไม่ใช่ประเภทโอนแยก
-- Update date: 2024-06-25
-- Description:	แก้ไขเงื่อนไข เอาเลขโรงพยาบาลมาหานอกการ JOIN UNION
-- Update date: 2024-07-01 06588 Krekpon.D Mind
-- Description:	เปลี่ยนโค้ดการทำงานใหม่ ให้ทำงานเร็วขึ้น
-- Update date: 2025-05-15 Wetpisit.P
-- Description:	เพิ่มการดึงข้อมูล ClaimNo CustomerName และ RecordedDate ถ้าเป็นเคลมโรงพยาบาล PH,PA
-- Update date: 2025-08-13 Bunchuai chaiket 
-- Description:	แก้ไขการดึงข้อมูล @ClaimGroupTypeId = 6 Hospital,COL, Province และเพิ่ม SELECT HospitalCode
-- Update date: 2025-08-18 16:22 Bunchuai chaiket 
-- Description:	Select icu.ClaimCode AS ClaimNo เพิ่ม
-- Update date: 2025-08-18 17:52 Krekpon Dokkamklang Mind 
-- Description:	remove where product
-- Update date: 2025-08-19 16:34 Krekpon Dokkamklang Mind 
-- Description:	WHERE isAcive
-- Update date: 2025-08-20 16:10 Krekpon Dokkamklang Mind 
-- Description:	ปรับการทำงานตอนดึงข้อมูล
-- Update date: 2025-10-16 15:20 Sorawit Kamlangsub
-- Description:	ปรับเรียกข้อมูล Employee
-- Update date: 2025-10-29 14:31 Sorawit Kamlangsub
-- Description:	Add UNION ClaimMisc
-- Update date: 2025-12-08 10:06 Krekpon.D
-- Update date: 2025-12-11 09.00 Mr.Bunchuai Chaiket (08498)
-- Description:	ปรับการแสดงผล (SELECT ข้อมูลเพิ่ม) จากระบบ ClaimMisc
-- Description:	Add province
-- Update date: 2025-12-22 9:35 Sorawit.K 
-- Description:	Fix ClaiMisc ProductGroupDetailName 
-- Update date: 2025-12-24 10.52 06588 Krekpon.D Mind
-- Description:	ปรับเงื่อนไขการแสดงข้อมูลเคลมออนไลน์ไม่ให้แสดง ธนาคาร,ชื่อบัญชี,เลขที่
-- Update date: 2025-12-24 17.07 Sorawit.k
-- Description:	ปรับเงื่อนไขการแสดงข้อมูลเคลมเบ็ดเตล็ดให้แสดง ธนาคาร,ชื่อบัญชี,เลขที่ เฉพาะ ยิ้มแฉ่ง
-- Update date: 2026-01-08 10.14 06588 Krekpon.D Mind
-- Description:	ปรับเงื่อนไขการแสดงข้อมูลเคลม MISC ให้ไม่แสดง ธนาคาร,ชื่อบัญชี,เลขที่
-- Update date: 2026-01-14 14.11 06588 Krekpon.D Mind
-- Description: ปรับรายการแสดงของการเลือก ProductType
-- Update date: 2026-02-17 14.11 Sorawit.k
-- Description: ปรับการค้นหา ClaimMisc Motor
-- Update date: 2026-03-09 Sorawit.k
-- Description:	เพิ่ม ClaimPaymentTypeName,ClaimPaymentTypeDetail
-- =============================================
CREATE PROCEDURE [dbo].[usp_ClaimPayBackReportNonClaimCompensate_Select]
	 @DateFrom			DATE =	NULL
	,@DateTo			DATE =	NULL
	,@InsuranceId		INT =	NULL
	,@ProductGroupId	INT =	NULL
	,@ClaimGroupTypeId	INT =	NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
-- START TEST
--DECLARE
--	 @DateFrom			DATE =	'2026-02-16'
--	,@DateTo			DATE =	'2026-02-17'
--	,@InsuranceId		INT =	NULL
--	,@ProductGroupId	INT =	4
--	,@ClaimGroupTypeId	INT =	7;
-- END Test

DECLARE @TmpClaimPayBack TABLE (
	 ClaimGroupCodeFromCPBD NVARCHAR(150),
	 ClaimGroupType NVARCHAR(100),
	 ItemCount		 INT,
     Amount			 DECIMAL(16,2),
	 ProductGroupDetailName NVARCHAR(20),
	 BranchId		 INT,
	 COL			 NVARCHAR(150),
	 CreatedDate	 DATETIME,
	 CreatedByUser NVARCHAR(150),
	 HospitalCode VARCHAR(20)
     )

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

 -- เอาข้อมูลลงใน temp แล้วไป JOIN ต่อกับฝั่ง Base อื่น
 INSERT INTO @TmpClaimPayBack(
      ClaimGroupCodeFromCPBD,
	  ClaimGroupType,
	  ItemCount,
      Amount,
	  ProductGroupDetailName,
	  BranchId,
	  COL,
	  CreatedDate,
	  CreatedByUser,
	  HospitalCode
      )
 SELECT   
     cpbd.ClaimGroupCode						AS ClaimGroupCode,
	 cgt.ClaimGroupType							AS ClaimGroupType,
	 cpbd.ItemCount								AS ItemCount,
     cpbd.Amount								AS Amount,
	 dppg.ProductGroupDetail					AS ProductGroupDetailName,
	 cpb.BranchId								AS BranchId,
	 cpbd.ClaimOnLineCode						AS COL,
	 cpb.CreatedDate							AS CreatedDate,
	 pu.PersonName								AS CreatedByUser,
	 cpbd.HospitalCode							AS HospitalCode
 FROM  ClaimPayBack cpb
		 LEFT JOIN (
			SELECT 
			 ClaimPayBackId
			 ,ClaimGroupCode
			 ,ItemCount
			 ,Amount
			 ,ClaimOnLineCode
			 ,HospitalCode
			 ,ProductGroupId
			 ,InsuranceCompanyId
			FROM ClaimPayBackDetail
			WHERE IsActive = 1
		 ) cpbd
			ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
		LEFT JOIN [DataCenterV1].[Product].ProductGroup dppg
			ON cpbd.ProductGroupId = dppg.ProductGroup_ID
		LEFT JOIN ClaimGroupType cgt
			ON cpb.ClaimGroupTypeId = cgt.ClaimGroupTypeId
		INNER JOIN #TmpPersonUser pu
			ON pu.User_ID = cpb.CreatedByUserId
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
 WHERE   cpb.ClaimGroupTypeId = @ClaimGroupTypeId
	AND cpb.IsActive = 1
	AND ((cpb.CreatedDate >= @DateFrom) AND (cpb.CreatedDate < DATEADD(Day,1,@DateTo)))
	AND (pg.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL)
	AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)
	 
	--SELECT เอาไปใช้งาน
    SELECT		icu.InsuranceCompany_Name									InsuranceCompany_Name
				,dab.BranchDetail											Branch
				,IIF(@ClaimGroupTypeId IN( 4,6,7),sssmtc.Detail,NULL)		Hospital
				,CASE 
					WHEN @ClaimGroupTypeId IN (2,4,6) THEN TmpCPB.ProductGroupDetailName
					WHEN @ClaimGroupTypeId = 7		  THEN icu.ProductTypeName
					ELSE NULL
				END															ProductGroupDetailName
				,TmpCPB.ClaimGroupType										ClaimGroupType
				,TmpCPB.ClaimGroupCodeFromCPBD								ClaimGroupCode
				,TmpCPB.ItemCount											ItemCount
				,TmpCPB.Amount												Amount
				,NULL														ClaimCompensate
				,icu.ClaimCode												ClaimNo 
				,IIF(@ClaimGroupTypeId IN (2,6,7) , TmpCPB.COL,NULL)		COL
				,IIF(@ClaimGroupTypeId IN (2,4,6,7) ,sssmp.Detail,NULL)		Province
				,IIF(@ClaimGroupTypeId IN (2,4,6,7) ,icu.CustomerName,NULL)	CustomerName
				,CASE 
					WHEN @ClaimGroupTypeId IN (4,6)							THEN sssmtb.Detail
					ELSE NULL
				END												BankName
				,CASE 
					WHEN @ClaimGroupTypeId IN (4,6)							THEN sssmtc.BankAccountName
					ELSE NULL
				END												BankAccountName
				,CASE 
					WHEN @ClaimGroupTypeId IN (4,6)							THEN REPLACE(sssmtc.BankAccountNo,'-','')
					ELSE NULL
				END												BankAccountNo
				,NULL											PhoneNo
				,TmpCPB.CreatedDate								CreatedDate
				,pu.PersonName									ApprovedUser 
				,TmpCPB.CreatedByUser							CteatedUser 
				,icu.ClaimAdmitType								ClaimAdmitType
				,NULL											RecordedDate
				,icu.ClaimPaymentTypeName						ClaimPaymentTypeName
				,icu.ClaimPaymentDetailTypeName					ClaimPaymentTypeDetail
FROM @TmpClaimPayBack TmpCPB
	 LEFT JOIN(

			-- SSS
			SELECT chg.Code										Code
				, chg.InsuranceCompany_Name						InsuranceCompany_Name
				, cat.Detail									ClaimAdmitType
				, chg.Hospital_id								Hospital
				, chg.CreatedBy_id								ApprovedUserFromSSS
				,CONCAT(tt.Detail,ct.FirstName,' ',ct.LastName) CustomerName
				,ch.Code										ClaimCode
				,NULL											BankAccountName
				,NULL											BankAccountNo
				,NULL											BankName
				,NULL											PhoneNo
				,NULL											ProductTypeName
				,NULL											ProductTypeId
				,NULL											ClaimPaymentTypeName
				,NULL											ClaimPaymentDetailTypeName
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
				, pachg.InsuranceCompany_Name					InsuranceCompany_Name
				, smc.Detail									ClaimAdmitType
				, pachg.Hospital_id								Hospital
				, pachg.CreatedBy_id							ApprovedUserFromSSS
				,CONCAT(tt.Detail,cd.FirstName,' ',cd.LastName) CustomerName
				,ch.Code										ClaimCode
				,NULL											BankAccountName
				,NULL											BankAccountNo
				,NULL											BankName
				,NULL											PhoneNo
				,NULL											ProductTypeName
				,NULL											ProductTypeId
				,NULL											ClaimPaymentTypeName
				,NULL											ClaimPaymentDetailTypeName
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
				ClaimHeaderGroupCode									Code
				,InsuranceCompanyName									InsuranceCompany_Name
				,IIF(pd.ProductTypeId <> 11,cxa.ClaimAdmitType,NULL)	ClaimAdmitType
				,h.HospitalCode											Hospital
				,u.EmployeeCode											ApprovedUserFromSSS
				,cm.CustomerName										CustomerName
				,cm.ClaimMiscNo											ClaimCode
				,NULL													BankAccountName
				,NULL													BankAccountNo
				,NULL													BankName
				,ce.ContactPersonPhoneNo								PhoneNo
				,pd.ProductTypeName
				,pd.ProductTypeId
				,cpbType.ClaimPaymentTypeName
				,cpbType.ClaimPaymentDetailTypeName
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
			LEFT JOIN (
				SELECT DISTINCT
				 h.ClaimMiscId
				 ,cp.ClaimPaymentTypeName
				 ,cpd.ClaimPaymentDetailTypeName
				FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] h
				 LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] p
				  ON h.ClaimMiscPaymentHeaderId = p.ClaimMiscPaymentHeaderId
				 LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimPaymentType] cp
				  ON cp.ClaimPaymentTypeId = p.ClaimPaymentTypeId
				 LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimPaymentDetailType] cpd
				  ON cpd.ClaimPaymentDetailTypeId = p.ClaimPaymentDetailTypeId
				 ) cpbType
			 ON cm.ClaimMiscId = cpbType.ClaimMiscId

		) icu
		ON TmpCPB.ClaimGroupCodeFromCPBD = icu.Code
	LEFT JOIN [DataCenterV1].[Address].Branch dab
		ON TmpCPB.BranchId = dab.Branch_ID
	INNER JOIN #TmpPersonUser pu
		ON icu.ApprovedUserFromSSS = pu.EmployeeCode
	LEFT JOIN SSS.dbo.MT_Company sssmtc
		ON icu.Hospital = sssmtc.Code OR icu.Hospital = sssmtc.Code
	LEFT JOIN SSS.dbo.MT_Bank sssmtb
		ON sssmtc.Bank_id = sssmtb.Code
	LEFT JOIN SSS.dbo.DB_Address sssadr
		ON sssmtc.Address_id = sssadr.Code
	LEFT JOIN SSS.dbo.SM_Province sssmp
		ON sssadr.Province_id = sssmp.Code;

IF OBJECT_ID('tempdb..#TmpPersonUser') IS NOT NULL DROP TABLE #TmpPersonUser;
IF OBJECT_ID('tempdb..#TmpProductClaimMisc') IS NOT NULL DROP TABLE #TmpProductClaimMisc;
IF OBJECT_ID('tempdb..@TmpClaimPayBack') IS NOT NULL  DELETE FROM @TmpClaimPayBack;   
END;
GO

/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackSubGroup_Insert]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackSubGroup_Insert]    Script Date: 10/25/2023 9:30:52 AM ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

-- =============================================
-- Author:		Sahatsawat golffy 06958
-- Create date: 20230908
-- Update date: 
-- Description:	For Group ClaimHospital and ClaimCompensate
-- =============================================
CREATE PROCEDURE [dbo].[usp_ClaimPayBackSubGroup_Insert]
-- Add the parameters for the stored procedure here
	@ClaimPayBackTransferId		INT
	,@CreatedByUserId			INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- For Test
	--DECLARE @ClaimPayBackTransferId INT = 389
	--DECLARE @CreatedByUserId INT = 4957

	-- Add the parameters for the stored procedure here
	DECLARE @IsResult			BIT				= 1;
	DECLARE @Result				VARCHAR(100)	= '';
	DECLARE @Msg				NVARCHAR(500)	= '';

	DECLARE @CreatedDate				DATETIME2 = GETDATE();
	DECLARE @ClaimPayBackSubGroupCount	INT = 0;
	DECLARE @ClaimGroupTypeId			INT;

	-- Validate
	SELECT @ClaimPayBackSubGroupCount = COUNT(ClaimPayBackSubGroupId) 
	FROM dbo.ClaimPayBackSubGroup
	WHERE ClaimPayBackTransferId = @ClaimPayBackTransferId

	IF @ClaimPayBackSubGroupCount > 0
		BEGIN
		    SET @IsResult = 0;
			SET @Msg = N'ถูก Generate Group แล้ว';
		END

	SELECT @ClaimGroupTypeId = ClaimGroupTypeId 
	FROM dbo.ClaimPayBack 
	WHERE ClaimPayBackTransferId = @ClaimPayBackTransferId

	IF @ClaimGroupTypeId <> 4
	BEGIN
		SET @IsResult = 0;
		SET @Msg = N'ต้องเป็นเคลมโรงพยาบาลเท่านั้น';
	END

	IF (@IsResult = 1)
		BEGIN

			SELECT cd.ClaimPayBackDetailId
					, cd.ItemCount
					, cd.Amount
					, cd.HospitalCode
					, h.Detail AS HospitalName
					, cd.CreatedDate
					, c.ClaimPayBackTransferId
					--, cd.ProductGroupId
					--, pdg.ProductGroupDetail AS ProductGroup
					,h.ContactEmail
			INTO #TmpHeader
			FROM dbo.ClaimPayBackDetail cd
			LEFT JOIN sss.dbo.vw_CompanyGroupHospital h
				ON cd.HospitalCode = h.Code
			INNER JOIN dbo.ClaimPayBack c
				ON cd.ClaimPayBackId = c.ClaimPayBackId
			--LEFT JOIN DataCenterV1.Product.ProductGroup pdg
			--	ON cd.ProductGroupId = pdg.ProductGroup_ID
			WHERE c.ClaimPayBackTransferId = @ClaimPayBackTransferId
				AND cd.IsActive = 1

			SELECT COUNT(ClaimPayBackDetailId)		ItemCount
					, SUM(Amount)					SumAmount 
					, HospitalCode					HospitalCode
					, MAX(HospitalName) 			HospitalName
					, ROW_NUMBER() OVER(ORDER BY (HospitalCode) asc ) AS rwId
					, ContactEmail
			INTO #TmpGroup
			FROM #TmpHeader
			GROUP BY HospitalCode, ContactEmail;

			DECLARE @TT          VARCHAR(6) = 'HCG'
				  , @Total		 INT 
				  , @YY          VARCHAR(2)
				  , @MM          VARCHAR(2)
				  , @RunningFrom INT
				  , @RunningTo   INT;

			SELECT @Total = MAX(rwId)
			FROM #TmpGroup;

			EXECUTE dbo.usp_GenerateCode_FromTo @TT -- varchar(6)
										   , @Total -- int
										   , @YY OUTPUT -- varchar(2)
										   , @MM OUTPUT -- varchar(2)
										   , @RunningFrom OUTPUT -- int
										   , @RunningTo OUTPUT -- int

	
			-- สร้าง ClaimPayBackSubGroup และเก็บ ClaimPayBackSubGroupId ที่สร้างขึ้นใหม่
			DECLARE @GeneratedIds TABLE (ClaimPayBackSubGroupId INT, HospitalCode VARCHAR(20))

			--SELECT * FROM #TmpHeader
			--SELECT * FROM #TmpGroup

			-----------------------------------
			BEGIN TRY
				BEGIN TRANSACTION
	

				INSERT INTO dbo.ClaimPayBackSubGroup
				(
					ClaimPayBackSubGroupCode
					, Amount
					, ItemCount
					, HospitalCode
					, HospitalName
					, ClaimPayBackTransferId
					, IsActive
					, CreatedDate
					, CreatedByUserId
					, UpdatedDate
					, UpdatedByUserId
					, ContactEmail
				)
				OUTPUT INSERTED.ClaimPayBackSubGroupId, INSERTED.HospitalCode INTO @GeneratedIds (ClaimPayBackSubGroupId, HospitalCode)
				SELECT CONCAT(@TT,@YY,@MM ,FORMAT(@RunningFrom + rwId - 1,'000000')) 
					, SumAmount
					, ItemCount
					, HospitalCode
					, HospitalName
					, @ClaimPayBackTransferId
					, 1
					, @CreatedDate
					, @CreatedByUserId
					, @CreatedDate
					, @CreatedByUserId
					, ContactEmail
				FROM #TmpGroup

				-- อัปเดต ClaimPayBackDetail ด้วย ClaimPayBackSubGroupId
				UPDATE CPBD
				SET CPBD.ClaimPayBackSubGroupId = GID.ClaimPayBackSubGroupId
					, CPBD.UpdatedDate = @CreatedDate
					, CPBD.UpdatedByUserId = @CreatedByUserId
				FROM dbo.ClaimPayBackDetail CPBD
				INNER JOIN #TmpHeader TH 
					ON CPBD.ClaimPayBackDetailId = TH.ClaimPayBackDetailId
				INNER JOIN @GeneratedIds GID 
					ON TH.HospitalCode = GID.HospitalCode;
	
				SET @IsResult   = 1;
				SET @Msg        = 'บันทึก สำเร็จ';
	
				COMMIT TRANSACTION
			END TRY
			BEGIN CATCH
	
				SET @IsResult   = 0;
				SET @Msg        = 'บันทึก ไม่สำเร็จ';
	
				IF (@@Trancount > 0) ROLLBACK;
			END CATCH
			-----------------------------------

		IF OBJECT_ID('tempdb..#TmpHeader') IS NOT NULL  DROP TABLE #TmpHeader;
		IF OBJECT_ID('tempdb..#TmpGroup') IS NOT NULL  DROP TABLE #TmpGroup;
	
	END;
	
	IF (@IsResult = 1) 
		BEGIN
			SET @Result = 'Success';
		END
	ELSE
		BEGIN
			SET @Result = 'Failure';
		END;	
	
	SELECT	@IsResult	AS IsResult
			,@Result	AS Result
			,@Msg		AS Msg;
	
END;
GO

/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackTransferNonClaimCompensateReport_Select]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		06588 Krekpon Dokkamklang Mind
-- Create date: 2024-06-21
-- Description:	รายงานหลังส่งการเงิน
-- Update date: 2024-07-01 06588 Krekpon.D Mind 
-- Description:	เปลี่ยนโค้ดการทำงานใหม่ ให้ทำงานเร็วขึ้น
-- Update date: 2025-08-15 06588 Krekpon.D Mind 
-- Description:	เพิ่มข้อมูลสำหรับ ClaimGroupTypeId =  6
-- Update date: 2025-08-18 06588 Krekpon.D Mind 
-- Description:	remove where product
-- Update date: 2025-08-20 16:26 06588 Krekpon.D Mind 
-- Description:	ปรับการ join ข้อมูล
-- Update date: 2025-10-29 14:31 Sorawit Kamlangsub
-- Update date: 2025-12-09 10.20 Mr.Bunchuai Chaiket (08498)
-- Description:	ปรับการแสดงผล (SELECT ข้อมูลเพิ่ม) จากระบบ ClaimMisc
-- Description:	Add UNION ClaimMisc
-- Update date: 2025-12-24 10.52 06588 Krekpon.D Mind
-- Description:	ปรับเงื่อนไขการแสดงข้อมูลเคลมออนไลน์ไม่ให้แสดง ธนาคาร,ชื่อบัญชี,เลขที่
-- Update date: 2026-01-08 10.14 06588 Krekpon.D Mind
-- Description:	ปรับเงื่อนไขการแสดงข้อมูลเคลม MISC ที่เป็น productIdType 38 ให้แสดง ธนาคาร,ชื่อบัญชี,เลขที่
-- Update date: 2026-01-14 17:00 Sorawit.K
-- Description:	เพิ่ม #TmpProductClaimMisc และปรับการ Join Product เคลมย่อย
-- Update date: 2026-01-15 14:15 Krkepon.D
-- Description:	เอาข้อมูลบัญชีของเคลม Misc ออก
-- Update date: 2026-03-09 Sorawit.k
-- Description:	เพิ่ม ClaimPaymentTypeName,ClaimPaymentTypeDetail
-- =============================================
CREATE PROCEDURE [dbo].[usp_ClaimPayBackTransferNonClaimCompensateReport_Select]
	 @DateFrom			DATE 
	,@DateTo			DATE 
	,@InsuranceId		INT = NULL
	,@ProductGroupId	INT = NULL
	,@ClaimGroupTypeId	INT = NULL
AS
BEGIN

	SET NOCOUNT ON;
    -- Insert statements for procedure here
-- ===============================================
	--DECLARE
	--@DateFrom			DATE = '2025-12-01'
	--,@DateTo			DATE = '2026-01-08'
	--,@InsuranceId		INT = NULL
	--,@ProductGroupId	INT = NULL
	--,@ClaimGroupTypeId	INT = 7;
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
 
--ประกาศ Table เก็บข้อมูลจาก ClaimPayBack
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
 -- เอาข้อมูลลงใน temp แล้วไป JOIN ต่อกับฝั่ง Base อื่น
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
					WHEN @ClaimGroupTypeId IN (4,6)									THEN sssmtb.Detail
					WHEN @ClaimGroupTypeId = 7  AND icu.ProductTypeId = 38			THEN icu.BankName
					ELSE NULL
				END													BankName
				,CASE 
					WHEN @ClaimGroupTypeId IN (4,6)								THEN ssicu.BankAccountName
					WHEN @ClaimGroupTypeId  = 7	 AND icu.ProductTypeId = 38		THEN icu.BankAccountName
					ELSE NULL
				END													BankAccountName
				,CASE 
					WHEN @ClaimGroupTypeId IN (4,6)								THEN REPLACE(ssicu.BankAccountNo,'-','')
					WHEN @ClaimGroupTypeId  = 7	 AND icu.ProductTypeId = 38		THEN icu.BankAccountNo
					ELSE NULL
				END													BankAccountNo
				,CASE 
					WHEN @ClaimGroupTypeId IN (4,6)								THEN NULL
					WHEN @ClaimGroupTypeId  = 7	AND icu.ProductTypeId = 38		THEN icu.PhoneNo
					ELSE NULL
				END													PhoneNo
				,tmpCpbd.CreatedDate								SendDate
				,tmpCpbd.TransferDate								CreatedDate
				,dmeu.PersonName									ApprovedUser
				,tmpCpbd.CreatedByUser								CteatedUser
				,icu.ClaimAdmitType									ClaimAdmitType
				,icu.ClaimPaymentTypeName							ClaimPaymentTypeName
				,icu.ClaimPaymentDetailTypeName						ClaimPaymentTypeDetail
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
				,NULL												ProductTypeId
				,NULL												ClaimPaymentTypeName
				,NULL												ClaimPaymentDetailTypeName
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
				,NULL											ClaimPaymentTypeName
				,NULL											ClaimPaymentDetailTypeName
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
				ClaimHeaderGroupCode										Code
				,InsuranceCompanyName										InsuranceCompany_Name
				,IIF(pd.ProductTypeId <> 11,cxa.ClaimAdmitType,NULL)		ClaimAdmitType
				,h.HospitalCode												Hospital
				,u.EmployeeCode												ApprovedUserFromSSS
				,cm.ClaimMiscNo												ClaimCode
				,cm.CustomerName											CustomerName
				,NUll														BankAccountName
				,NUll														BankAccountNo
				,NUll														BankName
				,ce.ContactPersonPhoneNo									PhoneNo
				,pd.ProductTypeName
				,pd.ProductTypeId
				,cpbType.ClaimPaymentTypeName
				,cpbType.ClaimPaymentDetailTypeName
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
			LEFT JOIN (
				SELECT DISTINCT
				 h.ClaimMiscId
				 ,cp.ClaimPaymentTypeName
				 ,cpd.ClaimPaymentDetailTypeName
				FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] h
				 LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] p
				  ON h.ClaimMiscPaymentHeaderId = p.ClaimMiscPaymentHeaderId
				 LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimPaymentType] cp
				  ON cp.ClaimPaymentTypeId = p.ClaimPaymentTypeId
				 LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimPaymentDetailType] cpd
				  ON cpd.ClaimPaymentDetailTypeId = p.ClaimPaymentDetailTypeId
				 ) cpbType
			 ON cm.ClaimMiscId = cpbType.ClaimMiscId

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
IF OBJECT_ID('tempdb..#TmpProductClaimMisc') IS NOT NULL DROP TABLE #TmpProductClaimMisc;
IF OBJECT_ID('tempdb..@TmpClaimPayBack') IS NOT NULL  DELETE FROM @TmpClaimPayBack;

END;
GO

/****** Object:  StoredProcedure [dbo].[usp_GetDocumentIdDocStorage_Select]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Sorawit KamlangSub
-- Create date: 2025-11-26 15:30
-- Description:	For Get DocStorage Data
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetDocumentIdDocStorage_Select]
	@ClaimHeaderGroupCodes	NVARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT DISTINCT Element
	INTO #Tmplst
	from dbo.func_SplitStringToTable(@ClaimHeaderGroupCodes,',');
	
	SELECT 
		CASE 
			WHEN doc.TbType = 'ClaimMisc' THEN cm.ClaimMiscNo
			WHEN doc.TbType = 'ClaimOnlineAppCode' THEN cm.ApplicationCode
			WHEN doc.TbType = 'ClaimOnlineDocCode' THEN doc.DocumentCode
		END MainIndex
		,cm.ClaimHeaderGroupCode
		,doc.DocumentId
	FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
		INNER JOIN #Tmplst tl
			ON cm.ClaimHeaderGroupCode = tl.Element
		LEFT JOIN
		(
				SELECT
					doc.ClaimMiscId
					,doc.DocumentId
					,doc.DocumentCode
					,doct.DocumentSubTypeId
					,'ClaimMisc'			TbType
				FROM [ClaimMiscellaneous].[misc].[Document] doc
					LEFT JOIN [ClaimMiscellaneous].[misc].[DocumentType] doct
						ON doct.DocumentTypeId = doc.DocumentTypeId
				WHERE doc.IsActive = 1
				AND doc.DocumentTypeId <> 3

				UNION ALL 

				SELECT 
					ClaimMiscId
					,DocumentId
					,DocumentCode
					,DocumentSubTypeId
					,'ClaimOnlineAppCode'			TbType
				FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
				WHERE IsActive = 1
				AND DocumentSubTypeId <> 340

				UNION ALL 

				SELECT 
					ClaimMiscId
					,DocumentId
					,DocumentCode
					,DocumentSubTypeId
					,'ClaimOnlineDocCode'			TbType
				FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
				WHERE IsActive = 1
				AND DocumentSubTypeId <> 340

		) doc
			ON doc.ClaimMiscId = cm.ClaimMiscId
	WHERE cm.IsActive = 1

	IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;

	--DECLARE @MainIndex				NVARCHAR(MAX)
	--DECLARE @DocumentId				UNIQUEIDENTIFIER
	--DECLARE @ClaimHeaderGroupCode	NVARCHAR(MAX)
	--SELECT
	--	@MainIndex				MainIndex
	--	,@DocumentId			DocumentId
	--	,@ClaimHeaderGroupCode	ClaimHeaderGroupCode

END
GO

/****** Object:  StoredProcedure [dbo].[usp_TmpClaimHeaderGroupImport_Validate_V2]    Script Date: 11/6/2569 9:00:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Siriphong Narkphung
-- Create date: 2022-11-02
-- Update date: 2023-08-08	Siriphong	Narkphung	Add ValidateDoc
-- update date:  2024-01-24 Kittisak.Ph 
-- update date:  2024-02-01 Kittisak.Ph เช็ครายการเคลมซ้ำ ใน บ.ส.เดียวกัน
-- update date:	2024-04-23 Kerkpon.Mind เพิ่มเงื่อนไขเช็คว่าเลข claim มีซ้ำ
-- update date: 2024-06-17 Krekpon.Mind เพิ่มเงื่อนไข
-- update date: 2024-07-09 Krekpon.Mind เพิ่ม IsActive
-- update date: 2025-04-11 Wetpisit.P เพิ่ม validate เช็คเลขกรมธรรม์ใน บ.ส.โดยดึงข้อมูล PolicyNo มาใส่ #TmpDetail เพื่อนำไปเช็ค,เพิ่มเงื่อนไขการเช็คจำนวนเอกสารใน #tmpDoc
-- update date: 2025-10-02 10:02 เพิ่ม IsActive ใน LEFT JOIN ClaimHeaderGroupImport
-- Update date: 2025-10-16 14:01 Clear comment Krekpon.D
-- Update date: 2025-10-30 09:34 Add ClaimMisc and Clean Script Sorawit kamlangsub
-- Update date: 2026-03-11 13:16 Add Pa Validate PolicyNo Sorawit kamlangsub
-- Update date: 2026-03-12 08:47 เพิ่ม Validate กรณีเป็น บ.ส.นั้นเป็นเบิกจ่ายกองทุนม้าลาย Sorawit kamlangsub
-- Description:	PROD (P30,1000) dl.DocumentListID = 137 (2000) dl.DocumentListID = 138 
--	UAT  dl.DocumentListID = 134 (2000) dl.DocumentListID = 135
-- =============================================
CREATE PROCEDURE [dbo].[usp_TmpClaimHeaderGroupImport_Validate_V2]
	@TmpCode VARCHAR(20)

AS
BEGIN
	
SET NOCOUNT ON;

--Test Zone
--DECLARE @TmpCode VARCHAR(20) = 'IMCHG6812000071'
--End Test

DECLARE @ClaimHeaderSSS INT = 2;
DECLARE @ClaimHeaderSSSPA INT = 3;
DECLARE @ClaimCompensate INT = 4;
DECLARE @ClaimHeaderPA30 INT = 5;
DECLARE @ClaimMisc INT = 6;
DECLARE @IsResult    BIT             = 1;		
DECLARE @Result        VARCHAR(100) = '';		
DECLARE @Msg        NVARCHAR(500)= '';	
DECLARE @CountIsError INT;

DECLARE @ProductGroup TABLE (ProductGroupId INT ,ProductGroupCode VARCHAR(20));
INSERT @ProductGroup
(
    ProductGroupId
  , ProductGroupCode
)
VALUES
(2,'1000')
,(3,'2000')
,(4,'2222')
,(5,'P30')
,(6,'Misc')
DECLARE @ClaimTypeCode_H	VARCHAR(20) = '1000'
DECLARE @ClaimTypeCode_C	VARCHAR(20) = '2000'
----------------------------------------------

IF @IsResult = 1			
	BEGIN					
	
		SELECT 
			tmp.TmpClaimHeaderGroupImportId
			,tmp.TmpCode
			,tmp.ClaimHeaderGroupCode
			,ISNULL(tmp.ItemCount,0) ItemCount
			,ISNULL(tmp.TotalAmount ,0) TotalAmount
			,tmp.BillingDate
			,tmp.IsValid
			,tmp.ValidateResult
			,tmp.InsuranceCompanyId
			,tmp.ClaimHeaderGroupTypeId
		INTO #Tmp
		FROM dbo.TmpClaimHeaderGroupImport tmp
		WHERE tmp.TmpCode = @TmpCode;


		
		SELECT x.TmpClaimHeaderGroupImportId
              ,m.ClaimHeaderGroupCode
			  ,m.ClaimTypeCode
		INTO #TmpClaimType
		FROM
        (
			SELECT g.Code					ClaimHeaderGroupCode
					,cat.ClaimType_id		ClaimTypeCode

			FROM sss.dbo.DB_ClaimHeaderGroup g
				INNER JOIN sss.dbo.MT_ClaimAdmitType cat
					ON g.ClaimAdmitType_id = cat.Code

		UNION ALL	
        
			SELECT g.Code					ClaimHeaderGroupCode
					,CASE g.ClaimStyle_id
						WHEN '4110'	THEN @ClaimTypeCode_H
						WHEN '4120'	THEN @ClaimTypeCode_H
						WHEN '4130'	THEN @ClaimTypeCode_C
						WHEN '4140'	THEN @ClaimTypeCode_C
						ELSE ''
						END					ClaimTypeCode
			FROM SSSPA.dbo.DB_ClaimHeaderGroup g

		UNION ALL

			SELECT g.ClaimCompensateGroupCode	ClaimHeaderGroupCode
					,@ClaimTypeCode_H			ClaimTypeCode	
			FROM SSS.dbo.ClaimCompensateGroup g
		)m
			INNER JOIN #Tmp x
				ON m.ClaimHeaderGroupCode = x.ClaimHeaderGroupCode;

		
		SELECT d.TmpClaimHeaderGroupImportId
			,d.ClaimHeaderGroupCodeInDB
			,d.TotalAmount
			,d.TotalAmountSS
			,d.InsuranceCompanyId
			,d.ClaimHeaderCodeInDB
			,d.ProductGroup
			,d.PolicyNo
		INTO #TmpDetail
		FROM
			(	--SSS------
				SELECT t.TmpClaimHeaderGroupImportId
						,h.ClaimHeaderGroup_id					AS ClaimHeaderGroupCodeInDB
						,CAST(v.Pay_Total AS DECIMAL(16,2))		AS TotalAmount
						,v.PaySS_Total							AS TotalAmountSS
						,ins.Organize_ID						AS InsuranceCompanyId
						,h.Code									AS ClaimHeaderCodeInDB
						,IIF(h.Product_id = 'P30',h.Product_id,'1000') AS ProductGroup
						,cus.InsuredPolicy_no					AS PolicyNo
				FROM #Tmp t
					LEFT JOIN SSS.dbo.DB_ClaimHeader h
						ON t.ClaimHeaderGroupCode = h.ClaimHeaderGroup_id
					LEFT JOIN SSS.dbo.DB_ClaimVoucher v
						ON h.Code = v.Code
					LEFT JOIN DataCenterV1.Organize.Organize ins
						ON h.InsuranceCompany_id = ins.OrganizeCode
					LEFT JOIN sss.dbo.MT_ClaimType ct
						ON h.ClaimAdmitType_id = ct.Code
					LEFT JOIN sss.dbo.DB_Customer  cus
						ON h.App_id = cus.App_id
				WHERE t.ClaimHeaderGroupTypeId IN(@ClaimHeaderSSS,@ClaimHeaderPA30)


				UNION
				--SSSPA------
				SELECT t.TmpClaimHeaderGroupImportId
						,hg.Code								AS ClaimHeaderGroupCodeInDB
						,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
						,h.PaySS_Total							AS TotalAmountSS
						,ins.Organize_ID						AS InsuranceCompanyId
						,h.Code									AS ClaimHeaderCodeInDB
						,'2000'									AS ProductGroup
						,ctp.Detail								AS PolicyNo
				FROM #Tmp t
					INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg
						ON t.ClaimHeaderGroupCode = hg.Code
					LEFT JOIN SSSPA.dbo.DB_ClaimHeader h
						ON hg.Code = h.ClaimheaderGroup_id
					LEFT JOIN DataCenterV1.Organize.Organize AS ins
						ON hg.InsuranceCompany_id = ins.OrganizeCode
					LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
						ON h.CustomerDetail_id = ctd.Code
					LEFT JOIN SSSPA.dbo.DB_Customer AS cus
						ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090' --ไม่ใช่ยกเลิกกรมธรรม์
					LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
						ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601' --เป็นเลขกรมธรรม์ ปกติ
				WHERE t.ClaimHeaderGroupTypeId = @ClaimHeaderSSSPA

				UNION

				--ClaimCompensate------
				SELECT t.TmpClaimHeaderGroupImportId
					,cg.ClaimCompensateGroupCode				AS ClaimHeaderGroupCodeInDB
					,cc.CompensateRemain						AS TotalAmount
					,cc.CompensateRemain						AS TotalAmountSS
					,ins.Organize_ID							AS InsuranceCompanyId
					,cc.ClaimCompensateCode						AS ClaimHeaderCodeInDB
					,'2222'										AS ProductGroup
					,cus.InsuredPolicy_no						AS PolicyNo
				FROM #Tmp t
					INNER JOIN SSS.dbo.ClaimCompensateGroup cg
						ON t.ClaimHeaderGroupCode = cg.ClaimCompensateGroupCode
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
						ON t.ClaimHeaderGroupCode = h.ClaimHeaderGroup_id
					LEFT JOIN sss.dbo.DB_Customer  cus
						ON h.App_id = cus.App_id
				WHERE t.ClaimHeaderGroupTypeId = @ClaimCompensate

				UNION

				-- ClaimMisc 
				SELECT 
					t.TmpClaimHeaderGroupImportId	
					,cm.ClaimHeaderGroupCode									ClaimHeaderGroupCodeInDB
					,cm.PayAmount												TotalAmount
					,cm.PayAmount												TotalAmountSS
					,org.Organize_ID											InsuranceCompanyId
					,NULL														ClaimHeaderCodeInDB
					,IIF(cpbType.ClaimPaymentTypeId = 2, 'ZebraMisc','Misc')	ProductGroup
					,cm.PolicyNo												PolicyNo
				FROM #Tmp t
					INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm
						ON t.ClaimHeaderGroupCode = cm.ClaimHeaderGroupCode
					LEFT JOIN [ClaimMiscellaneous].[misc].[InsuranceCompany] ins
						ON ins.InsuranceCompanyId = cm.InsuranceCompanyId
					LEFT JOIN [DataCenterV1].[Organize].[Organize] org
						ON org.OrganizeCode = ins.InsuranceCompanyCode
					LEFT JOIN (
							SELECT DISTINCT
								h.ClaimMiscId
								,cp.ClaimPaymentTypeId
								,cp.ClaimPaymentTypeName
							FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] h
								LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] p
								 ON h.ClaimMiscPaymentHeaderId = p.ClaimMiscPaymentHeaderId
								LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimPaymentType] cp
								 ON cp.ClaimPaymentTypeId = p.ClaimPaymentTypeId
								) cpbType
						ON cm.ClaimMiscId = cpbType.ClaimMiscId
			)d;

		----------------Update 2023-08-09-----------------------
		SELECT m.TmpClaimHeaderGroupImportId
			 , m.ClaimHeaderGroupCodeInDB
             , m.ClaimHeaderCodeInDB
			 , m.TotalAmountSS
			 , IIF(m.ProductGroup = 'Misc',1,ISNULL(d.CountDoc,0)) CountDoc
			 , IIF(IIF(m.ProductGroup = 'Misc',1,ISNULL(d.CountDoc,0)) = 0,N'ไม่พบเอกสารแนบ','') ValidateDetailResult
		INTO #TmpDoc
		FROM #TmpDetail m
			LEFT JOIN 
				(
					SELECT  td.ClaimHeaderGroupCodeInDB
							,td.ClaimHeaderCodeInDB
							,CASE 
								WHEN 
									-- ตรวจสอบเอกสาร PH ที่เป็นเคลมโรงพยาบาลต้องมีทั้งเอกสารเคลมโรงพยาบาล(24) กับหนังสือแจ้งชำระค่ารักษาพยาบาล (134,PROD 137)
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup IN ('P30','1000') AND dl.DocumentListID = 24 THEN 1 ELSE 0 END) >= 1
									AND
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup IN ('P30','1000') AND dl.DocumentListID = 137 THEN 1 ELSE 0 END) >= 1
								THEN 1
								WHEN 
									-- ตรวจสอบเอกสาร PA ที่เป็นเคลมโรงพยาบาลต้องมีทั้งเอกสารเคลมโรงพยาบาล(26) กับหนังสือแจ้งชำระค่ารักษาพยาบาล (135,PROD 138)
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup = '2000' AND dl.DocumentListID = 26 THEN 1 ELSE 0 END) >= 1
									AND
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H AND td.ProductGroup = '2000' AND dl.DocumentListID = 138 THEN 1 ELSE 0 END) >= 1
								THEN 1
								WHEN 
									-- กรณีเป็นเคลมสาขา ต้องไม่มีของเคลมโรงพยาบาล
									SUM(CASE WHEN ct.ClaimTypeCode = @ClaimTypeCode_H THEN 1 ELSE 0 END) = 0
								THEN 1
								WHEN 
									-- กรณีเป็นเคลมโอนแยก
									MAX(CASE WHEN td.ProductGroup = '2222' THEN 1 ELSE 0 END) = 1
								THEN 1
								ELSE 0
							 END AS CountDoc
					FROM ISC_SmileDoc.dbo.DocumentIndexData dd WITH(NOLOCK)
						LEFT JOIN ISC_SmileDoc.dbo.Document d WITH(NOLOCK)
							ON dd.DocumentID = d.DocumentID
						LEFT JOIN 
						(
							SELECT
								DocumentListID
							FROM ISC_SmileDoc.dbo.DocumentList 
							WHERE DocumentTypeId IN (5,6)
						) dl
							ON d.DocumentListID = dl.DocumentListID
						INNER JOIN #TmpDetail td
							ON dd.DocumentIndexData = td.ClaimHeaderCodeInDB COLLATE DATABASE_DEFAULT
						INNER JOIN #TmpClaimType ct
							ON td.ClaimHeaderGroupCodeInDB = ct.ClaimHeaderGroupCode
					WHERE d.IsEnable = 1
					GROUP BY td.ClaimHeaderGroupCodeInDB, td.ClaimHeaderCodeInDB
				)d
				ON m.ClaimHeaderCodeInDB = d.ClaimHeaderCodeInDB
				AND m.ClaimHeaderGroupCodeInDB = d.ClaimHeaderGroupCodeInDB;

		---------------------------------------------------------------------------

		SELECT 
				t.TmpClaimHeaderGroupImportId
				,t.ClaimHeaderGroupCode
				,t.TmpCode
				,c.InsuranceCompanyId
				,t.ItemCount
				,t.TotalAmount
				,c.ItemCountInDB
				,c.TotalAmountInDB
				,imd.ClaimCodeInSystem AS ClaimCodeInSystem
				,img.ClaimHeaderGroupCode AS ClaimHeaderGroupInSystem
				,s.ClaimHeaderGroupCode AS ClaimHeaderGroupCodeInFlie
				,c.ClaimHeaderGroupCodeInDB
				----------------------Update 2023-08-08--------------------
				,CONCAT
					(
						 IIF(s.ClaimHeaderGroupCode IS NOT NULL,N'รายการ บ.ส. ซ้ำกันในไฟล์, ','')
						,IIF(img.ClaimHeaderGroupCode IS NOT NULL,N'รายการ บ.ส. ซ้ำกับในระบบ, ','')
						,IIF(c.ClaimHeaderGroupCodeInDB IS NULL, N'ไม่พบเลข บ.ส. นี้ในฐานข้อมูล, ','')
						,IIF(t.ItemCount<>ISNULL(c.ItemCountInDB,0) AND t.ClaimHeaderGroupTypeId = pg.ProductGroupId AND s.ClaimHeaderGroupCode IS NULL,N'ข้อมูลจำนวนเคลมไม่ตรงกับในฐานข้อมูล, ','')
						,IIF(t.TotalAmount = 0,N'ไม่มียอดเงินในรายการ บ.ส., ','')
						,IIF(t.TotalAmount<>ISNULL(c.TotalAmountInDB,0) AND t.ClaimHeaderGroupTypeId = pg.ProductGroupId AND s.ClaimHeaderGroupCode IS NULL,CONCAT(N'ข้อมูลจำนวนเงินรวมไม่ตรงกับในฐานข้อมูล','( ',FORMAT(c.TotalAmountInDB,'N'),'), '),'')
						,IIF(imd.ClaimCodeInSystem IS NOT NULL AND t.ClaimHeaderGroupCode LIKE '%_0' AND cbd.ClaimGroupCode = t.ClaimHeaderGroupCode AND imd.ClaimHeaderGroupCode = t.ClaimHeaderGroupCode ,N'มีรายการเคลมนี้ในระบบแล้ว, ','') -- Update 2024-02-01 Kittisak.Ph เช็ครายการเคลมซ้ำ ใน บ.ส.เดียวกัน --Update 2024-06-17 Krekpon.Mind เพิ่มเงื่อนไข
						,IIF(t.ClaimHeaderGroupTypeId <> pg.ProductGroupId ,CONCAT(N'รายการ บ.ส. นี้ ไม่ใช่กลุ่ม', 
									' ',
									--IIF(t.ClaimHeaderGroupTypeId = @ClaimHeaderSSS,'PH','PA30')
									CASE
										WHEN
											t.ClaimHeaderGroupTypeId = @ClaimHeaderSSS
										THEN 'PH'
										WHEN 
											t.ClaimHeaderGroupTypeId = @ClaimHeaderSSSPA
										THEN 
											'PA30'
										WHEN 
											t.ClaimHeaderGroupTypeId = @ClaimMisc
										THEN 
											'เบ็ดเตล็ด'
										ELSE
											'-'
									END
									,N' ตามกลุ่มที่ระบุ, '),'')
						,IIF(doc.CountDoc > 0 ,N'บ.ส. ไม่มีเอกสารแนบ, ','')
						,IIF(a.ClaimTypeCode = '',N'ไม่ได้ MappingType (H,C), ','')
						,IIF(c.ProductGroup = '2000' AND (c.PolicyNo = '' OR c.PolicyNo IS NULL),'ไม่มีเลขกรมธรรม์','' )
						,IIF(c.ProductGroup = 'ZebraMisc', 'ตรวจสอบรายการเคลมกองทุนรถม้าลาย','')
					)ValidateResult
				---------------------------------------------------------------
				,IIF(t.ClaimHeaderGroupTypeId = 6 ,'2000',a.ClaimTypeCode)	ClaimTypeCode

		INTO #TmpUpdate
		FROM #Tmp t
			LEFT JOIN 
				(
					SELECT ClaimHeaderGroupCodeInDB
						,InsuranceCompanyId
						,COUNT(ClaimHeaderGroupCodeInDB) ItemCountInDB
						,SUM(TotalAmountSS)  TotalAmountInDB
						,MAX(ProductGroup)	ProductGroup
						,PolicyNo
					FROM #TmpDetail
					GROUP BY ClaimHeaderGroupCodeInDB,InsuranceCompanyId,PolicyNo
				) c
				ON t.ClaimHeaderGroupCode = c.ClaimHeaderGroupCodeInDB
			LEFT JOIN @ProductGroup pg
				ON c.ProductGroup = pg.ProductGroupCode
			LEFT JOIN (
				SELECT *
				FROM dbo.ClaimHeaderGroupImport
				WHERE IsActive = 1
			) img
				ON t.ClaimHeaderGroupCode = img.ClaimHeaderGroupCode
			LEFT JOIN
				(
					SELECT  d.ClaimHeaderGroupCodeInDB AS ClaimCodeInSystem
							,imd.ClaimHeaderGroupCode AS ClaimHeaderGroupCode --Update 2024-06-17 Krekpon.Mind เพิ่มเงื่อนไข
					FROM #TmpDetail d
						INNER JOIN dbo.ClaimHeaderGroupImportDetail imd 
							ON d.ClaimHeaderCodeInDB = imd.ClaimCode
					WHERE d.ClaimHeaderCodeInDB = imd.ClaimCode -- ลองเปลี่ยนเป็น Where 2024-04-23 Krekpon-Mind
						  AND imd.IsActive = 1 -- 2024-07-09 Krekpon.Mind เพิ่ม IsActive
					GROUP BY d.ClaimHeaderGroupCodeInDB,imd.ClaimHeaderGroupCode
				) imd
				ON t.ClaimHeaderGroupCode = imd.ClaimCodeInSystem
			LEFT JOIN 
				(
					SELECT ClaimHeaderGroupCode
						,COUNT(TmpClaimHeaderGroupImportId) xCount
					FROM #Tmp 
					GROUP BY ClaimHeaderGroupCode
					HAVING COUNT(TmpClaimHeaderGroupImportId) >1
				)s
				ON t.ClaimHeaderGroupCode = s.ClaimHeaderGroupCode

			LEFT JOIN #TmpClaimType a
				ON t.TmpClaimHeaderGroupImportId = a.TmpClaimHeaderGroupImportId
			-------------------------Update 2023-08-09--------------------
			LEFT JOIN 
				(
					SELECT ClaimHeaderGroupCodeInDB
						,COUNT(ClaimHeaderGroupCodeInDB) CountDoc
					FROM #TmpDoc
					WHERE CountDoc = 0
					GROUP BY ClaimHeaderGroupCodeInDB
				) doc
				ON t.ClaimHeaderGroupCode = doc.ClaimHeaderGroupCodeInDB
			-------------------------------------------------------------------	
			LEFT JOIN [ClaimPayBack].[dbo].[ClaimPayBackDetail] cbd ON cbd.ClaimGroupCode = t.ClaimHeaderGroupCode
			SELECT @CountIsError = COUNT(ValidateResult)
			FROM #TmpUpdate
			WHERE TmpCode = @TmpCode 
			AND ValidateResult <>'';

			IF @CountIsError IS NULL SET @CountIsError = 0;

		------------------------------------------------------

		BEGIN TRY			
			BEGIN TRANSACTION
				
				--SELECT *
				DELETE hd
				FROM dbo.TmpClaimHeaderGroupImportDetail hd
					INNER JOIN #TmpDoc d
						ON hd.TmpClaimHeaderGroupImportId = d.TmpClaimHeaderGroupImportId;

				INSERT INTO dbo.TmpClaimHeaderGroupImportDetail
				(
				    TmpClaimHeaderGroupImportId
				  , ClaimHeaderCode
				  , DocumentCount
				  , Amount
				  , ValidateDetailResult
				  ,IsValid
				)
				SELECT TmpClaimHeaderGroupImportId
                     , ClaimHeaderCodeInDB
                     , CountDoc 
					 ,TotalAmountSS
					 ,ValidateDetailResult
					 ,IIF(ValidateDetailResult = '',1,0)	IsValid
				FROM #TmpDoc 
				WHERE ClaimHeaderGroupCodeInDB IS NOT NULL
				ORDER BY TmpClaimHeaderGroupImportId;

				--SELECT *
				UPDATE m
					SET m.ValidateResult = u.ValidateResult
					,m.IsValid = IIF(u.ValidateResult = '',1,0)
					,m.InsuranceCompanyId = u.InsuranceCompanyId
					,m.ClaimTypeCode = u.ClaimTypeCode
				FROM dbo.TmpClaimHeaderGroupImport m
					INNER JOIN #TmpUpdate u
						ON m.TmpClaimHeaderGroupImportId = u.TmpClaimHeaderGroupImportId;


			SET @IsResult = 1			  					
			SET @Msg = 'บันทึก สำเร็จ'	 												  					
			COMMIT TRANSACTION			  					
		END TRY							  					
		BEGIN CATCH						  					
										  					
			SET @IsResult = 0			  					
			SET @Msg = 'บันทึก ไม่สำเร็จ'						
										  					
			IF @@TRANCOUNT > 0 ROLLBACK	  					
		END CATCH
		
IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;
IF OBJECT_ID('tempdb..#TmpDetail') IS NOT NULL  DROP TABLE #TmpDetail;
IF OBJECT_ID('tempdb..#TmpDoc') IS NOT NULL  DROP TABLE #TmpDoc;
IF OBJECT_ID('tempdb..#TmpUpdate') IS NOT NULL  DROP TABLE #TmpUpdate;
IF OBJECT_ID('tempdb..#TmpClaimType') IS NOT NULL  DROP TABLE #TmpClaimType;	

	END									  					
										  					
IF @IsResult = 1	BEGIN	SET @Result = IIF(@CountIsError = 0,1,0) END
ELSE				BEGIN	SET @Result = 'Failure'END	
			
							  								
            							  					
       SELECT @IsResult IsResult		  					
		,@Result Result					  					
		,@Msg	 Msg 		



END
GO

