USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackDetailXClaim_Select]    Script Date: 3/12/2568 13:41:32 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Prattana  Phiwkaew
-- Create date: 2021-10-07 10:03
-- Description:	<Description,,>
-- UpdateDate: 2025-10-21 15:13 Krekpon.D Add URL ClaimMisc view page
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackDetailXClaim_Select]
	-- Add the parameters for the stored procedure here
	 @ClaimPayBackDetailId	INT = NULL


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
DECLARE @l_PageSize INT				= @PageSize;
DECLARE @l_SortField NVARCHAR(MAX)	= @SortField;
DECLARE @l_OrderType NVARCHAR(MAX)	= @OrderType;
DECLARE @l_SearchDetail NVARCHAR(MAX)	= @SearchDetail;	

----------------------------------------------------------------------------
IF @l_IndexStart IS NULL SET @l_IndexStart = 0;
IF @l_PageSize IS NULL SET @l_PageSize = 10;
IF @l_SearchDetail IS NULL SET @l_SearchDetail = '';
----------------------------------------------------------------------------

--Get URL in ProgramConfig
DECLARE @SSSURL			NVARCHAR(250)
DECLARE @SSSPAURL		NVARCHAR(250)
DECLARE @ClaimMiscURL	NVARCHAR(250)


DECLARE @SSSPath	NVARCHAR(250) = 'SSS_URL'
DECLARE @SSSPAPath	NVARCHAR(250) = 'SSSPA_URL'

SELECT @SSSURL = ValueString
FROM dbo.ProgramConfig 
WHERE ParameterName = @SSSPath

SELECT @SSSPAURL = ValueString
FROM dbo.ProgramConfig 
WHERE ParameterName = @SSSPAPath


-- Set URL
SET @SSSURL = CONCAT(@SSSURL,'Modules/Claim/frmClaimApproveOverview.aspx?clm=')
SET @SSSPAURL = CONCAT(@SSSPAURL,'Modules/Claim/frmClaimPA_New.aspx?clm=')
SET @ClaimMiscURL = 'https://uatclaimmisc.siamsmile.co.th/viewclaimdetails?id='



-----------------------------------------------------------------------------

SELECT c.ClaimPayBackXClaimId
      ,c.ClaimPayBackDetailId
      ,c.ClaimCode
      ,c.ProductName
      ,c.HospitalName
      ,c.ClaimAdmitType
      ,c.ChiefComplain
      ,c.ICD10
      ,c.ClaimPay
      ,c.ClaimTransfer
      ,c.IsActive
      ,c.CreatedByUserId
      ,c.CreatedDate
      ,c.UpdatedByUserId
      ,c.UpdatedDate 
	  ,CASE 
		WHEN d.ProductGroupId = 2 THEN CONCAT(@SSSURL,dbo.uFnStringToBase64(c.ClaimCode))
		WHEN d.ProductGroupId = 3 THEN CONCAT(@SSSPAURL,dbo.uFnStringToBase64(c.ClaimCode))
		WHEN d.ProductGroupId IN (4,5,6,7,8,9,10,11) THEN CONCAT(@ClaimMiscURL,cm.ClaimMiscId)
		ELSE ''
		END		URLLink
	  ,COUNT(c.ClaimPayBackXClaimId) OVER ( ) AS TotalCount
FROM dbo.ClaimPayBackXClaim c
	INNER JOIN dbo.ClaimPayBackDetail d
		ON c.ClaimPayBackDetailId = d.ClaimPayBackDetailId
	LEFT JOIN [ClaimMiscellaneous].[misc].ClaimMisc cm
		on c.ClaimCode = cm.ClaimMiscNo
WHERE (c.ClaimPayBackDetailId = @ClaimPayBackDetailId)
AND (c.IsActive = 1)


--AND (b.ClaimPayBackCode LIKE N'%'+ @l_SearchDetail + '%' OR @l_SearchDetail IS NULL)

ORDER BY CASE WHEN @l_OrderType IS NULL AND @l_SortField IS NULL THEN c.ClaimPayBackXClaimId END ASC 
--,CASE WHEN @l_OrderType = 'ASC' AND @l_SortField = 'ClaimPayBackCode' THEN b.ClaimPayBackId END ASC 
--,CASE WHEN @l_OrderType = 'DESC' AND @l_SortField = 'ClaimPayBackCode' THEN b.ClaimPayBackId END DESC 

OFFSET @l_IndexStart ROWS FETCH NEXT @l_PageSize ROWS ONLY;



END
