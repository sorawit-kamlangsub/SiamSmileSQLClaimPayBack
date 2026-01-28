USE [ClaimPayBack]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sorawit Kamlangsub 08719
-- Create date: 2026-01-28 09:24
-- Description:	Monitor การโอนเงินสำรองจ่าย
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackTransferOutPocket_Select]
	-- Add the parameters for the stored procedure here
	@CreatedDateFrom							DATE 
	,@CreatedDateTo								DATE 
	,@OutOfPocketStatusId						INT = NULL
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
	  ,ops.OutOfPocketStatusName
	  ,t.OutOfPocketStatus				OutOfPocketStatus
      ,t.IsActive
      ,t.CreatedByUserId
      ,t.CreatedDate
      ,t.UpdatedByUserId
      ,t.UpdatedDate
	  ,CASE WHEN t.Amount > 2000000 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END IsCheck 
	  ,CASE WHEN t.Amount > 2000000 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END IsGroup 
	  ,COUNT(t.ClaimPayBackTransferId) OVER ( ) AS TotalCount
	FROM dbo.ClaimPayBackTransfer t
		LEFT JOIN dbo.ClaimPayBackOutOfPocketStatus ops
			ON t.OutOfPocketStatus = ops.OutOfPocketStatusId
		LEFT JOIN dbo.ClaimGroupType cg_t
			ON t.ClaimGroupTypeId = cg_t.ClaimGroupTypeId

	WHERE (t.CreatedDate >= @CreatedDateFrom AND t.CreatedDate < @CreatedDateTo)
	AND (t.OutOfPocketStatus = @OutOfPocketStatusId OR @OutOfPocketStatusId IS NULL)
	AND (t.IsActive = 1)
	AND (t.ClaimGroupTypeId = @ClaimGroupType OR @ClaimGroupType IS NULL)
	ORDER BY CASE WHEN @l_OrderType IS NULL AND @l_SortField IS NULL THEN t.ClaimPayBackTransferId END ASC 
		,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'ClaimPayBackTransferCode' THEN t.ClaimPayBackTransferId END ASC 
	    ,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'ClaimPayBackTransferCode' THEN t.ClaimPayBackTransferId END DESC 
	
		,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'Amount' THEN t.Amount END ASC 
	    ,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'Amount' THEN t.Amount END DESC 
	
		,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'ClaimPayBackTransferStatus' THEN ops.OutOfPocketStatusName END ASC 
	    ,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'ClaimPayBackTransferStatus' THEN ops.OutOfPocketStatusName END DESC 
	
	
		,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'TransferDate' THEN t.TransferDate END ASC 
	    ,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'TransferDate' THEN t.TransferDate END DESC 
	
		,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'CreatedDate' THEN t.TransferDate END ASC 
	    ,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'CreatedDate' THEN t.TransferDate END DESC 
OFFSET @l_IndexStart ROWS FETCH NEXT @l_PageSize ROWS ONLY;
END