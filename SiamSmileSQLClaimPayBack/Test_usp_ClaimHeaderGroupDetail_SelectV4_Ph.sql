DECLARE
	 @ProductGroupId		INT 			= 2
	,@InsuranceId			INT				= NULL	
	,@ClaimGroupTypeId		INT				= 4  
	,@BranchId				INT				= NULL	
	,@CreateByUser_Code		VARCHAR(20)		= NULL

	,@IndexStart			INT				= NULL	
	,@PageSize				INT				= NULL
	,@SortField				NVARCHAR(MAX)	= NULL
	,@OrderType				NVARCHAR(MAX)	= NULL
	,@SearchDetail			NVARCHAR(MAX)	= 'BUHH-888-68110003-0' 
	,@IsShowDocumentLink	BIT				= NULL
--AS
--BEGIN
--	SET NOCOUNT ON;

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

SELECT Code
		,ClaimType_id 
		,CASE Code
			WHEN @CalimAdmitType_1001 THEN 1
			WHEN @CalimAdmitType_3001 THEN 1
			ELSE 0
			END xFlag
INTO #TmpCAT
FROM sss.dbo.MT_ClaimAdmitType WITH (NOLOCK);
		
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
				,cl.ClaimPaybackStatus
		FROM sss.dbo.DB_ClaimHeaderGroupItem i			WITH (NOLOCK)
			INNER JOIN SSS.dbo.DB_ClaimHeaderGroup g	WITH (NOLOCK)
				ON i.ClaimHeaderGroup_id = g.Code
			LEFT JOIN #TmpCAT cat
				ON g.ClaimAdmitType_id = cat.Code
			LEFT JOIN sss.dbo.DB_ClaimHeader cl			WITH (NOLOCK)
				ON i.ClaimHeader_id = cl.Code
			LEFT JOIN sss.dbo.DB_ClaimVoucher v			WITH (NOLOCK)
				ON i.ClaimHeader_id = v.Code
		WHERE (g.InsuranceCompany_id = @pInsCode OR @pInsCode IS NULL)
			AND (g.Branch_id = @pBranchCode OR @pBranchCode IS NULL)
			AND (
					(
						@pClaimGroupTypeId = 4 
						AND cat.xFlag = 1
						--AND	cl.ClaimPaybackStatus = 1
						AND	(cl.UpdatedByCode = @pCreatedByCode OR @pCreatedByCode IS NULL)
					)
				 OR (
						cat.xFlag = 0
						AND	(g.CreatedBy_id = @pCreatedByCode OR @pCreatedByCode IS NULL)
					)
				)
			AND (g.Code = @pSearchDetail OR @pSearchDetail IS NULL)				
			--AND	(
			--		(
			--			@pClaimGroupTypeId = 2	
			--			AND g.IsClaimOnLine = 1
			
			--			AND cat.xFlag = 0
			--			AND g.CreatedDate >= @fix_OpdDateCutoff 
			--			AND g.ClaimAdmitType_id NOT IN('4000','4001','5001','5002') 
			--		) 
			--	OR	(
			--			@pClaimGroupTypeId = 3	
			--			AND (g.IsClaimOnLine IS NULL OR g.IsClaimOnLine = 0)
			--			AND cat.ClaimType_id = @ClaimType_2000	
			
			--			AND cat.xFlag = 0
			--			AND g.CreatedDate >= @fix_OpdDateCutoff
			--		)
			--	OR	(
			--			@pClaimGroupTypeId = 4	
			--			AND (g.IsClaimOnLine IS NULL OR g.IsClaimOnLine = 0)
			--			AND cat.ClaimType_id = @ClaimType_1000	
			--			AND (
			--					(
			--						cat.xFlag = 0
			--						AND G.CreatedDate >= @fix_OpdDateCutoff
			--					)
			--				OR	(
			--						cat.xFlag = 1
			--						AND cl.ClaimPaybackStatus = 1
			--						AND g.CreatedDate >= @fix_CutoffEndDATE
			--					)
			--				)
			--		)
			--	OR (
			--			@pClaimGroupTypeId = 6
			--			AND g.IsClaimOnLine = 1
			--			AND cat.xFlag = 0
			--			AND g.CreatedDate >= @fix_OpdDateCutoff
			--			AND g.ClaimAdmitType_id IN('4000','4001','5001','5002')
			--			--AND colPH.PaymentStatusId IS NULL
			--		)
			--	)
			--	AND NOT EXISTS	(
			--						SELECT x.ClaimCode
			--						FROM dbo.ClaimPayBackXClaim x	WITH(NOLOCK)
			--						LEFT JOIN dbo.ClaimPayBackDetail cd	WITH(NOLOCK)
			--							ON x.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
			--						LEFT JOIN dbo.ClaimPayBack cp
			--							ON cd.ClaimPayBackId = cp.ClaimPayBackId
			--						WHERE x.IsActive = 1
			--						AND cp.ClaimGroupTypeId = @pClaimGroupTypeId
			--						AND cd.ProductGroupId = @pProductGroupId
			--						AND x.ClaimCode = i.ClaimHeader_id 
			--					)  

IF OBJECT_ID('tempdb..#TmpCAT') IS NOT NULL  DROP TABLE #TmpCAT;