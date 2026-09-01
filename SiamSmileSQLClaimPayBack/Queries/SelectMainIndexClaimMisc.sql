USE [ClaimPayBack]
GO

DECLARE @Tmp TABLE
(
    ClaimHeaderGroup_id     VARCHAR(50),
    Branch                  NVARCHAR(200),
    ProductGroup            NVARCHAR(200),
    CreatedByName           NVARCHAR(200),
    CreatedDate             DATETIME,
    ClaimGroupType          NVARCHAR(200),
    ItemCount               INT,
    Amount                  DECIMAL(18,2),
    InsuranceCompanyId      INT,
    InsuranceCompany        NVARCHAR(500),
    TotalCount              INT,
    DocumentCount           INT,
    TransferAmount          DECIMAL(18,2) NULL,
    ProductTypeDetail       NVARCHAR(200)
)

DECLARE @RC int
DECLARE @ProductGroupId int = 11
DECLARE @InsuranceId int
DECLARE @ClaimGroupTypeId int = 8
DECLARE @BranchId int
DECLARE @CreateByUser_Code varchar(20)
DECLARE @IndexStart int = 0
DECLARE @PageSize int = 25
DECLARE @SortField nvarchar(max)
DECLARE @OrderType nvarchar(max)
DECLARE @SearchDetail nvarchar(max)
DECLARE @IsShowDocumentLink bit
DECLARE @ProductTypeId int
DECLARE @ClaimPayBackTypeId int
DECLARE @ClaimHeaderGroupCodes nvarchar(max)


INSERT INTO @Tmp
EXECUTE [Claim].[usp_ClaimHeaderGroupDetail_SelectV4] 
   @ProductGroupId
  ,@InsuranceId
  ,@ClaimGroupTypeId
  ,@BranchId
  ,@CreateByUser_Code
  ,@IndexStart
  ,@PageSize
  ,@SortField
  ,@OrderType
  ,@SearchDetail
  ,@IsShowDocumentLink
  ,@ProductTypeId
  ,@ClaimPayBackTypeId

SELECT * FROM @Tmp

SELECT @ClaimHeaderGroupCodes =
    STUFF(
    (
        SELECT ',' + ClaimHeaderGroup_id
        FROM @Tmp
        FOR XML PATH(''), TYPE
    ).value('.', 'VARCHAR(MAX)')
    ,1,1,'');

SELECT @ClaimHeaderGroupCodes;

EXECUTE [dbo].[usp_GetDocumentIdDocStorage_Select] 
   @ClaimHeaderGroupCodes




GO