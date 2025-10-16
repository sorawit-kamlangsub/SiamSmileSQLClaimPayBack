USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_PersonalInfo_Select]    Script Date: 16/10/2568 13:34:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Mr.Bunchuai chaiket
-- Create date: 2025-09-17 09:46 
-- Description:	Function สำหรับ Get User info ทั้งหมด
-- =============================================
ALTER PROCEDURE [dbo].[usp_PersonalInfo_Select]
			@UserId	INT = NULL
AS
BEGIN
SET NOCOUNT ON;

-- =============================================
--DECLARE @UserId INT = 3287;
-- =============================================

SELECT 
	UserId
	,EmployeeCode
	,PersonName
	,Title
	,FirstName
	,LastName
FROM DataCenterV1.[Person].vw_PersonUser
WHERE UserId = @UserId

END;