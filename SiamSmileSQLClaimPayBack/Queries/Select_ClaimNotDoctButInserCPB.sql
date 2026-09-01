SELECT TOP(6000)
  cpbxc.ClaimCode
  ,cpb.ClaimPayBackCode
  ,cpt.ClaimPayBackTransferCode
  ,cpts.ClaimPayBackTransferStatus
  ,cpb.CreatedDate
  ,cpgt.ClaimGroupType
FROM dbo.ClaimPayBackDetail cpbdt
LEFT JOIN dbo.ClaimPayBackXClaim cpbxc
  ON cpbxc.ClaimPayBackDetailId = cpbdt.ClaimPayBackDetailId
LEFT JOIN dbo.ClaimPayBack cpb 
  ON cpb.ClaimPayBackId = cpbdt.ClaimPayBackId
LEFT JOIN dbo.ClaimPayBackTransfer cpt 
  ON cpt.ClaimPayBackTransferId = cpb.ClaimPayBackTransferId
LEFT JOIN dbo.ClaimPayBackTransferStatus cpts
  ON cpts.ClaimPayBackTransferStatusId = cpt.ClaimPayBackTransferStatusId
LEFT JOIN dbo.ClaimGroupType cpgt 
  ON cpgt.ClaimGroupTypeId = cpb.ClaimGroupTypeId
WHERE cpbdt.IsActive = 1
AND cpb.IsActive = 1
AND cpb.ClaimGroupTypeId <> 7
AND cpbdt.CreatedDate > '2026-01-01'
AND NOT EXISTS 
(
  SELECT 
   1
  FROM ISC_SmileDoc.dbo.DocumentIndexData doc
  WHERE doc.DocumentIndexData = cpbxc.ClaimCode COLLATE DATABASE_DEFAULT
)
ORDER BY cpb.CreatedDate DESC