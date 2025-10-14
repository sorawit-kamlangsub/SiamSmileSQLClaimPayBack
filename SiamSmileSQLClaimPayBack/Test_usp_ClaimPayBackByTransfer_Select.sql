USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackByTransfer_Select]    Script Date: 14/10/2568 14:04:19 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

-- =============================================
-- Author:		Prattana  Phiwkaew
-- Create date: 2021-10-07 10:03
-- Description:	<Description,,>
-- =============================================
--ALTER PROCEDURE [dbo].[usp_ClaimPayBackByTransfer_Select]
DECLARE
	-- Add the parameters for the stored procedure here
	 @ClaimPayBackTransferId	INT = NULL


	,@IndexStart			INT = NULL 
	,@PageSize				INT = NULL 
	,@SortField				NVARCHAR(MAX) = NULL
	,@OrderType				NVARCHAR(MAX) = NULL
	,@SearchDetail			NVARCHAR(MAX) = NULL

--AS
--BEGIN
--	-- SET NOCOUNT ON added to prevent extra result sets from
--	-- interfering with SELECT statements.
--	SET NOCOUNT ON;
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
WHERE (b.ClaimPayBackTransferId = @ClaimPayBackTransferId)
AND (b.IsActive = 1)

--AND (b.ClaimPayBackCode LIKE N'%'+ @l_SearchDetail + '%' OR @l_SearchDetail IS NULL)

ORDER BY CASE WHEN @l_OrderType IS NULL AND @l_SortField IS NULL THEN b.ClaimPayBackId END ASC 
,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'ClaimPayBackCode' THEN b.ClaimPayBackId END ASC 
,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'ClaimPayBackCode' THEN b.ClaimPayBackId END DESC 
OFFSET @l_IndexStart ROWS FETCH NEXT @l_PageSize ROWS ONLY;



--END

