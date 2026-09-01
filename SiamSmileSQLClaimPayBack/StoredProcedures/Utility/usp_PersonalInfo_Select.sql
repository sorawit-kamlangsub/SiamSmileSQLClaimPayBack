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
			@UserId	INT
AS
BEGIN
SET NOCOUNT ON;

-- =============================================
-- DECLARE @UserId INT = 3287;
-- =============================================

SELECT
  pu.User_ID		UserId
  ,e.EmployeeCode
  ,pT.TitleDetail + p.FirstName + ' ' + p.LastName PersonName
  ,pT.TitleDetail	Title
  ,p.FirstName
  ,p.LastName
FROM
  ( 
  SELECT 
	User_ID
	, Person_ID
	, Employee_ID
		FROM DataCenterV1.Person.PersonUser t 
		WHERE IsActive = 1 
	) pu
  LEFT OUTER JOIN DataCenterV1.Person.Person p 
	ON pu.Person_ID = p.Person_ID
  LEFT OUTER JOIN 
  ( 
	SELECT 
		Employee_ID
		, EmployeeCode
	FROM DataCenterV1.Employee.Employee t
	WHERE IsActive = 1 
	) e 
	ON pu.Employee_ID = e.Employee_ID
  INNER JOIN DataCenterV1.Person.Title pT 
	ON p.Title_ID = pT.Title_ID
  WHERE pt.IsActive = 1  
  AND pu.User_ID = @UserId

END;