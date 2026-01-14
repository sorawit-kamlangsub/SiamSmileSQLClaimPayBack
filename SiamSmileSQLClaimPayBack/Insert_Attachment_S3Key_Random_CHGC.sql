DECLARE @DateFrom DATE = '2025-1-1';
DECLARE @DateTo DATE = '2025-12-11';
DECLARE @StartDateFrom DATETIME2 = @DateFrom;
DECLARE @EndDateTo DATETIME2	= DATEADD(DAY, 1, @DateTo);
DECLARE @D DATETIME	= GETDATE()
DECLARE @S3Bucket NVARCHAR(255) = 'p-isc-ss-1-bucketdata'

		
	SELECT
		td.ClaimHeaderGroupCodeInDB
		,1 ItemCode
		,IIF(ISNULL(td.TotalAmount,0) = 0 ,td.TotalAmountSS,td.TotalAmount)	Amount
		,ISNULL(td.TotalAmount,0)	TotalAmount
		,ISNULL(td.TotalAmountSS,0)	TotalAmountSS
		,td.InsuranceCompanyId
		,td.ClaimHeaderCodeInDB
		,td.ProductGroup
		,td.PolicyNo
		,td.CreatedDate
		,IDENTITY(INT, 1, 1) AS RowNo
	INTO #Tmp
	FROM
		(	--SSS------
			SELECT h.ClaimHeaderGroup_id					AS ClaimHeaderGroupCodeInDB
					,CAST(v.Pay_Total AS DECIMAL(16,2))		AS TotalAmount
					,v.PaySS_Total							AS TotalAmountSS
					,ins.Organize_ID						AS InsuranceCompanyId
					,h.Code									AS ClaimHeaderCodeInDB
					,IIF(h.Product_id = 'P30',h.Product_id,'1000') AS ProductGroup
					,cus.InsuredPolicy_no					AS PolicyNo
					,h.CreatedDate
			FROM SSS.dbo.DB_ClaimHeader h
				LEFT JOIN SSS.dbo.DB_ClaimVoucher v
					ON h.Code = v.Code
				LEFT JOIN DataCenterV1.Organize.Organize ins
					ON h.InsuranceCompany_id = ins.OrganizeCode
				LEFT JOIN sss.dbo.MT_ClaimType ct
					ON h.ClaimAdmitType_id = ct.Code
				LEFT JOIN sss.dbo.DB_Customer  cus
					ON h.App_id = cus.App_id

			UNION
			--SSSPA------
			SELECT hg.Code								AS ClaimHeaderGroupCodeInDB
					,CAST(h.Amount_Pay AS DECIMAL(16,2))	AS TotalAmount
					,h.PaySS_Total							AS TotalAmountSS
					,ins.Organize_ID						AS InsuranceCompanyId
					,h.Code									AS ClaimHeaderCodeInDB
					,'2000'									AS ProductGroup
					,ctp.Detail								AS PolicyNo
					,hg.CreatedDate
			FROM SSSPA.dbo.DB_ClaimHeaderGroup AS hg
				LEFT JOIN SSSPA.dbo.DB_ClaimHeader h
					ON hg.Code = h.ClaimheaderGroup_id
				LEFT JOIN DataCenterV1.Organize.Organize AS ins
					ON hg.InsuranceCompany_id = ins.OrganizeCode
				LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS ctd
					ON h.CustomerDetail_id = ctd.Code
				LEFT JOIN SSSPA.dbo.DB_Customer AS cus
					ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090' 
				LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
					ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601' 

			UNION

			--ClaimCompensate------
			SELECT cg.ClaimCompensateGroupCode				AS ClaimHeaderGroupCodeInDB
				,cc.CompensateRemain						AS TotalAmount
				,cc.CompensateRemain						AS TotalAmountSS
				,ins.Organize_ID							AS InsuranceCompanyId
				,cc.ClaimCompensateCode						AS ClaimHeaderCodeInDB
				,'2222'										AS ProductGroup
				,cus.InsuredPolicy_no						AS PolicyNo
				,cg.CreatedDate
			FROM SSS.dbo.ClaimCompensateGroup cg
				LEFT JOIN
					(
						SELECT 
							CompensateRemain
							,ClaimCompensateCode
							,ClaimCompensateGroupId
						FROM SSS.dbo.ClaimCompensate
						WHERE IsActive = 1
					)cc
					ON cg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
				LEFT JOIN DataCenterV1.Organize.Organize AS ins
					ON cg.InsuranceCompanyCode = ins.OrganizeCode
				LEFT JOIN SSS.dbo.DB_ClaimHeader h
					ON cg.ClaimCompensateGroupCode = h.ClaimHeaderGroup_id
				LEFT JOIN sss.dbo.DB_Customer  cus
					ON h.App_id = cus.App_id

	) td	
	-- WHERE td.ClaimHeaderGroupCodeInDB IN
	WHERE td.ClaimHeaderCodeInDB IN
	(

		'CL6901000047'
	)

	ORDER BY ProductGroup 

SELECT
    IDENTITY(INT, 1, 1) AS RowNo,
    a.DocumentID,
    a.S3Key
INTO #Pool
FROM 
(
    SELECT TOP(3000)
        MIN(DocumentID) AS DocumentID,  
        S3Key
    FROM ISC_SmileDoc.dbo.Attachment
    WHERE 
        S3IsUploaded = 1
        AND S3Bucket = @S3Bucket
        AND S3Key IS NOT NULL
        AND S3Key <> ''
    GROUP BY 
        S3Key  
) a
ORDER BY 
    NEWID(); 

DECLARE @PoolCount INT;
SELECT @PoolCount = COUNT(*) FROM #Pool;

DELETE FROM #Tmp
WHERE RowNo > @PoolCount;


BEGIN TRY
	Begin TRANSACTION
		COMMIT TRANSACTION

			DECLARE @Document TABLE
			(
				Seq        INT IDENTITY(1,1),
				DocumentID INT,
				DocumentListID INT
			);

			INSERT INTO ISC_SmileDoc.dbo.Document
			(
				DocumentListID,
				ProjectPermissionID,
				BranchID,
				DocumentDate,
				VoucherRef,
				IsEnable,
				DateAction,
				PersonIDAction,
				DocumentStatusID,
				DateStatus,
				PersonIDStatus,
				IPAddress,
				GUI
			)
			OUTPUT 
				Inserted.DocumentID, 
				Inserted.DocumentListID  
			INTO @Document(DocumentID, DocumentListID)
			SELECT 
				26                          AS DocumentListID,
				1                           AS ProjectPermissionID,
				90                          AS BranchID,
				@D                          AS DocumentDate,
				NULL                        AS VoucherRef,
				1                           AS IsEnable,
				@D                          AS DateAction,
				1                           AS PersonIDAction,
				2                           AS DocumentStatusID,
				@D                          AS DateStatus,
				1                           AS PersonIDStatus,
				NULL                        AS IPAddress,
				NULL                        AS GUI
			FROM #Tmp

			UNION ALL

			SELECT
				135                         AS DocumentListID,
				1                           AS ProjectPermissionID,
				90                          AS BranchID,
				@D                          AS DocumentDate,
				NULL                        AS VoucherRef,
				1                           AS IsEnable,
				@D                          AS DateAction,
				1                           AS PersonIDAction,
				2                           AS DocumentStatusID,
				@D                          AS DateStatus,
				1                           AS PersonIDStatus,
				NULL                        AS IPAddress,
				NULL                        AS GUI
			FROM #Tmp;

			INSERT INTO ISC_SmileDoc.dbo.DocumentIndexData
			(
				DocumentID
				,DocumentIndexID
				,DocumentIndexData
				,DateAction
				,PersonIDAction
				,IPAddress
			)
			SELECT
				d.DocumentID              AS DocumentID
				,1                        AS DocumentIndexID
				,t.ClaimHeaderCodeInDB    AS DocumentIndexData
				,@D                       AS DateAction
				,1                        AS PersonIDAction
				,NULL                     AS IPAddress
			FROM
			(
				SELECT 
					ClaimHeaderCodeInDB,
					ROW_NUMBER() OVER (ORDER BY ClaimHeaderCodeInDB) AS Seq
				FROM #Tmp
			) t
			INNER JOIN
			(
				SELECT 
					DocumentID,
					ROW_NUMBER() OVER (PARTITION BY DocumentListID ORDER BY DocumentID) AS Seq
				FROM @Document
			) d
				ON t.Seq = d.Seq;

			INSERT INTO ISC_SmileDoc.dbo.Attachment
			(
				DocumentID
				,AttachmentName
				,AttachmentURL
				,AttachmentSortOrder
				,IsEnable
				,DateAction
				,PersonIDAction
				,IPAddress
				,S3IsUploaded
				,S3UploadedDate
				,S3Bucket
				,S3Key
				,S3StorageType
				,S3StorageTypeUpdateDate
				,IsDelete
				,IsLocalFileDeleted
				,LocalFileDeletedDate
			)
			SELECT
				d.DocumentID     AS DocumentID         
				,NULL            AS AttachmentName
				,NULL            AS AttachmentURL
				,1               AS AttachmentSortOrder
				,1               AS IsEnable
				,@D              AS DateAction
				,1               AS PersonIDAction
				,NULL            AS IPAddress
				,1               AS S3IsUploaded
				,@D              AS S3UploadedDate
				,@S3Bucket       AS S3Bucket
				,p.S3Key         AS S3Key
				,NULL            AS S3StorageType
				,NULL            AS S3StorageTypeUpdateDate
				,NULL            AS IsDelete
				,NULL            AS IsLocalFileDeleted
				,NULL            AS LocalFileDeletedDate
			FROM #Pool p
			INNER JOIN
			(
				SELECT 
					RowNo,
					ClaimHeaderCodeInDB,
					ROW_NUMBER() OVER (ORDER BY ClaimHeaderCodeInDB) AS Seq
				FROM #Tmp
			) t
				ON p.RowNo = t.RowNo
			INNER JOIN
			(
				SELECT 
					DocumentID,
					ROW_NUMBER() OVER (PARTITION BY DocumentListID ORDER BY DocumentID) AS Seq
				FROM @Document
			) d
				ON t.Seq = d.Seq;

			SELECT
			 *
			FROM @Document

END TRY
BEGIN CATCH

	Print('Success');

	IF @@Trancount > 0 ROLLBACK;
END CATCH

	--Result--

	SELECT
		*
	FROM #Tmp



IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;
IF OBJECT_ID('tempdb..#Pool') IS NOT NULL DROP TABLE #Pool;