USE [ClaimPayBack]
GO

DECLARE @D DATETIME = GETDATE();
DECLARE @CutOffDate DATETIME = DATEADD(DAY,-2,@D);

SELECT 
    cpbxc.ClaimCode
    ,g.ClaimPayBackSubGroupCode,
    stat.ClaimPayBackSubGroupTransactionStatusName
FROM dbo.ClaimPayBackSubGroupTransaction sub
LEFT JOIN dbo.ClaimPayBackSubGroup g
    ON g.ClaimPayBackSubGroupId = sub.ClaimPayBackSubGroupId
LEFT JOIN dbo.ClaimPayBackSubGroupTransactionStatus stat
    ON stat.ClaimPayBackSubGroupTransactionStatusId = sub.ClaimPayBackSubGroupTransactionStatusId
LEFT JOIN dbo.ClaimPayBackTransfer cpt 
    ON cpt.ClaimPayBackTransferId = g.ClaimPayBackTransferId
LEFT JOIN dbo.ClaimPayBack cpg 
    ON cpg.ClaimPayBackTransferId = cpt.ClaimPayBackTransferId
LEFT JOIN dbo.ClaimPayBackDetail cpd 
    ON cpd.ClaimPayBackId = cpg.ClaimPayBackId
LEFT JOIN dbo.ClaimPayBackXClaim cpbxc
    ON cpbxc.ClaimPayBackDetailId = cpd.ClaimPayBackDetailId
WHERE sub.ClaimPayBackSubGroupTransactionStatusId IN (4,5,6)
AND sub.CreatedDate > @CutOffDate 
AND sub.CreatedDate <= @D

-- ต้องมี 5
AND EXISTS (
    SELECT 1
    FROM dbo.ClaimPayBackSubGroupTransaction s5
    WHERE s5.ClaimPayBackSubGroupId = sub.ClaimPayBackSubGroupId
    AND s5.ClaimPayBackSubGroupTransactionStatusId = 5
    AND s5.CreatedDate > @CutOffDate 
    AND s5.CreatedDate <= @D
)

-- และต้องมี 4 หรือ 6 อย่างน้อย 1
AND (
    EXISTS (
        SELECT 1
        FROM dbo.ClaimPayBackSubGroupTransaction s4
        WHERE s4.ClaimPayBackSubGroupId = sub.ClaimPayBackSubGroupId
        AND s4.ClaimPayBackSubGroupTransactionStatusId = 4
        AND s4.CreatedDate > @CutOffDate 
        AND s4.CreatedDate <= @D
    )
    OR
    EXISTS (
        SELECT 1
        FROM dbo.ClaimPayBackSubGroupTransaction s6
        WHERE s6.ClaimPayBackSubGroupId = sub.ClaimPayBackSubGroupId
        AND s6.ClaimPayBackSubGroupTransactionStatusId = 6
        AND s6.CreatedDate > @CutOffDate 
        AND s6.CreatedDate <= @D
    )
)

ORDER BY sub.ClaimPayBackSubGroupId;