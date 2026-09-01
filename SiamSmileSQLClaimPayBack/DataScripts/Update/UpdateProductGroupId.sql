USE [ClaimPayBack]
GO

--SELECT *
UPDATE m
	SET m.ProductGroupId = u.CmPgId
FROM dbo.ClaimPayBackDetail m
INNER JOIN 
(
	SELECT
		cpbd.ClaimGroupCode
		,cpbd.ProductGroupId CpbdPgId
		,cm.ProductGroupId	 CmPgId
	FROM dbo.ClaimPayBackDetail cpbd
		LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			ON cm.ClaimHeaderGroupCode = cpbd.ClaimGroupCode
	WHERE cpbd.ProductGroupId = 11
) u
ON u.ClaimGroupCode = m.ClaimGroupCode
WHERE m.IsActive = 1