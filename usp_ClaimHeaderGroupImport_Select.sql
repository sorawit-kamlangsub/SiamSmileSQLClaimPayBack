USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimHeaderGroupImport_Select]    Script Date: 23/9/2568 9:43:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Siriphong Narkphong
-- Create date: 2022-10-28
-- Update date: 2023-02-02 Add Parameter @ClaimHeaderGroupImportStatusId can NULL
--				2023-02-03 Change TotalAmount >> TotalAmount - CoverAmount
--				2023-07-03 Change InsuranceCompany
--				2023-09-04 Chang condition Select TotalAmount 
--				2024-02-01 Chang Check ClaimCompensate
--				2025-09-17 09:54 
--					Change เงื่อนไขการ ClaimHeaderGroupImportStatusId = 4 SELECT TotalAmount
-- Description:	Ui3-2
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimHeaderGroupImport_Select]
	-- Add the parameters for the stored procedure here
	@BillingDateFrom					DATE
	,@BillingDateTo						DATE
	,@ClaimHeaderGroupImportStatusId	INT
	,@IndexStart						INT = NULL           
	,@PageSize							INT = NULL             
	,@SortField							NVARCHAR(MAX)  = NULL 
	,@OrderType							NVARCHAR(MAX)  = NULL
	,@SearchDetail						NVARCHAR(MAX)  = NULL
AS
BEGIN
	
	SET NOCOUNT ON;

	------------------------------------------------------------------------------
	IF @IndexStart		IS NULL    SET @IndexStart		= 0;
	IF @PageSize		IS NULL    SET @PageSize        = 10;
	IF @SearchDetail	IS NULL    SET @SearchDetail    = '';
	------------------------------------------------------------------------------
	SET @BillingDateTo = DATEADD(DAY,1,@BillingDateTo)
	
	SELECT hi.ClaimHeaderGroupImportId
	      ,hi.ClaimHeaderGroupCode
	      ,hi.ItemCount
		  ,CASE 
			WHEN hi.ClaimHeaderGroupImportStatusId = 2 OR hi.ClaimHeaderGroupImportStatusId = 4 THEN hi.TotalAmount - ISNULL(rd.CoverAmount,0) 
			WHEN cc.countClaim > 1 OR hi.ClaimHeaderGroupImportStatusId = 3 THEN hi.TotalAmount - ISNULL(bi.CoverAmount,0) 
		   ELSE hi.TotalAmount END AS TotalAmount
	      ,hi.CreatedDate AS BillingDate
	      ,his.ClaimHeaderGroupImportStatusId
		  ,his.ClaimHeaderGroupImportStatusName
	      ,hi.InsuranceCompanyId 
		  ,hi.InsuranceCompanyName AS InsuranceCompany 
	      ,hi.BillingRequestGroupId	
		,COUNT(hi.ClaimHeaderGroupImportId) OVER ( ) TotalCount
	FROM dbo.ClaimHeaderGroupImport hi
		LEFT JOIN ClaimHeaderGroupImportStatus his
			ON hi.ClaimHeaderGroupImportStatusId = his.ClaimHeaderGroupImportStatusId
		--LEFT JOIN DataCenterV1.Organize.Organize ins
		--	ON hi.InsuranceCompanyId = ins.Organize_ID
		------2023-02-03-------------------------------------------------
		LEFT JOIN 
			(
				SELECT d.ClaimHeaderGroupImportId
					,SUM(bi.CoverAmount) CoverAmount
				FROM dbo.ClaimHeaderGroupImportDetail d
					LEFT JOIN dbo.BillingRequestItem bi
						ON d.ClaimHeaderGroupImportDetailId = bi.ClaimHeaderGroupImportDetailId  --Update Chanadol 2023-08-31
					--Update Chanadol 2024-02-01
					LEFT JOIN 
						(
							SELECT cs.ClaimCompensateCode
								,cs.ClaimHeaderCode
							FROM SSS.dbo.ClaimCompensate cs
							WHERE cs.IsActive = 1	
						)cs
						ON d.ClaimCode = cs.ClaimHeaderCode
				WHERE d.IsActive = 1 
				AND cs.ClaimCompensateCode IS NULL --Update Chanadol 2024-02-01
				AND bi.IsActive = 1
				GROUP BY d.ClaimHeaderGroupImportId
			)bi
			ON hi.ClaimHeaderGroupImportId = bi.ClaimHeaderGroupImportId
		LEFT JOIN 
			(
				SELECT d.ClaimHeaderGroupImportId
					,SUM(rd.CoverAmount) CoverAmount
				FROM dbo.ClaimHeaderGroupImportDetail d
					LEFT JOIN dbo.BillingRequestResultDetail rd
						ON d.ClaimHeaderGroupImportDetailId = rd.ClaimHeaderGroupImportDetailId
				--Update Chanadol 2024-02-01
				LEFT JOIN 
						(
							SELECT cs.ClaimCompensateCode
								,cs.ClaimHeaderCode
							FROM SSS.dbo.ClaimCompensate cs
							WHERE cs.IsActive = 1	
						)cs
						ON d.ClaimCode = cs.ClaimHeaderCode
				WHERE d.IsActive = 1
				AND cs.ClaimCompensateCode IS NULL  --Update Chanadol 2024-02-01
				AND rd.IsActive = 1
				GROUP BY d.ClaimHeaderGroupImportId
			)rd
			ON hi.ClaimHeaderGroupImportId = rd.ClaimHeaderGroupImportId
		LEFT JOIN 
			(
				SELECT d.ClaimHeaderGroupImportId
					,COUNT(rd.ClaimCode) countClaim
				FROM dbo.ClaimHeaderGroupImportDetail d 
					LEFT JOIN dbo.BillingRequestResultDetail rd
						ON d.ClaimHeaderGroupImportDetailId = rd.ClaimHeaderGroupImportDetailId
				WHERE d.IsActive = 1
				AND rd.IsActive = 1
				GROUP BY d.ClaimHeaderGroupImportId
			)cc
			ON hi.ClaimHeaderGroupImportId = cc.ClaimHeaderGroupImportId	
		----------------------------------------------------------
	WHERE (hi.BillingDate >= @BillingDateFrom)
	AND (hi.BillingDate < @BillingDateTo)
	AND hi.IsActive = 1
	AND (hi.ClaimHeaderGroupImportStatusId = @ClaimHeaderGroupImportStatusId OR @ClaimHeaderGroupImportStatusId IS NULL)--
	AND (hi.ClaimHeaderGroupCode LIKE '%'+@SearchDetail+'%' OR @SearchDetail IS NULL)
	
	ORDER BY 
		 CASE WHEN @OrderType IS NULL    AND @SortField IS NULL        THEN hi.ClaimHeaderGroupImportId END ASC
		 --,CASE WHEN @OrderType = 'ASC'    AND @SortField ='Detail'    THEN Detail END ASC
		 --,CASE WHEN @OrderType = 'DESC'    AND @SortField ='Detail'    THEN Detail END DESC
	
	OFFSET @IndexStart ROWS FETCH NEXT @PageSize ROWS ONLY
END
