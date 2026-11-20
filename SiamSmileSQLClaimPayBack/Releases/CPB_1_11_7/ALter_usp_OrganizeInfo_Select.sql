USE [ClaimPayBack]
GO

/****** Object:  StoredProcedure [dbo].[usp_OrganizeInfo_Select]    Script Date: 20/11/2569 8:34:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Mr.Bunchuai chaiket
-- Create date: 2025-09-23 08:52 
-- Update date: 2025-10-16 13:30 Sorawit Kamlangsub
--				ปรับ Parameter
-- Update date:	2026-01-13 10:38
--				Select DocumentExpiry เพิ่ม
--				2026-03-05 11:21 Bunchuai Chaiket
--				เพิ่ม WHERE OrganizeType_ID IN (2,6)
-- Description:	Function สำหรับ Get User info ทั้งหมด
-- =============================================
ALTER PROCEDURE [dbo].[usp_OrganizeInfo_Select]
			@Organize_ID	INT
AS
BEGIN
SET NOCOUNT ON;

-- =============================================
--DECLARE @Organize_ID INT = 21;
-- =============================================

SELECT 
	og.Organize_ID
	,og.OrganizeCode
	,og.OrganizeDetail
	,cm.ShortName
	,cm.ShortName2
	,IIF(sfc.DocumentExpiry IS NULL,45,sfc.DocumentExpiry) DocumentExpiry
FROM [DataCenterV1].[Organize].[Organize] og
	INNER JOIN [SSS].[dbo].[MT_Company] cm
		ON og.OrganizeCode = cm.Code
	LEFT JOIN dbo.SFTPConfig sfc
		ON og.OrganizeCode = sfc.InsuranceCompanyCode
WHERE og.IsActive = 1
	AND og.OrganizeType_ID IN (2,6)
	AND og.Organize_ID = @Organize_ID

END;
GO

