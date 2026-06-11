USE [ClaimMiscellaneous]
GO

DECLARE @Tmplst TABLE (ClaimHeaderGroupCode NVARCHAR(100));

INSERT INTO @Tmplst(ClaimHeaderGroupCode)
VALUES
('CHSPH88869060006'),('CHSPO88869060002'),('CHSPH88869060005')

SELECT
	doc.DocumentId
FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
	INNER JOIN @Tmplst tls
		ON tls.ClaimHeaderGroupCode = cm.ClaimHeaderGroupCode
	LEFT JOIN 
		(
			SELECT
				ClaimMiscId
				,DocumentId
			FROM [ClaimMiscellaneous].[misc].[Document] 
			WHERE IsActive = 1
				AND DocumentTypeId IN (2,4)
			UNION
			SELECT 
				ClaimMiscId
				,DocumentId
			FROM [ClaimMiscellaneous].[misc].[DocumentClaimOnLine]
			WHERE IsActive = 1
				AND DocumentSubTypeId IN (339,341)
		) doc
		ON doc.ClaimMiscId = cm.ClaimMiscId
WHERE cm.IsActive = 1