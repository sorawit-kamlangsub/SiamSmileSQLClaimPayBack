USE [ClaimPayBack]
GO

DECLARE @ClaimHeaderGroup_ids NVARCHAR(MAX)
DECLARE @tmpClaimHeaderGroup_id TABLE (ClaimHeaderGroup_id NVARCHAR(50));
DECLARE @tmpValid TABLE
(
    ClaimHeaderGroupCode NVARCHAR(50),
    Amount DECIMAL(16,2),
    NPLAmount DECIMAL(16,2),
    TransferAmount DECIMAL(16,2),
    IsValid INT,
    WarningMessage NVARCHAR(MAX)
);
DECLARE @tmp TABLE
(
    ClaimHeaderGroup_id NVARCHAR(50),
    Branch VARCHAR(50),
    ProductGroup VARCHAR(50),
    CreatedByName VARCHAR(100),
    CreatedDate DATETIME,
    ClaimGroupType VARCHAR(50),
    ItemCount INT,
    Amount DECIMAL(18,2),
    InsuranceCompanyId INT,
    InsuranceCompany VARCHAR(100),
    DocumentCount INT,
    TotalCount INT,
    TransferAmount DECIMAL(18,2),
    ProductTypeDetail VARCHAR(50)
);


INSERT INTO @tmp
EXEC [ClaimPayBack].[Claim].[usp_ClaimHeaderGroupDetail_SelectV4]
		@ProductGroupId = 11,
		@InsuranceId = NULL,
		@ClaimGroupTypeId = 7,
		@BranchId = NULL,
		@CreateByUser_Code = NULL,
		@IndexStart = 0,
		@PageSize = 20,
		@SortField = NULL,
		@OrderType = NULL,
		@SearchDetail = NULL,
		@IsShowDocumentLink = NULL,
		@ProductTypeId = NULL,
		@ClaimPayBackTypeId = NULL

INSERT INTO @tmpClaimHeaderGroup_id(ClaimHeaderGroup_id)
SELECT ClaimHeaderGroup_id FROM @tmp

SELECT
@ClaimHeaderGroup_ids =
STUFF
(
    (
        SELECT ',' + ClaimHeaderGroup_id
        FROM @tmpClaimHeaderGroup_id
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)')
,1,1,'')

INSERT INTO @tmpValid
EXEC	[dbo].[usp_ClaimHeaderGroupValidateAmountPay_Select]
		@ProductGroupId = 11,
		@ClaimGroupTypeId = 7,
		@ClaimHeaderGroupCode = @ClaimHeaderGroup_ids

SELECT
    t.ClaimHeaderGroup_id
    ,t.Amount
    ,t.Branch
    ,t.ProductGroup
    ,t.ClaimGroupType
FROM @tmp t
INNER JOIN @tmpValid v
    ON v.ClaimHeaderGroupCode = t.ClaimHeaderGroup_id
WHERE v.IsValid = 1