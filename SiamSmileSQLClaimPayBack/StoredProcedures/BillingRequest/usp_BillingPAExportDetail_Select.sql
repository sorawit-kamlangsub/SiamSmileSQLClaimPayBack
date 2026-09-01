USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingPAExportDetail_Select]    Script Date: 6/11/2568 9:26:10 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Krekpon Dokkamklang
-- Create date: 24-09-2025 13:58
-- Update date: 2025-10-16 13:25 Krekpon.D 
--				แก้เปลี่ยน v.* เป็นตัวแปรที่ต้องใช้
-- Update date: 2025-11-05 Bunchuai
--				Fix Remark Field
-- Description:	ดึงข้อมูลมาแสดงในเอกสารนำส่ง บ.ประกัน ของ PA
-- =============================================
ALTER PROCEDURE [dbo].[usp_BillingPAExportDetail_Select]
	-- Add the parameters for the stored procedure here
	@ClaimCode NVARCHAR(50)
	,@BillingRequestGroupCode NVARCHAR(50)
AS
BEGIN
	SELECT
	  v.ClaimheaderGroup_id
	 ,v.PolicyNo
	 ,v.Code
	 ,v.School
	 ,v.CustName
	 ,v.DateHappen
	 ,v.AccidentCause
	 ,v.ChiefComplain
	 ,v.Amount_Net
	 ,v.Amount_Compensate_in
	 ,v.Amount_Compensate_out
	 ,v.Amount_Pay
	 ,v.Amount_Dead
	 ,v.Amount_Total
	 ,v.Hospital
	 ,ch.AccidentDetail	Remark
	 ,v.DateIn
	 ,v.DateOut
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
