USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [Claim].[usp_ClaimHeaderGroupDetail_SelectV5]    Script Date: 2025-10-21 10:33:10 ******/
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
	 @ProductGroupId		INT
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

--DECLARE @ProductGroupId			INT 			= 4;
--DECLARE @InsuranceId			INT				= NULL;
--DECLARE @ClaimGroupTypeId		INT				= 7;
--DECLARE @BranchId				INT				= NULL;
--DECLARE @CreateByUser_Code		VARCHAR(20)		= NULL;
--DECLARE @IndexStart				INT				= NULL;
--DECLARE @PageSize				INT				= NULL;
--DECLARE @SortField				NVARCHAR(MAX)	= NULL;
--DECLARE @OrderType				NVARCHAR(MAX)	= NULL;
--DECLARE @SearchDetail			NVARCHAR(MAX)	= NULL;
--DECLARE @IsShowDocumentLink	BIT					= NULL;

DECLARE @pInsCode				VARCHAR(20)		= NULL;	/*ถ้าส่ง @InsuranceId จะ set*/
DECLARE @pBranchCode			VARCHAR(20)		= NULL;	/*ถ้าส่ง @BranchId จะ set*/


/*Set Page*/
IF @IndexStart		IS NULL	SET @IndexStart = 0;
IF @PageSize		IS NULL	SET @PageSize	 = 10;
IF @SearchDetail IS NULL OR @SearchDetail = ''	SET @SearchDetail = NULL;


DECLARE @pg_2	INT = 2;
DECLARE @pg_3	INT = 3;
DECLARE @B_9901	VARCHAR(20) = '9901';

DECLARE @ClaimType_1000 VARCHAR(20) = '1000';
DECLARE @ClaimType_2000	VARCHAR(20) = '2000';

DECLARE @CalimAdmitType_1001 VARCHAR(20) = '1001';
DECLARE @CalimAdmitType_3001 VARCHAR(20) = '3001';

DECLARE @fix_ClaimCompensateCreatedDatefrom DATETIME = '2023-12-08'	/*ClaimCompensate*/

DECLARE @fix_OpdDateCutoff	DATETIME = '2023-12-08';	/*OpdDateCutoff*/
DECLARE @fix_IpdDateCutoff	DATETIME = '2023-10-26';
DECLARE @fix_CutoffEndDATE	DATETIME = '2024-01-09'	/*CutoffEndDate*/
DECLARE @CreatedDateFrom DATETIME = '2023-11-27';

DECLARE @InsSMICode VARCHAR(20) = '100000000041';
DECLARE @DisabilityCutoffDate DATE = '2025-08-18';

DECLARE @ClaimMiscId		INT = 12;
DECLARE @ClaimMiscCPBId		INT = 4;
DECLARE @ClaimMiscProductName	VARCHAR(20) = 'Motor';

/*
ClaimGroupTypeId	ClaimGroupType
2	เคลมออนไลน์
3	เคลมสาขา
4	เคลมโรงพยาบาล
5	เคลมโอนแยก
6	เคลมเสียชีวิต ทุพพลภาพ
*/

/*Tmp Declare */
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

/*Get Master */
	SELECT Code
			,ClaimType_id 
			,CASE Code
				WHEN @CalimAdmitType_1001 THEN 1
				WHEN @CalimAdmitType_3001 THEN 1
				ELSE 0
			END xFlag
	INTO #TmpCAT
	FROM [SSS].[dbo].[MT_ClaimAdmitType] WITH (NOLOCK);

	SELECT @pInsCode = OrganizeCode
	FROM [DataCenterV1].[Organize].[Organize] WITH (NOLOCK)
	WHERE OrganizeType_ID = 2
		AND Organize_ID = @InsuranceId;

	SELECT @pBranchCode = CAST(tempcode AS VARCHAR(20))
	FROM [DataCenterV1].[Address].[Branch] WITH (NOLOCK)
	WHERE Branch_ID = @BranchId;

 ---------------------------------------------------------------------

IF @ProductGroupId = 2 AND @ClaimGroupTypeId = 5
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
				,@ClaimGroupTypeId						ClaimGroupTypeId
				,0										TransferAmount
		FROM [SSS].[dbo].[ClaimCompensateGroup] cg
			INNER JOIN [SSS].[dbo].[ClaimCompensate] c
				ON cg.ClaimCompensateGroupId = c.ClaimCompensateGroupId
		WHERE cg.ItemCount > 0
			AND cg.CreatedDate >= @fix_ClaimCompensateCreatedDatefrom
			AND (cg.InsuranceCompanyCode = @pInsCode OR @pInsCode IS NULL)
			AND (cg.CreatedByCode = @CreateByUser_Code OR @CreateByUser_Code IS NULL)
			AND (cg.ClaimCompensateGroupCode = @SearchDetail OR @SearchDetail IS NULL)
			AND NOT EXISTS	(
								SELECT 1
								FROM dbo.ClaimPayBackXClaim x
									LEFT JOIN dbo.ClaimPayBackDetail cd
										ON x.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
									LEFT JOIN dbo.ClaimPayBack cp
										ON cd.ClaimPayBackId = cp.ClaimPayBackId
								WHERE x.IsActive = 1
									AND x.ClaimCode = c.ClaimHeaderCode
									AND cd.ProductGroupId = @ProductGroupId
									AND cp.ClaimGroupTypeId = @ClaimGroupTypeId
							); 

	END 
-- PH
ELSE IF @ProductGroupId = 2 AND @ClaimGroupTypeId IN (2,3,4,6)
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
				,@ClaimGroupTypeId											ClaimGroupTypeId
				,0															TransferAmount
		FROM [SSS].[dbo].[DB_ClaimHeaderGroup] g
			INNER JOIN [SSS].[dbo].[DB_ClaimHeaderGroupItem] i
				ON g.Code = i.ClaimHeaderGroup_id
			LEFT JOIN #TmpCAT cat
				ON g.ClaimAdmitType_id = cat.Code
			LEFT JOIN [SSS].[dbo].[DB_ClaimHeader] cl
				ON i.ClaimHeader_id = cl.Code
			LEFT JOIN [SSS].[dbo].[DB_ClaimVoucher] v
				ON i.ClaimHeader_id = v.Code
		WHERE (g.InsuranceCompany_id = @pInsCode OR @pInsCode IS NULL)
			AND (g.Branch_id = @pBranchCode OR @pBranchCode IS NULL)
			AND (g.Code = @SearchDetail OR @SearchDetail IS NULL)
			AND
			(
				(
					@ClaimGroupTypeId = 4 
						AND cat.xFlag = 1
						AND	cl.ClaimPaybackStatus = 1
						AND	(cl.UpdatedByCode = @CreateByUser_Code OR @CreateByUser_Code IS NULL)
				)
				OR 
				(
					cat.xFlag = 0
						AND	(g.CreatedBy_id = @CreateByUser_Code OR @CreateByUser_Code IS NULL)
				)
			)
			AND	
			(
				(
					@ClaimGroupTypeId = 2	
						AND g.IsClaimOnLine = 1
						AND cat.xFlag = 0
						AND g.CreatedDate >= @fix_OpdDateCutoff 
						AND g.ClaimAdmitType_id NOT IN('4000','4001','5001','5002') 
				) 
				OR	
				(
					@ClaimGroupTypeId = 3	
						AND (g.IsClaimOnLine IS NULL OR g.IsClaimOnLine = 0)
						AND cat.ClaimType_id = @ClaimType_2000	
						AND cat.xFlag = 0
						AND g.CreatedDate >= @fix_OpdDateCutoff
				)
				OR	
				(
					@ClaimGroupTypeId = 4	
						AND (g.IsClaimOnLine IS NULL OR g.IsClaimOnLine = 0)
						AND cat.ClaimType_id = @ClaimType_1000	
						AND 
						(
							(
								cat.xFlag = 0 AND G.CreatedDate >= @fix_OpdDateCutoff
							)
							OR	
							(
								cat.xFlag = 1 AND cl.ClaimPaybackStatus = 1 AND g.CreatedDate >= @fix_CutoffEndDATE
							)
						)
				)
				OR 
				(
					@ClaimGroupTypeId = 6
						AND g.IsClaimOnLine = 1
						AND cat.xFlag = 0
						AND g.CreatedDate >= @fix_OpdDateCutoff
						AND g.ClaimAdmitType_id IN('4000','4001','5001','5002')
				)
			)
			AND NOT EXISTS	(
								SELECT 1
								FROM dbo.ClaimPayBackXClaim x
									LEFT JOIN dbo.ClaimPayBackDetail cd
										ON x.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
									LEFT JOIN dbo.ClaimPayBack cp
										ON cd.ClaimPayBackId = cp.ClaimPayBackId
								WHERE x.IsActive = 1
									AND x.ClaimCode = i.ClaimHeader_id 
									AND cp.ClaimGroupTypeId = @ClaimGroupTypeId
									AND cd.ProductGroupId = @ProductGroupId
							);
	
	END
-- PA
ELSE IF @ProductGroupId = 3 AND @ClaimGroupTypeId IN (2,3,4,6)
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
				,@ClaimGroupTypeId											ClaimGroupTypeId
				,0															TransferAmount
		FROM [SSSPA].[dbo].[DB_ClaimHeaderGroup] g
			INNER JOIN [SSSPA].[dbo].[DB_ClaimHeaderGroupItem] i
				ON g.Code = i.ClaimHeaderGroup_id
			LEFT JOIN [SSSPA].[dbo].[DB_ClaimHeader] c
				ON i.ClaimHeader_id = c.Code
		WHERE (g.InsuranceCompany_id = @pInsCode OR @pInsCode IS NULL)
			AND (g.Branch_id = @pBranchCode OR @pBranchCode IS NULL)
			AND (g.CreatedBy_id = @CreateByUser_Code OR @CreateByUser_Code IS NULL)
			AND (g.Code = @SearchDetail OR @SearchDetail IS NULL)
			AND c.Status_id NOT IN ('3570','3580') 
			AND	
			(
				(
					@ClaimGroupTypeId = 2
					AND g.IsClaimOnLine = 1
					AND g.CreatedDate >= @CreatedDateFrom
					AND (
							c.ClaimType_id IN('4001','4002','4003','4004','4009','4010') 
							OR (c.ClaimType_id='4005' AND c.CreatedDate >@DisabilityCutoffDate)
						)
				)
				OR	
				(
						@ClaimGroupTypeId = 3
						AND (g.IsClaimOnLine = 0 OR g.IsClaimOnLine IS NULL)
						AND g.ClaimStyle_id IN ('4130','4140')
						AND g.CreatedDate >= @CreatedDateFrom
				)
				OR	
				(
						@ClaimGroupTypeId = 4
						AND (g.IsClaimOnLine = 0 OR g.IsClaimOnLine IS NULL)
						AND g.ClaimStyle_id IN ('4110','4120')
						AND g.CreatedDate >= @fix_IpdDateCutoff
				)
				OR	
				(
						@ClaimGroupTypeId = 6
						AND (g.IsClaimOnLine = 1)
						AND c.ClaimType_id IN ('4006','4006_2','4007','4008')
						AND g.CreatedDate >= @fix_IpdDateCutoff
				)
			)
			AND NOT EXISTS	(
								SELECT 1
								FROM dbo.ClaimPayBackXClaim x
									LEFT JOIN dbo.ClaimPayBackDetail cd
										ON x.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
									LEFT JOIN dbo.ClaimPayBack cp
										ON cd.ClaimPayBackId = cp.ClaimPayBackId
								WHERE x.IsActive = 1
									AND x.ClaimCode = i.ClaimHeader_id 
									AND cp.ClaimGroupTypeId = @ClaimGroupTypeId
									AND cd.ProductGroupId = @ProductGroupId
									
							);
			 
	END
-- ClaimMisc
ELSE IF @ProductGroupId = 4 AND @ClaimGroupTypeId = 7
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
				,b.tempcode							BranchCode
				,ISNULL(e.EmployeeCode, '00000')	CreatedByCode
				,cm.CreatedDate						CreatedDate
				,cm.InsuranceCompanyCode			InsuranceCompanyCode
				,cm.InsuranceCompanyName			InsuranceCompanyName 
				,@ClaimMiscCPBId					ProductGroupId
				,'0'								xRevise
				,cm.ClaimAmount						amount 
				,@ClaimGroupTypeId					ClaimGroupTypeId
				,NULL								TransferAmount
		FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] cmh
				ON cm.ClaimMiscId = cmh.ClaimMiscId
			INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] cmp
				ON cmh.ClaimMiscPaymentHeaderId = cmp.ClaimMiscPaymentHeaderId
			LEFT JOIN [DataCenterV1].[Person].[PersonUser] pu
				ON pu.[User_ID] = cm.CreatedByUserId
			LEFT JOIN [DataCenterV1].[Employee].[Employee] e
				ON pu.Employee_ID = e.Employee_ID
			LEFT JOIN [DataCenterV1].[Address].[Branch] b
				ON cm.BranchId = b.Branch_ID
		WHERE cm.IsActive = 1
			AND cm.ClaimMiscStatusId = 3
			AND cm.ClaimHeaderGroupCode IS NOT NULL
			AND cm.ProductTypeId = @ClaimMiscId
			AND cmh.IsActive = 1
			AND cmp.IsActive = 1
			AND cmp.PaymentStatusId = 4
			AND (cm.BranchId = @BranchId OR @BranchId IS NULL);
	END

 ---------------------------------------------------------------------

	SELECT ROW_NUMBER() OVER(ORDER BY (a.ClaimHeaderGroupCode) ASC) rwId
		,*
	INTO #TmpCondition
	FROM #Tmplst a
	WHERE a.xRevise = '0';

IF @ClaimGroupTypeId <> 4
BEGIN

	INSERT INTO #TmpDoc(
		ClaimHeaderGroupCode
		,ClaimHeaderCode)
	SELECT x.ClaimHeaderGroupCode
			,x.ClaimHeaderCode 
	FROM [ISC_SmileDoc].[dbo].[ClaimDocument] d
		INNER JOIN #TmpCondition x
			ON d.DocumentIndexData = x.ClaimHeaderCode
	WHERE d.DocumentStatusId IN (2,4)
	AND d.IsActive = 1
	GROUP BY x.ClaimHeaderGroupCode
			,x.ClaimHeaderCode 
END

 ---------------------------------------------------------------------
	SELECT g.ClaimHeaderGroupCode									ClaimHeaderGroup_id  
			,b.Detail												Branch
			,pg.ProductGroupDetail									ProductGroup
			,CONCAT(eC.Code,' ', eC.FirstName,' ', eC.LastName)		CreatedByName
			,d.CreatedDate											CreatedDate
			,cgt.ClaimGroupType										ClaimGroupType
			,g.ItemCount											ItemCount
			,g.Amount												Amount
			,@InsuranceId											InsuranceCompanyId
			,d.InsuranceCompanyName									InsuranceCompany	 
			,COUNT(g.ClaimHeaderGroupCode) OVER ()					TotalCount
			,1														DocumentCount
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
			ON g.ClaimHeaderGroupCode = doc.ClaimHeaderGroupCode COLLATE DATABASE_DEFAULT
		LEFT JOIN dbo.ClaimGroupType  cgt
			ON d.ClaimGroupTypeId = cgt.ClaimGroupTypeId
		LEFT JOIN [SSS].[dbo].[DB_Employee] eC
			ON d.CreatedByCode = eC.Code						COLLATE DATABASE_DEFAULT
		LEFT JOIN [DataCenterV1].[Product].[ProductGroup] pg
			ON d.ProductGroupId = pg.ProductGroup_ID 
		LEFT JOIN [SSS].[dbo].[MT_Branch] b
			ON d.BranchCode = b.Code							COLLATE DATABASE_DEFAULT
	WHERE 
	(	@IsShowDocumentLink IS NULL
		OR
		(@IsShowDocumentLink = 1  AND g.ItemCount = doc.docCount)
		OR	
		(
			@IsShowDocumentLink = 0 
			AND 
			(
				( g.ItemCount <> doc.docCount )
				OR ( doc.docCount IS NULL )
			)
		)
	)
	ORDER BY g.ClaimHeaderGroupCode ASC	

	OFFSET @IndexStart ROWS FETCH NEXT @PageSize ROWS ONLY;


IF OBJECT_ID('tempdb..#TmpDoc') IS NOT NULL  DROP TABLE #TmpDoc;	
IF OBJECT_ID('tempdb..#TmpCondition') IS NOT NULL  DROP TABLE #TmpCondition;	
IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;	
IF OBJECT_ID('tempdb..#TmpCAT') IS NOT NULL  DROP TABLE #TmpCAT;	

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
