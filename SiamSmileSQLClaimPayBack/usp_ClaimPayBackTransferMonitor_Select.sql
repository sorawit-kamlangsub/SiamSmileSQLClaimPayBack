USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackTransferMonitor_Select]    Script Date: 27/1/2569 16:21:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Krekpon Mind 06588
-- Create date: 2024-08-13 09:06
-- Description:	ClaimPayBackTransferMonitor Select
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackTransferMonitor_Select]
	-- Add the parameters for the stored procedure here
	@CreatedDateFrom							DATE
	,@CreatedDateTo								DATE
	,@ClaimPayBackTransferStatusId				INT = NULL
	,@ClaimGroupType							INT = NULL

	,@IndexStart								INT = NULL 
	,@PageSize									INT = NULL 
	,@SortField									NVARCHAR(MAX) = NULL
	,@OrderType									NVARCHAR(MAX) = NULL
	,@SearchDetail								NVARCHAR(MAX) = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-------------------------------------------------------------
	 DECLARE @l_IndexStart INT				= @IndexStart;
	 DECLARE @l_PageSize INT				= @PageSize;
	 DECLARE @l_SortField NVARCHAR(MAX)		= @SortField;
	 DECLARE @l_OrderType NVARCHAR(MAX)		= @OrderType;
	 DECLARE @l_SearchDetail NVARCHAR(MAX)	= @SearchDetail;	
	 
	 ----------------------------------------------------------------------------
	 IF @l_IndexStart IS NULL SET @l_IndexStart = 0;
	 IF @l_PageSize IS NULL  SET @l_PageSize = 10;
	 IF @l_SearchDetail IS NULL SET @l_SearchDetail = '';
	----------------------------------------------------------------------------

	SET @CreatedDateTo = DATEADD(DAY,1,@CreatedDateTo)

    -- Insert statements for procedure here
	SELECT t.ClaimPayBackTransferId
      ,t.ClaimPayBackTransferCode
      ,t.ClaimGroupTypeId
	  ,cg_t.ClaimGroupType
      ,t.Amount
      ,t.TransferAmount
      ,t.TransferDate
      ,t.ClaimPayBackTransferStatusId
	  ,sts.ClaimPayBackTransferStatus
      ,t.IsActive
      ,t.CreatedByUserId
      ,t.CreatedDate
      ,t.UpdatedByUserId
      ,t.UpdatedDate
	  ,COUNT(t.ClaimPayBackTransferId) OVER ( ) AS TotalCount
	FROM dbo.ClaimPayBackTransfer t
		LEFT JOIN dbo.ClaimPayBackTransferStatus sts
			ON t.ClaimPayBackTransferStatusId = sts.ClaimPayBackTransferStatusId
		LEFT JOIN dbo.ClaimGroupType cg_t
			ON t.ClaimGroupTypeId = cg_t.ClaimGroupTypeId

	WHERE (t.CreatedDate >= @CreatedDateFrom AND t.CreatedDate < @CreatedDateTo)
	AND (t.ClaimPayBackTransferStatusId = @ClaimPayBackTransferStatusId OR @ClaimPayBackTransferStatusId IS NULL)
	AND (t.IsActive = 1)
	AND (t.ClaimGroupTypeId = @ClaimGroupType OR @ClaimGroupType IS NULL)
	ORDER BY CASE WHEN @l_OrderType IS NULL AND @l_SortField IS NULL THEN t.ClaimPayBackTransferId END ASC 
		,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'ClaimPayBackTransferCode' THEN t.ClaimPayBackTransferId END ASC 
	    ,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'ClaimPayBackTransferCode' THEN t.ClaimPayBackTransferId END DESC 
	
		,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'Amount' THEN t.Amount END ASC 
	    ,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'Amount' THEN t.Amount END DESC 
	
		,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'ClaimPayBackTransferStatus' THEN sts.ClaimPayBackTransferStatus END ASC 
	    ,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'ClaimPayBackTransferStatus' THEN sts.ClaimPayBackTransferStatus END DESC 
	
	
		,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'TransferDate' THEN t.TransferDate END ASC 
	    ,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'TransferDate' THEN t.TransferDate END DESC 
	
		,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'CreatedDate' THEN t.TransferDate END ASC 
	    ,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'CreatedDate' THEN t.TransferDate END DESC 
OFFSET @l_IndexStart ROWS FETCH NEXT @l_PageSize ROWS ONLY;
END
