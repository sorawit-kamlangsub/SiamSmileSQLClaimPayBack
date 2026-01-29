DECLARE @ProductGroupId			INT 			= 11;
DECLARE @ProductTypeId			INT 			= 10;
DECLARE @InsuranceId			INT				= NULL;
DECLARE @ClaimGroupTypeId		INT				= 7;
DECLARE @BranchId				INT				= NULL;
DECLARE @CreateByUser_Code		VARCHAR(20)		= NULL;
DECLARE @IndexStart				INT				= 0;
DECLARE @PageSize				INT				= 10;
DECLARE @SortField				NVARCHAR(MAX)	= NULL;
DECLARE @OrderType				NVARCHAR(MAX)	= NULL;
DECLARE @SearchDetail			NVARCHAR(MAX)	= NULL;
DECLARE @IsShowDocumentLink		BIT				= NULL

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
    
    
    
    SELECT 
				cm.ClaimMiscId
				,cm.ClaimHeaderGroupCode									ClaimHeaderGroupCode
				,1															ClaimHeaderCode
				--,b.tempcode													BranchCode
				,ISNULL(e.EmployeeCode, '00000')							CreatedByCode
				,cm.ApproveDate												CreatedDate
				,cm.InsuranceCompanyCode									InsuranceCompanyCode
				,cm.InsuranceCompanyName									InsuranceCompanyName 
				,cm.ProductGroupId											ProductGroupId
				,'0'														xRevise
				,ISNULL(cm.PayAmount, 0) 									amount 
				,@pClaimGroupTypeId											ClaimGroupTypeId
				,NULL														TransferAmount
				,pt.ProductTypeDetail										ProductTypeDetail
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
							(@ProductTypeId IS NOT NULL AND cm.ProductTypeId = @ProductTypeId)
							OR
							(@ProductTypeId IS NULL AND cm.ProductTypeId = 7)
						)
				)
				OR
				(
					@pProductGroupId = 11 
					AND
						(
							(@ProductTypeId IS NOT NULL AND cm.ProductTypeId = @ProductTypeId)
							OR
							(@ProductTypeId IS NULL AND cm.ProductTypeId IN (10,27,38,41,42,32,33))
						)
				)
			) 
 			AND NOT EXISTS	
 			(
 				SELECT x.ClaimCode
 				FROM dbo.ClaimPayBackXClaim x	WITH(NOLOCK)
 				LEFT JOIN dbo.ClaimPayBackDetail cd	WITH(NOLOCK)
 					ON x.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
 				LEFT JOIN dbo.ClaimPayBack cp
 					ON cd.ClaimPayBackId = cp.ClaimPayBackId
 				WHERE x.IsActive = 1
 					AND cm.ClaimHeaderGroupCode = cd.ClaimGroupCode
 			)