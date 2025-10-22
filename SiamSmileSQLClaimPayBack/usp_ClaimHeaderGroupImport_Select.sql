USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimHeaderGroupImport_Select]    Script Date: 22/10/2568 15:52:42 ******/
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
-- Update date:2025-09-25 09:24 Bunchuai Chaiket
--					ถ้า @ClaimHeaderGroupImportStatusId = 4 ไม่ต้อง Filter วันที่
-- Update Date:2025-09-29 11:00 Sorawit kamlangsub
--					เพิ่ม Parameter @BranchId
--					เพิ่ม ฟิลด์ Branch Name
-- Update date:2025-10-21 15:53 Sorawit Kamlangsub
--					Add OPTION (RECOMPILE)
--					Update Filter BranchId
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
	,@BranchId							INT			   = NULL
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
		  ,ISNULL(b.Detail, N'สำนักงานใหญ่')	AS BranchName
	FROM dbo.ClaimHeaderGroupImport hi
		LEFT JOIN ClaimHeaderGroupImportStatus his
			ON hi.ClaimHeaderGroupImportStatusId = his.ClaimHeaderGroupImportStatusId
		LEFT JOIN 
			(
				SELECT d.ClaimHeaderGroupImportId
					,SUM(bi.CoverAmount) CoverAmount
				FROM dbo.ClaimHeaderGroupImportDetail d
					LEFT JOIN dbo.BillingRequestItem bi
						ON d.ClaimHeaderGroupImportDetailId = bi.ClaimHeaderGroupImportDetailId
					LEFT JOIN 
						(
							SELECT cs.ClaimCompensateCode
								,cs.ClaimHeaderCode
							FROM SSS.dbo.ClaimCompensate cs
							WHERE cs.IsActive = 1	
						)cs
						ON d.ClaimCode = cs.ClaimHeaderCode
				WHERE d.IsActive = 1 
				AND cs.ClaimCompensateCode IS NULL
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
				LEFT JOIN 
						(
							SELECT cs.ClaimCompensateCode
								,cs.ClaimHeaderCode
							FROM SSS.dbo.ClaimCompensate cs
							WHERE cs.IsActive = 1	
						)cs
						ON d.ClaimCode = cs.ClaimHeaderCode
				WHERE d.IsActive = 1
				AND cs.ClaimCompensateCode IS NULL
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
		--
		LEFT JOIN
		(
		SELECT u.ClaimHeaderGroup_id
			  ,u.Branch_id
		FROM
			(
				SELECT	 g.Code											ClaimHeaderGroup_id
						,g.Branch_id									Branch_id
				FROM  sss.dbo.DB_ClaimHeaderGroup g WITH(NOLOCK)
			UNION ALL	

				SELECT 	 g.Code											ClaimHeaderGroup_id
						,g.Branch_id									Branch_id
				 FROM SSSPA.dbo.DB_ClaimHeaderGroup g WITH(NOLOCK)
			) u
		) x
		ON x.ClaimHeaderGroup_id = hi.ClaimHeaderGroupCode
		LEFT JOIN sss.dbo.MT_Branch b
			ON x.Branch_id = b.Code
		LEFT JOIN [DataCenterV1].[Address].[Branch] cb
			ON cb.tempcode = b.Code
	WHERE 
	(
		(@ClaimHeaderGroupImportStatusId = 4)
		OR (hi.CreatedDate >= @BillingDateFrom AND hi.CreatedDate < @BillingDateTo)
	)	
	AND hi.IsActive = 1
	AND (hi.ClaimHeaderGroupImportStatusId = @ClaimHeaderGroupImportStatusId OR @ClaimHeaderGroupImportStatusId IS NULL)
	AND (hi.ClaimHeaderGroupCode LIKE '%'+@SearchDetail+'%' OR @SearchDetail IS NULL)
	AND (cb.Branch_ID = @BranchId OR @BranchId IS NULL)
	
	ORDER BY 
		 CASE WHEN @OrderType IS NULL    AND @SortField IS NULL        THEN hi.ClaimHeaderGroupImportId END ASC
		 --,CASE WHEN @OrderType = 'ASC'    AND @SortField ='Detail'    THEN Detail END ASC
		 --,CASE WHEN @OrderType = 'DESC'    AND @SortField ='Detail'    THEN Detail END DESC
	
	OFFSET @IndexStart ROWS FETCH NEXT @PageSize ROWS ONLY

	OPTION (RECOMPILE)
END;
