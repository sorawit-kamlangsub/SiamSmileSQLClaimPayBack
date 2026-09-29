USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequestItem_Select]    Script Date: 9/29/2026 8:40:26 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Napaporn  Saarnwong
-- Create date: 2022-10-28 10:40
-- Update date:		2023-02-03 Siriphong Narkphung Add Column Branch
--					2023-03-13 Siriphong Narkphung Change Location	ICD10,ICD10_1Code Only PH >>>> All Show	PolicyNo Only PA >>>> All Show
-- Update date:		2023-08-15 10:15 Siriphong Narkphung Change Location Branch Join
--					2023-08-31 Chanadol Koonkam Change CoverAmount from BillingRequestItem
--					2024-01-26 Chanadol Koonkam Change Pay_Total to  PaySS_Total
--					2025-11-17 Sorawit KamlangSuab Add Order By ClaimHeaderGroupCode Option
-- Update date:		2026-07-22 Bunchuai chaiket (เพิ่มเงื่อนไข กรณี PA ChiefComplain ให้ใส่ Code)
-- Description:	
-- =============================================
ALTER PROCEDURE [dbo].[usp_BillingRequestItem_Select]
	-- Add the parameters for the stored procedure here
	 @BillingRequestGroupId		INT

	,@IndexStart				INT = NULL 
	,@PageSize					INT = NULL 
	,@SortField					NVARCHAR(MAX) = NULL
	,@OrderType					NVARCHAR(MAX) = NULL
	,@SearchDetail				NVARCHAR(MAX) = NULL
AS
BEGIN
	--WAITFOR DELAY '00:01'
	SET NOCOUNT ON;


--DECLARE 
--	 @BillingRequestGroupId		INT = 3129
--	,@IndexStart				INT = NULL 
--	,@PageSize					INT = 10000 
--	,@SortField					NVARCHAR(MAX) = NULL
--	,@OrderType					NVARCHAR(MAX) = NULL
--	,@SearchDetail				NVARCHAR(MAX) = NULL;

	----------------------------------------------------------
	IF @IndexStart		IS NULL    SET @IndexStart		= 0;
	IF @PageSize        IS NULL    SET @PageSize        = 10;
	IF @SearchDetail    IS NULL    SET @SearchDetail    = '';
	----------------------------------------------------------

	DECLARE @DocumentLink NVARCHAR(MAX) = '';
															
	SELECT	b.BillingRequestItemId							
			,b.BillingRequestItemCode
			,g.BillingRequestGroupId						
			,g.BillingRequestGroupCode
			,i.BillingDate
			,g.BillingDueDate
			,c.ClaimHeaderGroupImportDetailId
			,c.ClaimHeaderGroupCode							
			,c.ClaimCode									
			,c.Province										
			,IIF(c.IdentityCard IS NOT NULL,c.IdentityCard,ccd.Passport)			IdentityCard									
			,c.CustName										
			,c.DateHappen
			,CASE WHEN c.Pay = 0 THEN 0 ELSE c.Pay	- ISNULL(b.CoverAmount,0) END AS Pay
			,c.HospitalName									
			,c.DateIn										
			,c.DateOut										
			,c.ApplicationCode
			,bh.BranchDetail							Branch
			,c.ICD10_1Code						
			,c.ICD10
			,c.PolicyNo
			
			--SSS
			,c.Product										
			,IIF(c.DateNotice IS NULL, pa.DateNotice, NULL)		DateNotice
			,c.StartCoverDate								
			,c.ClaimAdmitType								
			,c.ClaimType													
			,c.IPDCount										
			,c.ICUCount										
			,c.Net										Net										
			,c.Compensate_Include
			,CASE WHEN f.ClaimHeaderGroupTypeId = 6 THEN ISNULL(i.TotalAmount,0)- ISNULL(b.CoverAmount,0) ELSE ISNULL(c.PaySS_Total,0)- ISNULL(b.CoverAmount,0) END Pay_Total
			,c.DiscountSS
			,c.PaySS_Total
											
			--SSSPA									
			,c.SchoolName									
			,c.CustomerDetailCode							
			,c.SchoolLevel									
			,c.Accident										
			,IIF(g.ClaimHeaderGroupTypeId = 3,  CONCAT(pa.ChiefComplain_id, ':',c.ChiefComplain) , c.ChiefComplain) 	 ChiefComplain							
			,c.Orgen										
			,c.Amount_Compensate_in							
			,c.Amount_Compensate_out						
			,c.Amount_Pay									
			,c.Amount_Dead									
			,c.Remark
			--
			,@DocumentLink										AS DocumentLink
			,b.CoverAmount
			,b.AmountTotal
			,smc.Detail											AS [Plan]
			,smcm.Detail										AS MemberCategory
			,COUNT(b.BillingRequestGroupId) OVER ( )			AS TotalCount
	FROM	dbo.BillingRequestItem AS b
			LEFT JOIN dbo.ClaimHeaderGroupImportDetail AS c
				ON b.ClaimHeaderGroupImportDetailId = c.ClaimHeaderGroupImportDetailId
			LEFT JOIN dbo.BillingRequestGroup AS g
				ON b.BillingRequestGroupId = g.BillingRequestGroupId
			---------------------------------------
			LEFT JOIN dbo.ClaimHeaderGroupImport i
				ON c.ClaimHeaderGroupImportId = i.ClaimHeaderGroupImportId
			LEFT JOIN dbo.ClaimHeaderGroupImportFile f
				ON i.ClaimGroupImportFileId = f.ClaimHeaderGroupImportFileId
			----2023-02-03--------------------------------------
			LEFT JOIN SSSPA.dbo.DB_ClaimHeader pa
				ON c.ClaimCode = pa.Code
			LEFT JOIN SSSPA.dbo.DB_CustomerDetail ccd
				ON c.CustomerDetailCode = ccd.code
			LEFT JOIN SSSPA.dbo.DB_Customer ccm
				ON ccd.Application_id = ccm.App_id
			LEFT JOIN SSSPA.dbo.MT_Product mtp
				ON ccm.Product_id = mtp.Code
			LEFT JOIN SSSPA.dbo.SM_Code smc
				ON mtp.ProductCategory_id = smc.Code
			LEFT JOIN SSSPA.dbo.SM_Code smcm
				ON ccd.CustomerType_id = smcm.Code
			----2023-08-15--------------------------------------
			LEFT JOIN DataCenterV1.Address.Branch bh
				ON c.CreatedByBranchId = bh.Branch_ID
			---------------------------------------------------
	WHERE	(b.BillingRequestGroupId = @BillingRequestGroupId)
	AND		b.IsActive = 1
			AND ccd.IsActive = 1

	ORDER BY 
			CASE WHEN @OrderType IS NULL    AND @SortField IS NULL        THEN BillingRequestItemId END ASC
			--,CASE WHEN @OrderType = 'ASC'    AND @SortField ='ClaimHeaderGroupCode'    THEN c.ClaimHeaderGroupCode END ASC
			--,CASE WHEN @OrderType = 'DESC'    AND @SortField ='Detail'    THEN Detail END DESC
	
	OFFSET @IndexStart ROWS FETCH NEXT @PageSize ROWS ONLY

END