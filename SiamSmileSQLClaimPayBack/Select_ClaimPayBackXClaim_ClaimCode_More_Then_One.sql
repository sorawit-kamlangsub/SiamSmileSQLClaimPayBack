SELECT TOP(100)
    cpbxc.ClaimCode,
    cpb.ClaimPayBackTransferId,
    cpb.ClaimPayBackCode,
    cpb.CreatedDate,
    COUNT(*) AS TotalRows
FROM [ClaimPayBack].[dbo].[ClaimPayBackXClaim] cpbxc
    LEFT JOIN [ClaimPayBack].[dbo].[ClaimPayBackDetail] cpbd
        ON cpbd.ClaimPayBackDetailId = cpbxc.ClaimPayBackDetailId
    LEFT JOIN [ClaimPayBack].[dbo].[ClaimPayBack] cpb
        ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
WHERE cpbxc.IsActive = 1
AND cpb.ClaimGroupTypeId = 5
GROUP BY cpbxc.ClaimCode,cpb.ClaimPayBackTransferId,cpb.ClaimPayBackCode,cpb.CreatedDate
HAVING COUNT(*) > 1
ORDER BY TotalRows DESC;