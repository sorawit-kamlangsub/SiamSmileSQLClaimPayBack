
DECLARE @ClaimGroupCode NVARCHAR(100) = 'SEHN-222-66110002-0'

SELECT 
    cpbd.ClaimPayBackDetailId
    ,cpb.ClaimPayBackId
    ,cpt.ClaimPayBackTransferId
INTO #Tmp
FROM [ClaimPayBack].[dbo].[ClaimPayBackDetail] cpbd
LEFT JOIN [ClaimPayBack].[dbo].[ClaimPayBackXClaim] cpbxc
    ON cpbxc.ClaimPayBackDetailId = cpbd.ClaimPayBackDetailId
LEFT JOIN [ClaimPayBack].[dbo].[ClaimPayBack] cpb
    ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
LEFT JOIN [ClaimPayBack].[dbo].[ClaimPayBackTransfer] cpt
    ON cpt.ClaimPayBackTransferId = cpb.ClaimPayBackTransferId
WHERE cpbd.ClaimGroupCode = @ClaimGroupCode

SELECT 
    *
  FROM [ClaimPayBack].[dbo].[ClaimPayBackDetail] cpbd
  INNER JOIN #Tmp t
    ON t.ClaimPayBackDetailId = cpbd.ClaimPayBackDetailId

SELECT 
    *
  FROM [ClaimPayBack].[dbo].[ClaimPayBackXClaim] cpbxc
  INNER JOIN #Tmp t
    ON t.ClaimPayBackDetailId = cpbxc.ClaimPayBackDetailId

SELECT 
    *
  FROM [ClaimPayBack].[dbo].[ClaimPayBack] cpb
  INNER JOIN #Tmp t
    ON t.ClaimPayBackId = cpb.ClaimPayBackId

SELECT 
    *
  FROM [ClaimPayBack].[dbo].[ClaimPayBackTransfer] cpt
  INNER JOIN #Tmp t
    ON t.ClaimPayBackTransferId = cpt.ClaimPayBackTransferId


IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;