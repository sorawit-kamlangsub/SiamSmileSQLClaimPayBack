USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequestGroup_Select]    Script Date: 22/10/2568 9:19:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Napaporn  Saarnwong
-- Create date: 2022-10-28 10:50
-- Update date: 2023-02-02 16:50 Siriphong	Narkphung Add Column ClaimType
--				2023-07-03 12:47 Sahatsawat golffy Change Column InsuranceCompanyName
--				2023-10-09 16:48 Chanadol Koonkam Add Column ClaimHeaderGroupTypeName
--				2025-09-17 15:37 Bunchuai Chaiket เพิ่ม LEFT JOIN [Organize]/ SFTPConfig สำหรับการตรวจสอบ บ.ที่มี/ ไม่มี SFTP
--				2025-09-19 16:21 Krekpon Dokkamklang เพิ่ม paremeter การรับข้อมูลในการกรอง
-- Description:	
-- =============================================
ALTER PROCEDURE [dbo].[usp_BillingRequestGroup_Select]
	-- Add the parameters for the stored procedure here
		@InsurunceCompanyId				INT = NULL
		,@BillingDate					DATE = NULL
		,@BillingRequestGroupStatusId	INT = NULL
		,@ClaimType						NVARCHAR(25) = NULL
		,@ClaimHeaderGroupTypeId				INT = NULL
		,@IndexStart					INT = NULL 
		,@PageSize						INT = NULL 
		,@SortField						NVARCHAR(MAX) = NULL
		,@OrderType						NVARCHAR(MAX) = NULL
		,@SearchDetail					NVARCHAR(MAX) = NULL
AS
BEGIN
	SET NOCOUNT ON;

----------------------------------------------------------
IF @IndexStart			IS NULL    SET @IndexStart		= 0;
IF @PageSize			IS NULL    SET @PageSize        = 10;
IF @SearchDetail		IS NULL    SET @SearchDetail    = '';
----------------------------------------------------------

--DECLARE @InsurunceCompanyId				INT = NULL;
--DECLARE @BillingDate					DATE = '2025-09-16';
--DECLARE @BillingRequestGroupStatusId	INT = 2;
--DECLARE @SearchDetail	VARCHAR(MAX) = NULL;
	
	SELECT	g.BillingRequestGroupId										
			,g.BillingRequestGroupCode									
			,cgt.ClaimHeaderGroupTypeName								
			,g.InsuranceCompanyId	 			AS InsuranceCompanyId
			,o.OrganizeCode						AS OrganizeCode 
			,g.InsuranceCompanyName				AS InsuranceCompanyName		 
			,g.ItemCount												
			,g.TotalAmount												
			,g.BillingRequestGroupStatusId								
			,s.BillingRequestGroupStatusName 							
			,cg.BillingDate												
			,g.BillingDueDate
			,ct.Detail									AS ClaimType 
			,COUNT(g.BillingRequestGroupId) OVER ( )	AS TotalCount
			,IIF(sfc.SFTPConfigId IS NULL, 0, 1)  		AS IsSFTP
	FROM	dbo.BillingRequestGroup AS g
			LEFT JOIN dbo.BillingRequestGroupStatus AS s
				ON g.BillingRequestGroupStatusId = s.BillingRequestGroupStatusId
			LEFT JOIN DataCenterV1.Organize.Organize AS o
				ON g.InsuranceCompanyId = o.Organize_ID
			LEFT JOIN 
				(
					SELECT BillingRequestGroupId
						,ClaimTypeCode
						,BillingDate
					FROM dbo.ClaimHeaderGroupImport 
					WHERE IsActive = 1
					GROUP BY BillingRequestGroupId,ClaimTypeCode,BillingDate
				)cg
				ON g.BillingRequestGroupId = cg.BillingRequestGroupId
			LEFT JOIN SSS.dbo.MT_ClaimType ct
				ON cg.ClaimTypeCode = ct.Code
			LEFT JOIN dbo.ClaimHeaderGroupType cgt
				ON g.ClaimHeaderGroupTypeId = cgt.ClaimHeaderGroupTypeId
			LEFT JOIN (
				SELECT 
					Organize_ID
					,OrganizeCode
				FROM [DataCenterV1].[Organize].[Organize]
				WHERE OrganizeType_ID = 2
			) mtc
				ON g.InsuranceCompanyId = mtc.Organize_ID
			LEFT JOIN (
				SELECT *
				FROM dbo.SFTPConfig
				WHERE IsActive = 1
			) sfc
				ON mtc.OrganizeCode = sfc.InsuranceCompanyCode

	WHERE	(g.InsuranceCompanyId = @InsurunceCompanyId OR @InsurunceCompanyId IS NULL)
	AND		(cg.BillingDate = @BillingDate OR @BillingDate IS NULL)
	AND		(g.BillingRequestGroupStatusId = @BillingRequestGroupStatusId OR @BillingRequestGroupStatusId IS NULL)
	AND		g.IsActive = 1
	AND		(g.BillingRequestGroupCode LIKE '%'+ ISNULL(@SearchDetail, '') +'%')
	AND		(ct.Code = @ClaimType OR @ClaimType IS NULL)
	AND		(g.ClaimHeaderGroupTypeId = @ClaimHeaderGroupTypeId OR @ClaimHeaderGroupTypeId IS NULL)

	ORDER BY 
			CASE WHEN @OrderType IS NULL    AND @SortField IS NULL        THEN g.BillingRequestGroupId END ASC
			,CASE WHEN @OrderType = 'ASC'    AND @SortField ='BillingRequestGroupCode'    THEN g.BillingRequestGroupCode END ASC
			,CASE WHEN @OrderType = 'DESC'    AND @SortField ='BillingRequestGroupCode'    THEN g.BillingRequestGroupCode END DESC
			,CASE WHEN @OrderType = 'ASC'    AND @SortField ='ClaimHeaderGroupTypeName'    THEN cgt.ClaimHeaderGroupTypeName END ASC
			,CASE WHEN @OrderType = 'DESC'    AND @SortField ='ClaimHeaderGroupTypeName'    THEN cgt.ClaimHeaderGroupTypeName END DESC
			,CASE WHEN @OrderType = 'ASC'    AND @SortField ='InsuranceCompanyName'    THEN g.InsuranceCompanyName END ASC
			,CASE WHEN @OrderType = 'DESC'    AND @SortField ='InsuranceCompanyName'    THEN g.InsuranceCompanyName END DESC
			,CASE WHEN @OrderType = 'ASC'    AND @SortField ='ItemCount'    THEN g.ItemCount END ASC
			,CASE WHEN @OrderType = 'DESC'    AND @SortField ='ItemCount'    THEN g.ItemCount END DESC
			,CASE WHEN @OrderType = 'ASC'    AND @SortField ='TotalAmount'    THEN g.TotalAmount END ASC
			,CASE WHEN @OrderType = 'DESC'    AND @SortField ='TotalAmount'    THEN g.TotalAmount END DESC
			,CASE WHEN @OrderType = 'ASC'    AND @SortField ='ClaimType'    THEN ct.Detail END ASC
			,CASE WHEN @OrderType = 'DESC'    AND @SortField ='ClaimType'    THEN ct.Detail END DESC
			,CASE WHEN @OrderType = 'ASC'    AND @SortField ='BillingDate'    THEN cg.BillingDate END ASC
			,CASE WHEN @OrderType = 'DESC'    AND @SortField ='BillingDate'    THEN cg.BillingDate END DESC
	
	OFFSET @IndexStart ROWS FETCH NEXT @PageSize ROWS ONLY

	OPTION(RECOMPILE);

END;

