USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequestItem_Select]    Script Date: 18/11/2568 9:06:06 ******/
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
			,c.IdentityCard									
			,c.CustName										
			,c.DateHappen									
			--,c.Pay	- ISNULL(rrd.CoverAmount,0)			Pay	--Folk Update 2023-01-05	
			,CASE WHEN c.Pay = 0 THEN 0 ELSE c.Pay	- ISNULL(b.CoverAmount,0) END AS Pay --Chanadol Update 2023-08-31
			,c.HospitalName									
			,c.DateIn										
			,c.DateOut										
			,c.ApplicationCode
			,bh.BranchDetail							Branch --Folk Update 2023-08-15
			--,IIF(phb.Detail IS NULL,pab.Detail,phb.Detail) Branch--Folk Update 2023-02-03
			,c.ICD10_1Code		--Folk Update 2023-03-13							
			,c.ICD10				--Folk Update 2023-03-13	
			,c.PolicyNo				--Folk Update 2023-03-13	
			
			--SSS
			,c.Product										
			,c.DateNotice									
			,c.StartCoverDate								
			,c.ClaimAdmitType								
			,c.ClaimType													
			,c.IPDCount										
			,c.ICUCount										
			,c.Net										Net	--Folk Update 2023-01-05											
			,c.Compensate_Include							
			--,c.Pay_Total - ISNULL(rrd.CoverAmount,0)	Pay_Total --Folk Update 2023-01-05	
			--,c.Pay_Total - ISNULL(b.CoverAmount,0)	Pay_Total --Chanadol Update 2023-08-31
			,ISNULL(c.PaySS_Total,0)- ISNULL(b.CoverAmount,0) Pay_Total --Chanadol  Update 2024-01-26
			,c.DiscountSS
			,c.PaySS_Total
											
			--SSSPA									
			,c.SchoolName									
			,c.CustomerDetailCode							
			,c.SchoolLevel									
			,c.Accident										
			,c.ChiefComplain								
			,c.Orgen										
			,c.Amount_Compensate_in							
			,c.Amount_Compensate_out						
			,c.Amount_Pay									
			,c.Amount_Dead									
			,c.Remark
			--
			,@DocumentLink				AS DocumentLink		

			,b.CoverAmount
			,b.AmountTotal

			--,b.IsActive
			--,b.CreatedDate
			--,b.CreatedByUserId
			--,b.UpdatedDate
			--,b.UpdatedByUserId
			,COUNT(b.BillingRequestGroupId) OVER ( ) AS TotalCount
	FROM	dbo.BillingRequestItem AS b
			LEFT JOIN dbo.ClaimHeaderGroupImportDetail AS c
				ON b.ClaimHeaderGroupImportDetailId = c.ClaimHeaderGroupImportDetailId
			LEFT JOIN dbo.BillingRequestGroup AS g
				ON b.BillingRequestGroupId = g.BillingRequestGroupId
			--LEFT JOIN dbo.BillingRequestResultDetail rrd
			--	ON c.ClaimHeaderGroupImportDetailId = rrd.ClaimHeaderGroupImportDetailId
			---------------------------------------
			LEFT JOIN dbo.ClaimHeaderGroupImport i
				ON c.ClaimHeaderGroupImportId = i.ClaimHeaderGroupImportId
			LEFT JOIN dbo.ClaimHeaderGroupImportFile f
				ON i.ClaimGroupImportFileId = f.ClaimHeaderGroupImportFileId
			----2023-02-03--------------------------------------
			--LEFT JOIN SSSPA.dbo.DB_ClaimHeader pa
			--	ON c.ClaimCode = pa.Code
			--LEFT JOIN SSS.dbo.DB_Employee pae
			--	ON pa.CreatedBy_id = pae.Code
			--LEFT JOIN SSS.dbo.DB_Team pat
			--	ON pae.Team_id = pat.Code
			--LEFT JOIN SSS.dbo.MT_Branch pab
			--	ON pat.Branch_id = pab.Code

			--LEFT JOIN SSS.dbo.DB_ClaimHeader ph
			--	ON c.ClaimCode = ph.Code
			--LEFT JOIN SSS.dbo.DB_Employee phe
			--	ON ph.CreatedBy_id = phe.Code
			--LEFT JOIN SSS.dbo.DB_Team pht
			--	ON phe.Team_id = pht.Code
			--LEFT JOIN SSS.dbo.MT_Branch phb
			--	ON pht.Branch_id = phb.Code
			----2023-08-15--------------------------------------
			LEFT JOIN DataCenterV1.Address.Branch bh
				ON c.CreatedByBranchId = bh.Branch_ID
			---------------------------------------------------
	WHERE	(b.BillingRequestGroupId = @BillingRequestGroupId)
	AND		b.IsActive = 1

	ORDER BY 
			CASE WHEN @OrderType IS NULL    AND @SortField IS NULL        THEN BillingRequestItemId END ASC
			,CASE WHEN @OrderType = 'ASC'    AND @SortField ='ClaimHeaderGroupCode'    THEN c.ClaimHeaderGroupCode END ASC
			--,CASE WHEN @OrderType = 'DESC'    AND @SortField ='Detail'    THEN Detail END DESC
	
	OFFSET @IndexStart ROWS FETCH NEXT @PageSize ROWS ONLY

END

