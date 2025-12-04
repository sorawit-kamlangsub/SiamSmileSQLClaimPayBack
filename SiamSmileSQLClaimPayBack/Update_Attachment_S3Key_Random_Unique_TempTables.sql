/*

    สคริปต์อัปเดต S3Key แบบสุ่มไม่ซ้ำ

*/

----------------------------
-- 1) สร้าง temp table #Target
----------------------------


SELECT 
    IDENTITY(INT, 1, 1) AS RowNo,   
    a.DocumentID                   
INTO #Target
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
WHERE 
    a.S3IsUploaded IS NULL;   


----------------------------
-- 2) สร้าง temp table #Pool สำหรับ S3Key ที่สุ่มแล้ว
----------------------------


SELECT
    IDENTITY(INT, 1, 1) AS RowNo,  
    a.DocumentID,
    a.S3Key
INTO #Pool
FROM ISC_SmileDoc.dbo.Attachment a
WHERE 
    a.S3IsUploaded = 1
    AND a.S3Bucket = 'p-isc-ss-1-bucketdata'
    AND a.S3Key IS NOT NULL
    AND a.S3Key <> ''
ORDER BY 
    NEWID();   -- สุ่มลำดับ


----------------------------
-- 3) ถ้าจำนวน Target > Pool → ตัด RowNo เกินออก
----------------------------
DECLARE @PoolCount INT;
SELECT @PoolCount = COUNT(*) FROM #Pool;

DELETE FROM #Target
WHERE RowNo > @PoolCount;
-- ตอนนี้ #Target มีจำนวนแถว <= #Pool แน่นอน
-- ทำให้จับคู่ RowNo ได้ครบทุกแถว

--DEBUG ZONE


----------------------------
-- 4) UPDATE ด้วยคู่ RowNo ระหว่าง #Target กับ #Pool
----------------------------
--SELECT *
UPDATE a
SET 
    a.S3Key = p.S3Key,
    a.S3IsUploaded = 1,
    a.S3Bucket = 'p-isc-ss-1-bucketdata' 
FROM ISC_SmileDoc.dbo.Attachment a
    INNER JOIN #Target t 
        ON a.DocumentID = t.DocumentID
    INNER JOIN #Pool p
        ON t.RowNo = p.RowNo
WHERE 
    a.S3IsUploaded IS NULL;

IF OBJECT_ID('tempdb..#Target') IS NOT NULL DROP TABLE #Target;
IF OBJECT_ID('tempdb..#Pool') IS NOT NULL DROP TABLE #Pool;