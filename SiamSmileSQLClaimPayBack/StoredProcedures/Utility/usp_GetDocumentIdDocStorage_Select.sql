USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_GetDocumentIdDocStorage_Select]    Script Date: 11/16/2026 11:04:41 AM ******/
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
	--DECLARE  @ClaimHeaderGroupCodes NVARCHAR(MAX) =  'CHCMH88869060002';
	-- End Test

	SELECT 
		CASE 
			WHEN doc.TbType = 'ClaimMisc' AND cm.ClaimTypeId = 2 THEN cddg.ClaimPayBackSubGroupCode
			WHEN doc.TbType = 'ClaimMisc' THEN cm.ClaimMiscNo
			WHEN doc.TbType = 'ClaimOnline' THEN cm.ApplicationCode
			WHEN doc.TbType = 'DocCode'		THEN doc.DocumentCode
			WHEN doc.TbType = 'ClaimOnlineV2'	THEN col.ApplicationCode
		END MainIndex
		,tmp.Element			ClaimHeaderGroupCode
		,doc.DocumentId
		,doc.DocumentTypeId
		,doc.DocumentSubTypeId
		,doc.DocumentCode
		,cm.ProductTypeId
	FROM dbo.func_SplitStringToTable(@ClaimHeaderGroupCodes,',') tmp
		LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			ON tmp.Element = cm.ClaimHeaderGroupCode
		LEFT JOIN (
			SELECT 
			 pa.Code				ClaimHeaderGroupCode		 
			 ,col.ApplicationCode
			 ,col.ClaimOnLineItemId	
			 ,col.IsActive 
			FROM [SSSPA].[dbo].[DB_ClaimHeaderGroup] pa
				INNER JOIN [SSSPA].[dbo].[DB_ClaimHeader] cl
					ON pa.Code = cl.ClaimheaderGroup_id
				INNER JOIN [ClaimOnlineV2].[dbo].[ClaimOnlineItem] col
					ON cl.Code = col.ClaimCode
			WHERE
				col.ClaimAdmitTypeCode IN (
				'4000'	
				,'4001'	
				,'4006'	
				,'4006_2'	
				,'4007'	
				,'4008'	
				,'5001'	
				,'5002'	
				)
			
			UNION ALL 

			SELECT 
			 ph.Code				ClaimHeaderGroupCode
			 ,col.ApplicationCode
			 ,col.ClaimOnLineItemId	
			 ,col.IsActive 
			FROM [SSS].[dbo].[DB_ClaimHeaderGroup] ph
				INNER JOIN [sss].[dbo].[DB_ClaimHeader] cl
					ON ph.Code = cl.ClaimHeaderGroup_id
				INNER JOIN [ClaimOnlineV2].[dbo].[ClaimOnlineItem] col
					ON cl.Code = col.ClaimCode
			WHERE ph.ClaimAdmitType_id IN (
				'4000'	
				,'4001'	
				,'4006'	
				,'4006_2'	
				,'4007'	
				,'4008'	
				,'5001'	
				,'5002'	
				)
		) col
			ON tmp.Element = col.ClaimHeaderGroupCode
		LEFT JOIN
		(
				SELECT
					doc.ClaimMiscId				Id
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
					ClaimMiscId				Id
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
					ClaimMiscId				Id
					,DocumentId
					,DocumentCode
					,'DocCode'				TbType
					,NULL					DocumentTypeId
					,DocumentSubTypeId	
				FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
				WHERE IsActive = 1
				AND DocumentSubTypeId <> 340

				UNION ALL

				SELECT
					ClaimOnLineItemId		Id
					,DocumentId
					,DocumentCode
					,'ClaimOnlineV2'		TbType
					,NULL					DocumentTypeId
					,NULL					DocumentSubTypeId	
				FROM [ClaimOnlineV2].[dbo].[Document] 
				WHERE IsActive = 1

		) doc
			ON doc.Id = cm.ClaimMiscId OR doc.Id = col.ClaimOnLineItemId
		LEFT JOIN (
			SELECT 
				cd.ClaimGroupCode
				,cdg.ClaimPayBackSubGroupId
				,cdg.ClaimPayBackSubGroupCode
			FROM  [dbo].ClaimPayBackDetail cd
				LEFT JOIN [dbo].ClaimPayBackSubGroup cdg 
					ON cd.ClaimPayBackSubGroupId = cdg.ClaimPayBackSubGroupId
			WHERE cd.IsActive = 1
				AND cdg.IsActive = 1
		)
		cddg
			ON cm.ClaimHeaderGroupCode = cddg.ClaimGroupCode
	WHERE cm.IsActive = 1 OR col.IsActive = 1

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
