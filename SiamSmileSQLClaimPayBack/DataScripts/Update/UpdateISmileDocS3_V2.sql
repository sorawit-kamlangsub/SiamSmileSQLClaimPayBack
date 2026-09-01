USE [ClaimPayBack]
GO

DECLARE @D DATETIME = GETDATE();
DECLARE @CutOffDate DATETIME = DATEADD(DAY,-30,@D);

SELECT *
INTO #TmpClaimCodes
FROM 
(
SELECT ccg.ClaimCompensateGroupCode	ClaimHeaderGroup_id
	, cc.ClaimCompensateCode	ClaimHeader_id
FROM sss.dbo.ClaimCompensateGroup ccg
LEFT JOIN sss.dbo.ClaimCompensate cc
	ON ccg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
UNION 
SELECT t.ClaimHeaderGroup_id
	,t.ClaimHeader_id
FROM  sss.dbo.DB_ClaimHeaderGroupItem t
UNION  
SELECT 	 item.ClaimHeaderGroup_id
		,item.ClaimHeader_id
FROM ssspa.dbo.DB_ClaimHeaderGroupItem item
) rs
INNER JOIN ISC_SmileDoc.dbo.DocumentIndexData doc
	ON doc.DocumentIndexData = rs.ClaimHeader_id COLLATE DATABASE_DEFAULT

WHERE doc.DateAction > @CutOffDate AND doc.DateAction <= @D

--SELECT att.*
UPDATE att 
	SET att.S3IsUploaded = 1
FROM ISC_SmileDoc.dbo.Attachment att 
INNER JOIN ISC_SmileDoc.dbo.DocumentIndexData doc 
	ON doc.DocumentID = att.DocumentID
INNER JOIN #TmpClaimCodes tc 
	ON tc.ClaimHeader_id = doc.DocumentIndexData COLLATE DATABASE_DEFAULT
WHERE NOT EXISTS
(
	SELECT 
	1
	FROM [ISC_SmileDoc].[dbo].[ClaimDocument] claimdoc
	WHERE claimdoc.DocumentIndexData = doc.DocumentIndexData
)


INSERT INTO [ISC_SmileDoc].[dbo].[ClaimDocument] ( 
[DocumentId]
, [DocumentStatusId]
, [UpdatedDate]
, [DocumentIndexId]
, [DocumentIndexData]
, [ExtUpdatedDate]
, [IsActive]
, [CreatedDate]
, [DocumentListId]
, [DocumentListName]
, [DocumentTypeId]
, [DocumentTypeName] )
SELECT 
 doc.DocumentID
 ,2						DocumentStatusId
 ,@D					UpdatedDate
 ,doc.DocumentIndexID
 ,tc.ClaimHeader_id		DocumentIndexData
 ,@D					ExtUpdatedDate
 ,1						IsActive
 ,@D					CreatedDate
 ,NULL					DocumentListId
 ,NULL					DocumentListName
 ,NULL					DocumentTypeId
 ,NULL					DocumentTypeName
 FROM #TmpClaimCodes tc 
 INNER JOIN ISC_SmileDoc.dbo.DocumentIndexData doc 
	ON doc.DocumentIndexData = tc.ClaimHeader_id COLLATE DATABASE_DEFAULT
WHERE NOT EXISTS
(
	SELECT 
	1
	FROM [ISC_SmileDoc].[dbo].[ClaimDocument] claimdoc
	WHERE claimdoc.DocumentIndexData = doc.DocumentIndexData
)


IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;
IF OBJECT_ID('tempdb..#TmpClaimCodes') IS NOT NULL  DROP TABLE #TmpClaimCodes;