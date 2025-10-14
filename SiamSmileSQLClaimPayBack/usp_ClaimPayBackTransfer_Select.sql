USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackTransfer_Select]    Script Date: 14/10/2568 14:14:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Prattana Phiwkaew
-- Create date: 2021-10-06 15:52
-- Description:	ClaimPayBackTransfer
-- Update By:	Krekpon Mind 06588
-- Update Date:	2024-08-09
-- Description:	Count IsSentEmail And Count IsUpload
-- Update By:	Krekpon Mind 06588
-- Update Date:	2024-08-21
-- Description:	SELECT Count IsSentEmail And Count IsUpload for check
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackTransfer_Select]
	-- Add the parameters for the stored procedure here
	 @CreatedDateFrom							DATE
	,@CreatedDateTo								DATE
	,@ClaimPayBackTransferStatusId				INT = NULL

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
 DECLARE @l_SortField NVARCHAR(MAX)	= @SortField;
 DECLARE @l_OrderType NVARCHAR(MAX)	= @OrderType;
 DECLARE @l_SearchDetail NVARCHAR(MAX)	= @SearchDetail;	
 
 ----------------------------------------------------------------------------
 IF @l_IndexStart IS NULL SET @l_IndexStart = 0;
 IF @l_PageSize IS NULL  SET @l_PageSize = 10;
 IF @l_SearchDetail IS NULL SET @l_SearchDetail = '';
----------------------------------------------------------------------------

SET @CreatedDateTo = DATEADD(DAY,1,@CreatedDateTo)

--Count IsSentEmail And Count IsUpload
DECLARE @TmpCountAllHCG TABLE(
	ClaimPayBackTransferId INT
	,AllHCGCount INT
	,CountSentEmail INT
	,CountNotSentEmail INT
	,CountUploadDoc INT
	,CountNotUploadDoc INT
)

-- status is sent doc and mail
DECLARE @TmpStatusIsSentDocAndEmail TABLE(
	ClaimPayBackTransferId INT
	,IsSentDocStatus INT
	,IsSentEmailStatus INT
)

---------------------------------------------

-- Count All HCG in CPBT

INSERT INTO @TmpCountAllHCG (
		ClaimPayBackTransferId
		,AllHCGCount
		,CountSentEmail
		,CountNotSentEmail
		,CountUploadDoc
		,CountNotUploadDoc
		) 
SELECT DISTINCT
		cpbt.ClaimPayBackTransferId
        ,COUNT(hcg.ClaimPayBackSubGroupId) OVER(PARTITION BY cpbt.ClaimPayBackTransferId) AllHCGCount
		,COUNT(CASE WHEN hcg.IsSendEmail = 1 THEN 1 END) OVER(PARTITION BY cpbt.ClaimPayBackTransferId) CountIsSendEmail
		,COUNT(CASE WHEN hcg.IsSendEmail = 0 THEN 1 END) OVER(PARTITION BY cpbt.ClaimPayBackTransferId) CountIsNotSendEmail
		,COUNT(CASE WHEN hcg.IsUploadDoc = 1 THEN 1 END) OVER(PARTITION BY cpbt.ClaimPayBackTransferId) CountIsUploadDoc
		,COUNT(CASE WHEN hcg.IsUploadDoc = 0 THEN 1 END) OVER(PARTITION BY cpbt.ClaimPayBackTransferId) CountIsNotUploadDoc
FROM dbo.ClaimPayBackTransfer cpbt
LEFT JOIN dbo.ClaimPayBackSubGroup hcg
    ON cpbt.ClaimPayBackTransferId = hcg.ClaimPayBackTransferId
GROUP BY cpbt.ClaimPayBackTransferId,hcg.ClaimPayBackTransferId,hcg.IsSendEmail,hcg.IsUploadDoc,hcg.ClaimPayBackSubGroupId

--END Count IsSentEmail And Count IsUpload

-- Set Status IsSentDoc And IsSentEmail
-- 1 คือ ยังไม่ทำรายการ
-- 2 คือ ทำรายการบางส่วน
-- 3 คือ ทำรายการสำเร็จทั้งหมด
INSERT INTO @TmpStatusIsSentDocAndEmail (
		ClaimPayBackTransferId
		,IsSentDocStatus
		,IsSentEmailStatus
		) 
SELECT DISTINCT hcg.ClaimPayBackTransferId
		,CASE 
			WHEN tmpHCG.CountUploadDoc > 0 AND tmpHCG.CountNotUploadDoc > 0 THEN 2
			WHEN tmpHCG.CountUploadDoc = tmpHCG.AllHCGCount THEN 3
			ELSE 1
		END AS IsSentDocStatus
	   ,CASE 
			WHEN tmpHCG.CountSentEmail > 0 AND tmpHCG.CountNotSentEmail > 0 THEN 2
			WHEN tmpHCG.CountSentEmail = tmpHCG.AllHCGCount THEN 3
			ELSE 1
		END AS IsSentEmailStatus
		
FROM  dbo.ClaimPayBackTransfer cpbt
LEFT JOIN dbo.ClaimPayBackSubGroup hcg
    ON cpbt.ClaimPayBackTransferId = hcg.ClaimPayBackTransferId
LEFT JOIN @TmpCountAllHCG tmpHCG
	ON hcg.ClaimPayBackTransferId = tmpHCG.ClaimPayBackTransferId


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
	  ,tmpStatusIsSentDocAndMail.IsSentDocStatus AS IsUploadDocsStatus
	  ,tmpStatusIsSentDocAndMail.IsSentEmailStatus AS IsSentEmailStatus
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
	LEFT JOIN @TmpStatusIsSentDocAndEmail tmpStatusIsSentDocAndMail	--SELECT Count IsSentEmail And Count IsUpload for check
		ON t.ClaimPayBackTransferId = tmpStatusIsSentDocAndMail.ClaimPayBackTransferId

WHERE (t.CreatedDate >= @CreatedDateFrom AND t.CreatedDate < @CreatedDateTo)
AND (t.ClaimPayBackTransferStatusId = @ClaimPayBackTransferStatusId OR @ClaimPayBackTransferStatusId IS NULL)
AND (t.IsActive = 1)
AND t.ClaimGroupTypeId = 4
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

IF OBJECT_ID('tempdb..@TmpCountAllHCG') IS NOT NULL  DELETE FROM @TmpCountAllHCG;
IF OBJECT_ID('tempdb..@TmpStatusIsSentDocAndEmail') IS NOT NULL  DELETE FROM @TmpStatusIsSentDocAndEmail;
   
END
