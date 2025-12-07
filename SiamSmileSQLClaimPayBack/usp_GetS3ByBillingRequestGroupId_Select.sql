USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_GetS3ByBillingRequestGroupId_Select]    Script Date: 4/12/2568 10:16:19 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sahatsawat golffy 06958
-- Create date: 2023-08-09
-- Update date: 2024-01-26 --·°È‰¢‡§≈¡‚Õπ·¬°‰¡Ë¡’ Document Link
-- Description:	Use for get DocumentLink in AWSS3Client
-- =============================================
ALTER PROCEDURE [dbo].[usp_GetS3ByBillingRequestGroupId_Select]
    -- Add the parameters for the stored procedure here
    @BillingRequestGroupId INT,
    @BillingRequestGroupListId VARCHAR(MAX),
    @IsCheck INT
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    DECLARE @ClaimHeaderGroupType INT;
    SELECT @ClaimHeaderGroupType = ClaimHeaderGroupTypeId
    FROM dbo.BillingRequestGroup
    WHERE BillingRequestGroupId = @BillingRequestGroupId;
    -- Ischeck 1 Export Excel or SFTP // Ischeck 2 Generate Group for insert to BillingExport
    IF (@IsCheck = 1)
    BEGIN
        -- Insert statements for procedure here
        SELECT chid.ClaimHeaderGroupImportDetailId,
               chid.ClaimCode,
               cs.ClaimCompensateCode
        INTO #TmpBillingItem1
        FROM ClaimPayBack.dbo.BillingRequestItem bqi
            LEFT JOIN ClaimPayBack.dbo.ClaimHeaderGroupImportDetail chid
                ON bqi.ClaimHeaderGroupImportDetailId = chid.ClaimHeaderGroupImportDetailId
            LEFT JOIN SSS.dbo.ClaimCompensate cs
                ON chid.ClaimCode = cs.ClaimHeaderCode
        WHERE bqi.BillingRequestGroupId = @BillingRequestGroupId;

        IF @ClaimHeaderGroupType = 4
        BEGIN
            SELECT tbi.ClaimCode,
                   a.S3Bucket,
                   a.S3Key
            FROM ISC_SmileDoc.dbo.DocumentIndexData did
                INNER JOIN #TmpBillingItem1 tbi
                    ON did.DocumentIndexData = tbi.ClaimCompensateCode COLLATE DATABASE_DEFAULT
                LEFT JOIN ISC_SmileDoc.dbo.Document d
                    ON did.DocumentID = d.DocumentID
                LEFT JOIN ISC_SmileDoc.dbo.Attachment a
                    ON d.DocumentID = a.DocumentID
            WHERE a.S3IsUploaded = 1
                  AND a.S3Key IS NOT NULL
                  AND a.S3Key <> '';
        END;
        ELSE
        BEGIN
            SELECT tbi.ClaimCode,
                   a.S3Bucket,
                   a.S3Key
            FROM ISC_SmileDoc.dbo.DocumentIndexData did
                INNER JOIN #TmpBillingItem1 tbi
                    ON did.DocumentIndexData = tbi.ClaimCode COLLATE DATABASE_DEFAULT
                LEFT JOIN ISC_SmileDoc.dbo.Document d
                    ON did.DocumentID = d.DocumentID
                LEFT JOIN ISC_SmileDoc.dbo.Attachment a
                    ON d.DocumentID = a.DocumentID
            WHERE a.S3IsUploaded = 1
                  AND a.S3Key IS NOT NULL
                  AND a.S3Key <> '';
        END;
    END;
    ELSE
    BEGIN
        --	SELECT chid.ClaimHeaderGroupImportDetailId
        --			 , chid.ClaimCode
        --			 ,bqi.BillingRequestGroupId
        --	INTO #TmpBillingItem2
        --	FROM ClaimPayBack.dbo.BillingRequestItem bqi
        --		LEFT JOIN ClaimPayBack.dbo.ClaimHeaderGroupImportDetail chid
        --				ON bqi.ClaimHeaderGroupImportDetailId = chid.ClaimHeaderGroupImportDetailId
        --		INNER JOIN dbo.func_SplitStringToTable(@BillingRequestGroupListId,',') as brgli
        --				ON ( bqi.BillingRequestGroupId = brgli.Element OR brgli.Element is null)
        --SELECT tbi.ClaimCode
        --		, a.S3Bucket
        --		, a.S3Key
        --FROM ISC_SmileDoc.dbo.DocumentIndexData did
        --	INNER JOIN #TmpBillingItem2 tbi
        --		ON did.DocumentIndexData = tbi.ClaimCode COLLATE DATABASE_DEFAULT
        --	LEFT JOIN ISC_SmileDoc.dbo.Document d
        --		ON did.DocumentID = d.DocumentID
        --	LEFT JOIN ISC_SmileDoc.dbo.Attachment a
        --		ON d.DocumentID = a.DocumentID
        --WHERE a.S3IsUploaded = 1
        --		AND a.S3Key IS NOT NULL
        --		AND a.S3Key <> ''

        ---------------------------------------------------
        SELECT chid.ClaimHeaderGroupImportDetailId,
               chid.ClaimCode,
               bqi.BillingRequestGroupId,
               cs.ClaimCompensateCode
        INTO #TmpBillingItem2
        FROM ClaimPayBack.dbo.BillingRequestItem bqi
            LEFT JOIN ClaimPayBack.dbo.ClaimHeaderGroupImportDetail chid
                ON bqi.ClaimHeaderGroupImportDetailId = chid.ClaimHeaderGroupImportDetailId
            LEFT JOIN SSS.dbo.ClaimCompensate cs
                ON chid.ClaimCode = cs.ClaimHeaderCode
            INNER JOIN dbo.func_SplitStringToTable(@BillingRequestGroupListId, ',') AS brgli
                ON (
                       bqi.BillingRequestGroupId = brgli.Element
                       OR brgli.Element IS NULL
                   );

        IF @ClaimHeaderGroupType = 4
        BEGIN
            SELECT tbi.ClaimCode,
                   a.S3Bucket,
                   a.S3Key
            FROM ISC_SmileDoc.dbo.DocumentIndexData did
                INNER JOIN #TmpBillingItem2 tbi
                    ON did.DocumentIndexData = tbi.ClaimCompensateCode COLLATE DATABASE_DEFAULT
                LEFT JOIN ISC_SmileDoc.dbo.Document d
                    ON did.DocumentID = d.DocumentID
                LEFT JOIN ISC_SmileDoc.dbo.Attachment a
                    ON d.DocumentID = a.DocumentID
            WHERE a.S3IsUploaded = 1
                  AND a.S3Key IS NOT NULL
                  AND a.S3Key <> '';
        END;
        ELSE
        BEGIN
            SELECT tbi.ClaimCode,
                   a.S3Bucket,
                   a.S3Key
            FROM ISC_SmileDoc.dbo.DocumentIndexData did
                INNER JOIN #TmpBillingItem2 tbi
                    ON did.DocumentIndexData = tbi.ClaimCode COLLATE DATABASE_DEFAULT
                LEFT JOIN ISC_SmileDoc.dbo.Document d
                    ON did.DocumentID = d.DocumentID
                LEFT JOIN ISC_SmileDoc.dbo.Attachment a
                    ON d.DocumentID = a.DocumentID
            WHERE a.S3IsUploaded = 1
                  AND a.S3Key IS NOT NULL
                  AND a.S3Key <> '';
        END;
    ---------------------------------------------------
    END;



---------Mock data------------------------
--SELECT TOP 1 'CLS6612000598' AS ClaimCode
--	, 'p-isc-ss-1-bucketdata' as S3Bucket
--	, 'SmileDoc/2567/5/143/1/DocumentID5326516_{11_1_2567_9-45-56}_{01926}Upload.pdf' AS S3Key
--FROM ISC_SmileDoc.dbo.DocumentIndexData did

----INNER JOIN #TmpBillingItem2 tbi
----	ON did.DocumentIndexData = tbi.ClaimCode COLLATE DATABASE_DEFAULT

--LEFT JOIN ISC_SmileDoc.dbo.Document d
--	ON did.DocumentID = d.DocumentID
--LEFT JOIN ISC_SmileDoc.dbo.Attachment a
--	ON d.DocumentID = a.DocumentID
--WHERE a.S3IsUploaded = 1
--	AND a.S3Key IS NOT NULL
--	AND a.S3Key <> ''

END;
---------Mock data------------------------

IF OBJECT_ID('tempdb..#TmpBillingItem1') IS NOT NULL
    DROP TABLE #TmpBillingItem1;
IF OBJECT_ID('tempdb..#TmpBillingItem2') IS NOT NULL
    DROP TABLE #TmpBillingItem2;

--SELECT 
--'' AS ClaimCode,
--'' AS S3Bucket,
--'' AS S3Key

--END
