USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_OrganizeInfo_Select]    Script Date: 16/10/2568 13:19:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Mr.Bunchuai chaiket
-- Create date: 2025-09-23 08:52 
-- Update date: 2025-10-16 13:30 Sorawit Kamlangsub
--				ปรับ Parameter
-- Description:	Function สำหรับ Get User info ทั้งหมด
-- =============================================
ALTER PROCEDURE [dbo].[usp_OrganizeInfo_Select]
			@Organize_ID	INT
AS
BEGIN
SET NOCOUNT ON;

-- =============================================
--DECLARE @Organize_ID INT = 389190;
-- =============================================

SELECT 
	og.Organize_ID
	,og.OrganizeCode
	,og.OrganizeDetail
	,cm.ShortName
	,cm.ShortName2
FROM [DataCenterV1].[Organize].[Organize] og
	INNER JOIN [SSS].[dbo].[MT_Company] cm
		ON og.OrganizeCode = cm.Code
WHERE og.IsActive = 1
	AND og.OrganizeType_ID = 2
	AND og.Organize_ID = @Organize_ID

END;