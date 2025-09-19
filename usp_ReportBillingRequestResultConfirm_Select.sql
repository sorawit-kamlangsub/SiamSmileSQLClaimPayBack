USE [ClaimPayBack]
GO
--/****** Object:  StoredProcedure [dbo].[usp_ReportBillingRequestResultConfirm_Select]    Script Date: 1/9/2568 15:36:21 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

-- =============================================
-- Author:		Siriphong	Narkphung
-- Create date: 2023-02-06 14:00
-- Update date: Kittisak.Ph 2023-07-03
--				Chanadol Koonkam 2023-08-29
--				2023-08-31 Chanadol Koonkam Change CoverAmount from BillingRequestItem
--				2024-01-30 Kittisak.Ph Change Pay_Total To PaySS_Total
--				2024-07-05 Krekpon.D Add Where IsActive
-- Update date	2025-08-29 13:00
--				Comment pagination
-- Description:	<Description,,>
-- =============================================
--ALTER PROCEDURE [dbo].[usp_ReportBillingRequestResultConfirm_Select]
	-- Add the parameters for the stored procedure here
	DECLARE
	@DateType			INT				= 1
	,@ClaimGroupType	INT				= NULL
	,@DateFrom			DATE			='2024-07-01'

	,@DateTo			DATE			='2025-09-01'
	,@ClaimType			NVARCHAR(255)	= NULL
	,@InsuranceCompany	INT				= NULL
	,@IndexStart        INT = 0           
	,@PageSize			INT = 100             
	,@SortField			NVARCHAR(MAX)  = NULL 
	,@OrderType			NVARCHAR(MAX)  = NULL
	,@SearchDetail		NVARCHAR(MAX)  = NULL
--AS
--BEGIN
--	-- SET NOCOUNT ON added to prevent extra result sets from
--	-- interfering with SELECT statements.
--	SET NOCOUNT ON;

    ------------------------------------------------------------------------------
	--IF @IndexStart        IS NULL    SET @IndexStart    = 0;
	--IF @PageSize        IS NULL    SET @PageSize        = 10;
	--IF @SearchDetail    IS NULL    SET @SearchDetail    = '';
	------------------------------------------------------------------------------
	SET @DateTo = DATEADD(DAY,1,@DateTo)
	
	SELECT 
			b.Detail				Branch
			,gi.InsuranceCompanyName	InsuranceCompany					--Kittisak.Ph 2023-07-03
			,gi.CreatedDate			ImportDate
			,bg.BillingDate
			,bg.BillingDueDate --2023-02-06 Chanadol Koonkam
			,gi.ClaimHeaderGroupCode
			,gd.ApplicationCode
			,gd.Province
			,gd.ClaimCode
			,gd.IdentityCard
			,gd.CustName
			,gd.StartCoverDate
			,gd.HospitalName
			,gd.ICD10_1Code
			,gd.ICD10
			,gd.DateHappen
			,gd.DateIn
			,gd.DateOut
			,CASE WHEN gd.Pay = 0 THEN 0 ELSE gd.Pay - ISNULL(bi.coverAmount,0) END AS Pay				--Update Chanadol 2023-08-31
			,gd.Net
			--,gd.Pay_Total - ISNULL(bi.coverAmount,0) Pay_Total	--Update Chanadol 2023-08-31
			,ISNULL(gd.PaySS_Total,0) -ISNULL(bi.coverAmount,0) Pay_Total --Update By Kittisak.Ph 2024-01-30
			,bg.BillingRequestGroupCode
			,bi.BillingRequestItemCode
			--PH---
			,gd.Product
			,gd.IPDCount
			,gd.ICUCount
			,gd.ClaimAdmitType
			,ct.Detail			ClaimType
			,gd.Compensate_Include
	
			--PA---
			,gd.PolicyNo
			,gd.SchoolName
			,gd.CustomerDetailCode
			,gd.SchoolLevel
			,gd.Accident
			,gd.ChiefComplain
			,gd.Orgen
			,gd.Amount_Compensate_in
			,gd.Amount_Compensate_out
			,gd.Amount_Pay
			,gd.Amount_Dead
			,gd.Remark				AS PaRemark
	
			------Yellow------
			,bd.DecisionStatus
			,bd.RejectResult
			,bd.DecisionDate
			,bd.EstimatePaymentDate
			,bd.Remark
			,bd.PaymentReferenceId
			,IIF(bd.PaymentReferenceId IS NOT NULL,bd.CoverAmount,NULL) AS CoverAmount
			,IIF(bd.PaymentReferenceId IS NOT NULL,bd.UncoverAmount,NULL) AS UncoverAmount
			,IIF(bd.PaymentReferenceId IS NOT NULL,bd.UnCoverRemark,'') AS UnCoverRemark
			-----Green-----
			,bc.PaymentDate
			,bc.AmountPayment
			,bc.BankName
			,bc.BankAccountName
			,bc.BankAccountNumber
			,bc.Remark3

		FROM dbo.ClaimHeaderGroupImportFile gf
			LEFT JOIN dbo.ClaimHeaderGroupImport gi
				ON gf.ClaimHeaderGroupImportFileId = gi.ClaimGroupImportFileId
			LEFT JOIN dbo.ClaimHeaderGroupImportDetail gd
				ON gi.ClaimHeaderGroupImportId = gd.ClaimHeaderGroupImportId
			LEFT JOIN dbo.ClaimHeaderGroupImportStatus cs
				ON cs.ClaimHeaderGroupImportStatusId = gi.ClaimHeaderGroupImportStatusId

			LEFT JOIN dbo.BillingRequestGroup bg
				ON gi.BillingRequestGroupId = bg.BillingRequestGroupId
			LEFT JOIN dbo.BillingRequestItem bi
				ON gd.ClaimHeaderGroupImportDetailId = bi.ClaimHeaderGroupImportDetailId
			LEFT JOIN dbo.BillingRequestResultDetail bd
				ON bd.BillingRequestItemCode = bi.BillingRequestItemCode
			LEFT JOIN dbo.BillingRequestResultHeader bh
				ON bd.BillingRequestResultHeaderId = bh.BillingRequestResultHeaderId

			--LEFT JOIN dbo.BillingRequestGroupXResultDetail bx
			--	ON bd.BillingRequestResultDetailId = bx.BillingRequestResultDetailId
			

			LEFT JOIN dbo.BillingRequestResultConfirmDetail bc
				ON bd.BillingRequestResultDetailId = bc.BillingRequestResultDetailId
			LEFT JOIN SSS.dbo.MT_ClaimType ct
				ON bg.ClaimTypeCode = ct.Code
			LEFT JOIN
				(
				
						SELECT Code 
							,CreatedBy_id
						FROM SSS.dbo.DB_ClaimHeader
					UNION
						SELECT Code 
							,CreatedBy_id
						FROM SSSPA.dbo.DB_ClaimHeader
				) d
				ON gd.ClaimCode = d.Code
			LEFT JOIN SSS.dbo.DB_Employee emp
				ON d.CreatedBy_id = emp.Code
			LEFT JOIN SSS.dbo.DB_Team t
				ON emp.Team_id = t.Code
			LEFT JOIN SSS.dbo.MT_Branch b
				ON t.Branch_id = b.Code
		WHERE 
			(
				(
					@DateType = 1
					AND (gi.CreatedDate >= @DateFrom OR @DateFrom IS NULL)
					AND (gi.CreatedDate < @DateTo OR @DateTo IS NULL)
				)
				OR 
				(
					@DateType = 2
					AND (bg.BillingDate >= @DateFrom OR @DateFrom IS NULL)
					AND (bg.BillingDate < @DateTo OR @DateTo IS NULL)
				)
			)
			AND (gi.InsuranceCompanyId = @InsuranceCompany OR @InsuranceCompany IS NULL)
			AND (bg.ClaimTypeCode = @ClaimType OR @ClaimType IS NULL)
			AND (gf.ClaimHeaderGroupTypeId = @ClaimGroupType OR @ClaimGroupType IS NULL) -- เพิ่มให้รับค่า NULL ได้ By Krekpon 30-04-2024
			--AND cs.ClaimHeaderGroupImportStatusId = 3
			AND bg.BillingRequestGroupStatusId = 3
			AND gd.IsActive = 1															-- 2024-07-05 Krekpon.D Add Where IsActive
			AND (bc.IsActive = 1 OR bc.IsActive IS NULL)								-- 2024-07-12 Krekpon.D Where IsActive

		ORDER BY 
			 CASE WHEN @OrderType IS NULL    AND @SortField IS NULL        THEN bg.BillingRequestGroupId END ASC
			 --,CASE WHEN @OrderType = 'ASC'    AND @SortField ='Detail'    THEN Detail END ASC
			 --,CASE WHEN @OrderType = 'DESC'    AND @SortField ='Detail'    THEN Detail END DESC
	
		-- OFFSET @IndexStart ROWS FETCH NEXT @PageSize ROWS ONLY

--END
