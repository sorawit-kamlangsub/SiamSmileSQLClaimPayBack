USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_GetDocumentIdDocStorage_Select]    Script Date: 2/12/2568 13:51:28 ******/
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
		CASE 
			WHEN doc.TbType = 'ClaimMisc' THEN CAST(doc.DocumentId AS NVARCHAR(MAX))
			WHEN doc.TbType = 'ClaimOnline' AND doc.DocumentSubTypeId = 339 THEN cm.ApplicationCode
			WHEN doc.TbType = 'ClaimOnline' AND doc.DocumentSubTypeId <> 339 THEN doc.DocumentCode
		END MainIndex
		,cm.ClaimHeaderGroupCode
		,doc.DocumentId
	FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
		INNER JOIN #Tmplst tl
			ON cm.ClaimHeaderGroupCode = tl.Element
		LEFT JOIN
		(
				SELECT
					doc.ClaimMiscId
					,doc.DocumentId
					,doc.DocumentCode
					,doct.DocumentSubTypeId
					,'ClaimMisc'			TbType
				FROM [ClaimMiscellaneous].[misc].[Document] doc
					LEFT JOIN [ClaimMiscellaneous].[misc].[DocumentType] doct
						ON doct.DocumentTypeId = doc.DocumentTypeId
				WHERE doc.IsActive = 1

				UNION ALL 

				SELECT 
					ClaimMiscId
					,DocumentId
					,DocumentCode
					,DocumentSubTypeId
					,'ClaimOnline'			TbType
				FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
				WHERE IsActive = 1
		) doc
			ON doc.ClaimMiscId = cm.ClaimMiscId
	WHERE cm.IsActive = 1

	IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;

	--DECLARE @MainIndex				NVARCHAR(MAX)
	--DECLARE @DocumentId				UNIQUEIDENTIFIER
	--DECLARE @ClaimHeaderGroupCode	NVARCHAR(MAX)
	--SELECT
	--	@MainIndex				MainIndex
	--	,@DocumentId			DocumentId
	--	,@ClaimHeaderGroupCode	ClaimHeaderGroupCode

END
