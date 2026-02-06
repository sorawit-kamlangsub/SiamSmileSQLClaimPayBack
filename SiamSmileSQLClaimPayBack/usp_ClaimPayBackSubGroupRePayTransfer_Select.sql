USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackSubGroupRePayTransfer_Select]    Script Date: 6/2/2569 10:35:36 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Krekpon Dokkamklang
-- Create date: 2024-06-12
-- Description:	เอาข้อมูลที่โอนไม่สำเร็จกับทำรายการไม่สำเร็จออกมาแสดง
-- UpdateDate:  2024-07-03 Krekpon.D Mind
-- Description: ปรับวันที่โอนให้เป็นวันที่ทำรายการ
-- UpdateDate:  2026-02-06 Sorawit.k 
-- Description: ปรับการเพิ่ม ฟีเจอร์การสำรองเงิน
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackSubGroupRePayTransfer_Select] 
	-- Add the parameters for the stored procedure here
	@HospitalCode								VARCHAR(30) = NULL
	,@IndexStart								INT = NULL 
	,@PageSize									INT = NULL 
	,@SortField									NVARCHAR(MAX) = NULL
	,@OrderType									NVARCHAR(MAX) = NULL
	,@SearchDetail								NVARCHAR(MAX) = NULL
AS
BEGIN
	
	-------------------------------------------------------------

	--TEST
	--DECLARE
	--@HospitalCode								VARCHAR(30) = NULL
	--,@IndexStart								INT = 1 
	--,@PageSize									INT = 20 
	--,@SortField									NVARCHAR(MAX) = NULL
	--,@OrderType									NVARCHAR(MAX) = NULL
	--,@SearchDetail								NVARCHAR(MAX) = NULL
	--END TEST
	
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
	SELECT 
		csg.ClaimPayBackSubGroupId,
		csg.ClaimPayBackSubGroupCode,
		csg.ItemCount,
		csg.Amount,
		csgt.CreatedDate AS BillingTransferDate, -- 2024-07-03 Krekpon.D ปรับวันที่โอนให้เป็นวันที่ทำรายการ
		csg.HospitalName,
		ISNULL(cpbacc.ReceivingBankAccountNo,REPLACE(mtc.BankAccountNo,'-','')) AS BankAccountNo,
		ISNULL(cpbacc.ReceivingBankAccountName,mtc.BankAccountName)	BankAccountName,
		ISNULL(org.OrganizeDetail,dfb.BankDetail)	BankDetail,
		csg.HospitalCode,
		csgt.ClaimPayBackSubGroupTransactionStatusId,
		csgts.ClaimPayBackSubGroupTransactionStatusName,
		csgt.ClaimPayBackSubGroupTransactionId,
		COUNT(csg.ClaimPayBackSubGroupId) OVER ( ) AS TotalCount
	FROM ClaimPayBackSubGroup csg
	LEFT JOIN [SSS].dbo.MT_Company mtc
		ON csg.HospitalCode = mtc.Code
	LEFT JOIN [DataCenterV1].[Financial].Bank dfb
		ON mtc.Bank_id = dfb.TempCode
	LEFT JOIN ClaimPayBackSubGroupTransaction csgt
		ON csg.ClaimPayBackSubGroupId = csgt.ClaimPayBackSubGroupId
	LEFT JOIN ClaimPayBackSubGroupTransactionStatus csgts
		ON csgt.ClaimPayBackSubGroupTransactionStatusId = csgts.ClaimPayBackSubGroupTransactionStatusId
	LEFT JOIN ClaimPayBackTransferAccountConfig cpbacc
		ON cpbacc.AccountConfigId = csg.AccountConfigId
	LEFT JOIN 
	 (
		SELECT
		dco.Organize_ID
		,dco.OrganizeDetail
		FROM [DataCenterV1].[Organize].Organize dco
		WHERE dco.IsActive = 1		
	 ) org
		ON org.Organize_ID IN (cpbacc.SendingBankId,cpbacc.ReceivingBankId) 
	WHERE (csgt.ClaimPayBackSubGroupTransactionStatusId = 4 OR csgt.ClaimPayBackSubGroupTransactionStatusId = 6)
		AND csgt.IsActive = 1 
		AND (csg.HospitalCode = @HospitalCode OR @HospitalCode IS NULL)
	ORDER BY csg.CreatedDate DESC, csgt.ClaimPayBackSubGroupTransactionId DESC
	OFFSET @l_IndexStart ROWS FETCH NEXT @l_PageSize ROWS ONLY;
END
