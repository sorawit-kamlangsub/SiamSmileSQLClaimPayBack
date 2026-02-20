USE [ClaimPayBack]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Prattana  Phiwkaew
-- Create date: 2021-10-07 10:03
-- Update date: 2022-10-05 07:05 Add BranchDetail
-- Update date: Kittisak.Ph 20230630
--				Chanadol 2023-09-08 add column HospitalName
-- Update date: Bunchuai Chaiket 2025-07-07 10:09
--				Change left join from DB_ClaimHeaderGroup to DataCenterV1.Organize.Organize for get InsuranceCompany
-- Update date: Bunchuai Chaiket 2026-01-07 16:14
--				add temp table #InsuranceType select new ProductGroup
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackDetailByHeader_Select]
	-- Add the parameters for the stored procedure here
	 @ClaimPayBackId	INT = NULL
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
DECLARE @l_PageSize INT					= @PageSize;
DECLARE @l_SortField NVARCHAR(MAX)		= @SortField;
DECLARE @l_OrderType NVARCHAR(MAX)		= @OrderType;
DECLARE @l_SearchDetail NVARCHAR(MAX)	= @SearchDetail;	

----------------------------------------------------------------------------
IF @l_IndexStart IS NULL SET @l_IndexStart = 0;
IF @l_PageSize IS NULL SET @l_PageSize = 10;
IF @l_SearchDetail IS NULL SET @l_SearchDetail = '';
----------------------------------------------------------------------------
SET @l_SortField = NULL;
SET @l_OrderType = NULL;

-- สร้าง temp table
CREATE TABLE #InsuranceType (
    ProductGroup_ID INT,
    ProductGroupDetail NVARCHAR(100),
    IsActive bit
);

INSERT INTO #InsuranceType (ProductGroup_ID, ProductGroupDetail, IsActive)
VALUES
    (1, N'รอข้อมูล',0),
    (2, N'PH',1),
    (3, N'PA',1),
    (4, N'Motor',1),
    (5, N'Miscellaneous',0),
    (6, N'Miscellaneous',0),
    (7, N'Miscellaneous',0),
    (8, N'Miscellaneous',0),
    (9, N'Miscellaneous',0),
    (10, N'Miscellaneous',0),
    (11, N'Miscellaneous',1);

SELECT d.ClaimPayBackDetailId
      ,d.ClaimPayBackDetailCode
      ,d.ClaimPayBackId
	  ,b.ClaimPayBackCode
      ,d.ClaimGroupCode
      ,d.ItemCount
      ,d.Amount
	  ,cg_t.ClaimGroupTypeId
	  ,cg_t.ClaimGroupType
      ,d.ProductGroupId
	  ,cpbpg.ProductGroupDetail					ProductGroup
      ,d.InsuranceCompanyId
	  ,org.OrganizeDetail						InsuranceCompany
      ,d.CancelRemark
	  ,b.ClaimPayBackStatusId
      ,d.IsActive
      ,d.CreatedByUserId
      ,d.CreatedDate
      ,d.UpdatedByUserId
      ,d.UpdatedDate 
	  ,COUNT(d.ClaimPayBackDetailId) OVER ( ) AS TotalCount
	  ,bc.BranchDetail
	  ,vh.Detail				HospitalName
FROM dbo.ClaimPayBackDetail d
	LEFT JOIN dbo.ClaimPayBack b
		ON d.ClaimPayBackId = b.ClaimPayBackId
	LEFT JOIN dbo.ClaimGroupType cg_t
		ON b.ClaimGroupTypeId = cg_t.ClaimGroupTypeId
	LEFT JOIN (
		SELECT 
			Organize_ID
			,OrganizeDetail
		FROM [DataCenterV1].[Organize].[Organize] 
		WHERE IsActive = 1
			AND OrganizeType_ID IN(2,6)
	)org
		ON org.Organize_ID = d.InsuranceCompanyId
	INNER JOIN #InsuranceType cpbpg
        ON d.ProductGroupId = cpbpg.ProductGroup_ID
	LEFT JOIN [DataCenterV1].[Address].[Branch] bc
		ON b.BranchId = bc.Branch_ID
	LEFT JOIN [SSS].[dbo].[MT_Company] vh
		ON d.HospitalCode = vh.Code
WHERE (d.ClaimPayBackId = @ClaimPayBackId)
AND (d.IsActive = 1)

ORDER BY CASE WHEN @l_OrderType IS NULL AND @l_SortField IS NULL THEN d.ClaimGroupCode END ASC
OFFSET @l_IndexStart ROWS FETCH NEXT @l_PageSize ROWS ONLY;

IF OBJECT_ID('tempdb..#InsuranceType') IS NOT NULL  DROP TABLE #InsuranceType;

END;