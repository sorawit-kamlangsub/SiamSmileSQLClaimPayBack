USE [ClaimPayBack]
GO
	
	DECLARE @ClaimHeaderGroupCodes	NVARCHAR(MAX) = 'TSCMO57369010001' --CHSPO23169010002
  
  SELECT DISTINCT Element
	INTO #Tmplst
	from dbo.func_SplitStringToTable(@ClaimHeaderGroupCodes,',');
	
	SELECT 
		CASE 
			WHEN doc.TbType = 'ClaimMisc' THEN cm.ClaimMiscNo
			WHEN doc.TbType = 'ClaimOnlineAppCode' AND doc.DocumentSubTypeId = 339 THEN ISNULL(cm.ApplicationCode,'-')
			WHEN doc.TbType = 'ClaimOnlineDocCode' AND doc.DocumentSubTypeId = 339 THEN doc.DocumentCode
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
				AND doc.DocumentTypeId <> 3

				UNION ALL 

				SELECT 
					ClaimMiscId
					,DocumentId
					,DocumentCode
					,DocumentSubTypeId
					,'ClaimOnlineAppCode'			TbType
				FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
				WHERE IsActive = 1
				AND DocumentSubTypeId <> 340

				UNION ALL 

				SELECT 
					ClaimMiscId
					,DocumentId
					,DocumentCode
					,DocumentSubTypeId
					,'ClaimOnlineDocCode'			TbType
				FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
				WHERE IsActive = 1
				AND DocumentSubTypeId <> 340

		) doc
			ON doc.ClaimMiscId = cm.ClaimMiscId
	WHERE cm.IsActive = 1

	IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;