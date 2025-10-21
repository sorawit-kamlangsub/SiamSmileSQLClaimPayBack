USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [Claim].[usp_ClaimHeaderGroupDetail_SelectV5]    Script Date: 21/10/2568 15:12:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Sorawit KamlangSub
-- Create date: 2025-10-17 14:30
-- Description:	
-- =============================================
ALTER PROCEDURE [Claim].[usp_ClaimHeaderGroupDetail_SelectV5]
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
AS
BEGIN
	SET NOCOUNT ON;

--DECLARE @ProductGroupId		INT 				= 4;
--DECLARE @InsuranceId			INT				= NULL;
--DECLARE @ClaimGroupTypeId		INT				= 7;
--DECLARE @BranchId				INT				= NULL;
--DECLARE @CreateByUser_Code		VARCHAR(20)		= NULL;
--DECLARE @IndexStart			INT					= NULL;
--DECLARE @PageSize				INT				= NULL;
--DECLARE @SortField				NVARCHAR(MAX)	= NULL;
--DECLARE @OrderType				NVARCHAR(MAX)	= NULL;
--DECLARE @SearchDetail			NVARCHAR(MAX)	= NULL;
--DECLARE @IsShowDocumentLink	BIT				= NULL

DECLARE @pInsCode				VARCHAR(20)		= NULL	/*ถ้าส่ง @InsuranceId จะ set*/
DECLARE @pBranchCode			VARCHAR(20)		= NULL	/*ถ้าส่ง @BranchId จะ set*/
DECLARE @pProductGroupId		INT				= @ProductGroupId
DECLARE @pClaimGroupTypeId		INT				= @ClaimGroupTypeId
DECLARE @pIsValidDoc			BIT				= @IsShowDocumentLink
DECLARE @pCreatedByCode			VARCHAR(20)		= @CreateByUser_Code

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
WHERE OrganizeType_ID = 2;


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
);

CREATE TABLE #TmpDoc 
(
	ClaimHeaderGroupCode VARCHAR(20) 
	,ClaimHeaderCode VARCHAR(20)
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
				,TransferAmount)
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

		FROM sss.dbo.ClaimCompensate c	WITH (NOLOCK)
			INNER JOIN sss.dbo.ClaimCompensateGroup cg	WITH (NOLOCK)
				ON c.ClaimCompensateGroupId = cg.ClaimCompensateGroupId
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
				,TransferAmount)
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

		FROM sss.dbo.DB_ClaimHeaderGroupItem i			WITH (NOLOCK)
			INNER JOIN SSS.dbo.DB_ClaimHeaderGroup g	WITH (NOLOCK)
				ON i.ClaimHeaderGroup_id = g.Code
			LEFT JOIN #TmpCAT cat
				ON g.ClaimAdmitType_id = cat.Code
			LEFT JOIN sss.dbo.DB_ClaimHeader cl			WITH (NOLOCK)
				ON i.ClaimHeader_id = cl.Code
			LEFT JOIN sss.dbo.DB_ClaimVoucher v			WITH (NOLOCK)
				ON i.ClaimHeader_id = v.Code
			--LEFT JOIN
			--	(
			--		SELECT 
			--			co.ClaimOnLineId
			--			,co.ClaimOnLineCode
			--			,cg.PaymentStatusId 
			--			,SUM(cg.TotalAmount) TotalAmount
			--		FROM ClaimOnlineV2.dbo.ClaimOnline co
			--			LEFT JOIN ClaimOnlineV2.dbo.ClaimPayGroup cg
			--				ON cg.ClaimOnLineId = co.ClaimOnLineId
			--		WHERE co.IsActive = 1
			--			AND cg.IsActive = 1 
			--			AND cg.PaymentStatusId = 4
			--		GROUP BY co.ClaimOnLineId, co.ClaimOnLineCode, cg.PaymentStatusId
			--	) colPH
			--	ON colPH.ClaimOnLineCode = cl.ClaimOnLineCode 
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
						--AND colPH.PaymentStatusId IS NULL
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
				,TransferAmount)
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

		FROM SSSPA.dbo.DB_ClaimHeaderGroupItem i WITH (NOLOCK)
			INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup g WITH (NOLOCK)
				ON i.ClaimHeaderGroup_id = g.Code
			LEFT JOIN SSSPA.dbo.DB_ClaimHeader c
				ON i.ClaimHeader_id = c.Code
			--LEFT JOIN
			--	(
			--		SELECT 
			--			co.ClaimOnLineId
			--			,co.ClaimOnLineCode
			--			,cg.PaymentStatusId 
			--			,SUM(cg.TotalAmount)	TotalAmount
			--		FROM ClaimOnlineV2.dbo.ClaimOnline co
			--			LEFT JOIN ClaimOnlineV2.dbo.ClaimPayGroup cg
			--				ON cg.ClaimOnLineId = co.ClaimOnLineId
			--		WHERE co.IsActive = 1 
			--			AND cg.IsActive = 1 
			--			AND cg.PaymentStatusId = 4
			--		GROUP BY co.ClaimOnLineId, co.ClaimOnLineCode, cg.PaymentStatusId
			--	) colPA
			--	ON colPA.ClaimOnLineCode = c.ClaimOnLineCode  
		WHERE (g.InsuranceCompany_id = @pInsCode OR @pInsCode IS NULL)
			AND (g.Branch_id = @pBranchCode OR @pBranchCode IS NULL)
			AND (g.CreatedBy_id = @pCreatedByCode OR @pCreatedByCode IS NULL)
			AND (g.Code = @pSearchDetail OR @pSearchDetail IS NULL)				
			AND	(
					(
						@pClaimGroupTypeId = 2
						AND g.IsClaimOnLine = 1
						AND g.CreatedDate >= @CreatedDateFrom
						AND (c.ClaimType_id IN('4001','4002','4003','4004','4009','4010') OR (c.ClaimType_id='4005' AND c.CreatedDate >@DisabilityCutoffDate))
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
						AND c.ClaimType_id IN ('4006','4006_2','4007','4008')
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
ELSE IF @pProductGroupId IN (4,5,6,7,8,9,10,11) AND @pClaimGroupTypeId = 7
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
				,TransferAmount)		
		SELECT 
				cm.ClaimHeaderGroupCode				ClaimHeaderGroupCode
				,1									ClaimHeaderCode
				,cm.BranchId						BranchCode
				,ISNULL(ud.EmployeeCode, '00000')	CreatedByCode
				,cm.CreatedDate						CreatedDate
				,cm.InsuranceCompanyCode			InsuranceCompanyCode
				,cm.InsuranceCompanyName			InsuranceCompanyName 
				,pd.ProductGroup_ID					ProductGroupId
				,'0'								xRevise
				,cm.ClaimAmount						amount 
				,@pClaimGroupTypeId					ClaimGroupTypeId
				,NULL								TransferAmount
		FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			INNER JOIN [ClaimPayBack].[dbo].[ClaimPayBackProductGroup] pd
				ON cm.ProductTypeId = pd.MappingXCliamMisc
			INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] cmh
				ON cm.ClaimMiscId = cmh.ClaimMiscId
			INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] cmp
				ON cmh.ClaimMiscPaymentHeaderId = cmp.ClaimMiscPaymentHeaderId
			LEFT JOIN 
			(
					SELECT 
						vpu.UserId
						,ve.EmployeeCode
					FROM [DataCenterV1].[Master].vw_PersonUser vpu
						INNER JOIN [DataCenterV1].[Master].vw_Employee ve
							ON vpu.EmployeeId = ve.EmployeeId 
			)ud
				ON ud.UserId = cm.CreatedByUserId
		WHERE cm.IsActive = 1
			AND cmh.IsActive = 1
			AND pd.ProductGroup_ID = @pProductGroupId
			AND cm.ClaimMiscStatusId = 3
			AND cmp.IsActive = 1
			AND cmp.PaymentStatusId = 4
			AND cm.ClaimHeaderGroupCode IS NOT NULL
			AND NOT EXISTS	
			(
				SELECT x.ClaimCode
				FROM dbo.ClaimPayBackXClaim x	WITH(NOLOCK)
				LEFT JOIN dbo.ClaimPayBackDetail cd	WITH(NOLOCK)
					ON x.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
				LEFT JOIN dbo.ClaimPayBack cp
					ON cd.ClaimPayBackId = cp.ClaimPayBackId
				WHERE x.IsActive = 1
					AND cp.ClaimGroupTypeId = @pClaimGroupTypeId
					AND cd.ProductGroupId = @pProductGroupId
					AND x.ClaimCode = cm.ClaimMiscCode
			)
	END

SELECT * 
		,ROW_NUMBER() OVER(ORDER BY (a.ClaimHeaderGroupCode) ASC) rwId
INTO #TmpCondition
FROM #Tmplst a
WHERE a.xRevise = '0';

IF @pClaimGroupTypeId <> 4
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
		--,IIF(g.ItemCount = doc.docCount ,1,0)					DocumentCount	 
		,1													DocumentCount
		,g.TransferAmount										TransferAmount
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
	LEFT JOIN 
	(
		SELECT
			Code
			,Detail
		FROM sss.dbo.MT_Branch
		UNION
		SELECT
			CAST(Branch_ID AS VARCHAR(20))	Code
			,BranchDetail					Detail
		FROM DataCenterV1.Address.Branch
	) b
		ON b.Code = d.BranchCode COLLATE DATABASE_DEFAULT
	LEFT JOIN sss.dbo.DB_Employee eC
		ON d.CreatedByCode = eC.Code COLLATE DATABASE_DEFAULT

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