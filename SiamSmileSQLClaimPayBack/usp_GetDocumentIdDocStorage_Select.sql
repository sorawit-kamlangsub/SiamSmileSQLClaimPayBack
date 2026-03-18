USE [ClaimPayBack]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sorawit KamlangSub
-- Create date: 2025-11-26 15:30
-- Update date: 2026-02-23 14:22 Remove doctype
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
			WHEN doc.TbType = 'ClaimMisc' THEN cm.ClaimMiscNo
			WHEN doc.TbType = 'ClaimOnlineAppCode' THEN cm.ApplicationCode
			WHEN doc.TbType = 'ClaimOnlineDocCode' THEN doc.DocumentCode
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
					,'ClaimMisc'			TbType
				FROM [ClaimMiscellaneous].[misc].[Document] doc
				WHERE doc.IsActive = 1
				AND doc.DocumentTypeId <> 3

				UNION ALL 

				SELECT 
					ClaimMiscId
					,DocumentId
					,DocumentCode
					,'ClaimOnlineAppCode'			TbType
				FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
				WHERE IsActive = 1
				AND DocumentSubTypeId <> 340

				UNION ALL 

				SELECT 
					ClaimMiscId
					,DocumentId
					,DocumentCode
					,'ClaimOnlineDocCode'			TbType
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
	--SELECT
	--	@MainIndex				MainIndex
	--	,@DocumentId			DocumentId
	--	,@ClaimHeaderGroupCode	ClaimHeaderGroupCode

END