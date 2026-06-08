USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_GetDocumentIdDocStorage_Select]    Script Date: 8/6/2569 11:48:08 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sorawit KamlangSub
-- Create date: 2025-11-26 15:30
-- Update date: 2026-02-23 14:22 Remove doctype
-- Update date: 2026-05-26 16:42 Add DocumentSubTypeId
-- Description:	For Get DocStorage Data
-- =============================================
ALTER PROCEDURE [dbo].[usp_GetDocumentIdDocStorage_Select]
	@ClaimHeaderGroupCodes	NVARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON;

	-- Start Test
	--DECLARE  @ClaimHeaderGroupCodes NVARCHAR(MAX) =  'ZBMPO88869020001';
	-- End Test

	SELECT DISTINCT Element
	INTO #Tmplst
	from dbo.func_SplitStringToTable(@ClaimHeaderGroupCodes,',');
	
	SELECT 
		CASE 
			WHEN doc.TbType = 'ClaimMisc'	THEN cm.ClaimMiscNo
			WHEN doc.TbType = 'ClaimOnline' THEN cm.ApplicationCode
			WHEN doc.TbType = 'DocCode'		THEN doc.DocumentCode
		END MainIndex
		,cm.ClaimHeaderGroupCode
		,doc.DocumentId
		,doc.DocumentTypeId
		,doc.DocumentSubTypeId
		,doc.DocumentCode
	FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
		INNER JOIN #Tmplst tl
			ON cm.ClaimHeaderGroupCode = tl.Element
		LEFT JOIN
		(
				SELECT
					doc.ClaimMiscId
					,doc.DocumentId
					,doc.DocumentCode
					,'ClaimMisc'				TbType
					,doc.DocumentTypeId			DocumentTypeId
					,docType.DocumentSubTypeId	DocumentSubTypeId
				FROM [ClaimMiscellaneous].[misc].[Document] doc
				LEFT JOIN [ClaimMiscellaneous].[misc].[DocumentType] docType
					ON docType.DocumentTypeId = doc.DocumentTypeId
				WHERE doc.IsActive = 1
				AND doc.DocumentTypeId <> 3

				UNION ALL 

				SELECT 
					ClaimMiscId
					,DocumentId
					,DocumentCode
					,'ClaimOnline'			TbType
					,NULL					DocumentTypeId
					,DocumentSubTypeId	
				FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
				WHERE IsActive = 1
				AND DocumentSubTypeId <> 340

				UNION ALL 

				SELECT 
					ClaimMiscId
					,DocumentId
					,DocumentCode
					,'DocCode'				TbType
					,NULL					DocumentTypeId
					,DocumentSubTypeId	
				FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
				WHERE IsActive = 1
				AND DocumentSubTypeId <> 340


		) doc
			ON doc.ClaimMiscId = cm.ClaimMiscId
	WHERE cm.IsActive = 1

	IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;

	--DECLARE @MainIndex				NVARCHAR(MAX)
	--DECLARE @DocumentId				UNIQUEIDENTIFIER
	--DECLARE @ClaimHeaderGroupCode	NVARCHAR(MAX)
	--DECLARE @DocumentSubTypeId		INT
	--DECLARE @DocumentTypeId			INT
	--DECLARE @DocumentCode			NVARCHAR(MAX)
	--SELECT
	--	@MainIndex				MainIndex
	--	,@DocumentId			DocumentId
	--	,@ClaimHeaderGroupCode	ClaimHeaderGroupCode
	--	,@DocumentSubTypeId		DocumentSubTypeId
	--	,@DocumentTypeId		DocumentTypeId
	--	,@DocumentCode			DocumentCode
END
