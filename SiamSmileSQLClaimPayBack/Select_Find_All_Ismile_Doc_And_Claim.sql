SELECT tbi.ClaimCode,
       a.S3IsUploaded,
       a.S3Bucket,
       a.S3Key
FROM ISC_SmileDoc.dbo.DocumentIndexData did
    LEFT JOIN ISC_SmileDoc.dbo.Document d
        ON did.DocumentID = d.DocumentID
    LEFT JOIN ISC_SmileDoc.dbo.Attachment a
        ON d.DocumentID = a.DocumentID
    INNER JOIN
    (    
        SELECT chid.ClaimHeaderGroupImportDetailId,
               chid.ClaimCode
        FROM ClaimPayBack.dbo.BillingRequestItem bqi
            LEFT JOIN ClaimPayBack.dbo.ClaimHeaderGroupImportDetail chid
                ON bqi.ClaimHeaderGroupImportDetailId = chid.ClaimHeaderGroupImportDetailId  
    ) tbi
        ON did.DocumentIndexData = tbi.ClaimCode COLLATE DATABASE_DEFAULT
-- WHERE 
-- a.S3IsUploaded = 1
-- AND a.S3Key IS NOT NULL
-- AND a.S3Key <> ''

WHERE 
a.S3IsUploaded IS NULL