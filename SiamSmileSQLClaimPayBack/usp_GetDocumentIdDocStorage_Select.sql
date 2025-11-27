USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_GetDocumentIdDocStorage_Select]    Script Date: 27/11/2568 8:48:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sorawit KamlangSub
-- Create date: 2025-11-26 15:30
-- Description:	For Get DocStorage Data
-- =============================================
ALTER PROCEDURE [dbo].[usp_GetDocumentIdDocStorage_Select]
	@ClaimHeaderGroupCodes	NVARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT DISTINCT Element
	INTO #Tmplst
	from dbo.func_SplitStringToTable(@ClaimHeaderGroupCodes,',');
	
	SELECT 
		cm.ApplicationCode
		,cm.ClaimHeaderGroupCode
		,doc.DocumentId
	FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
		INNER JOIN #Tmplst tl
			ON cm.ClaimHeaderGroupCode = tl.Element
		LEFT JOIN
		(
				SELECT
					ClaimMiscId
					,DocumentId
				FROM [ClaimMiscellaneous].[misc].[Document]
				WHERE IsActive = 1

				UNION ALL 

				SELECT 
					ClaimMiscId
					,DocumentId
				FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
				WHERE IsActive = 1
		) doc
			ON doc.ClaimMiscId = cm.ClaimMiscId
	WHERE cm.IsActive = 1

	--DECLARE @ApplicationCode		NVARCHAR(MAX)
	--DECLARE @DocumentId				UNIQUEIDENTIFIER
	--DECLARE @ClaimHeaderGroupCode	NVARCHAR(MAX)
	--SELECT
	--	@ApplicationCode		ApplicationCode
	--	,@DocumentId			DocumentId
	--	,@ClaimHeaderGroupCode	ClaimHeaderGroupCode

END
