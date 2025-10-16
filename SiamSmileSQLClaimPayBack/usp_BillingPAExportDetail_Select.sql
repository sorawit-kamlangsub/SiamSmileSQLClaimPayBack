USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingPAExportDetail_Select]    Script Date: 16/10/2568 11:26:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Krekpon Dokkamklang
-- Create date: 24-09-2025 13:58
-- Description:	ดึงข้อมูลมาแสดงในเอกสารนำส่ง บ.ประกัน ของ PA
-- =============================================
ALTER PROCEDURE [dbo].[usp_BillingPAExportDetail_Select]
	-- Add the parameters for the stored procedure here
	@ClaimCode NVARCHAR(50)
	,@BillingRequestGroupCode NVARCHAR(50)
AS
BEGIN
	SELECT
 v.*
	 ,x.BillingRequestGroupCode
	 ,x.BillingRequestItemCode
	 ,x.DocumentLink
	 ,x.Province
	 ,x.Orgen
	 ,cd.LevelRoom

	FROM [SSSPA].[dbo].[rpt_ClaimHeaderGroupDetail]  v
	  LEFT JOIN [ClaimPayBack].[dbo].BillingExport x
	  ON v.Code = x.ClaimCode
	  LEFT JOIN [SSSPA].[dbo].[DB_ClaimHeader] ch
	  ON ch.Code = v.Code
	  LEFT JOIN [SSSPA].[dbo].[DB_CustomerDetail] cd
	  ON ch.CustomerDetail_id = cd.Code
	WHERE v.Code = @ClaimCode
	 AND x.BillingRequestGroupCode = @BillingRequestGroupCode
	 AND cd.IsActive = 1
END;
