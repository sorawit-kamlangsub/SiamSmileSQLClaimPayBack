DECLARE @DateFrom DATE = '2025-12-9';
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
					ON ctd.Application_id = cus.App_id AND cus.Status_id <> '3090' --ไม่ใช่ยกเลิกกรมธรรม์
				LEFT JOIN SSSPA.dbo.DB_CustomerPolicy  AS ctp
					ON cus.App_id  = ctp.App_id AND PolicyType_id = '9601' --เป็นเลขกรมธรรม์ ปกติ

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
	WHERE NOT EXISTS (

		SELECT 
			1
		FROM ISC_SmileDoc.dbo.DocumentIndexData dd WITH(NOLOCK)
			LEFT JOIN ISC_SmileDoc.dbo.Document d WITH(NOLOCK)
				ON dd.DocumentID = d.DocumentID
			LEFT JOIN 
			(
				SELECT
					DocumentListID
				FROM ISC_SmileDoc.dbo.DocumentList 
				WHERE DocumentTypeId IN (5,6)
			) dl
			ON d.DocumentListID = dl.DocumentListID
		WHERE dd.DocumentIndexData = td.ClaimHeaderCodeInDB COLLATE DATABASE_DEFAULT

	)
	AND NOT EXISTS (
	
		SELECT 1
		FROM ClaimPayBack.dbo.ClaimHeaderGroupImport H
		WHERE H.ClaimHeaderGroupCode = td.ClaimHeaderGroupCodeInDB
		  AND H.IsActive = 1
		  AND H.ClaimHeaderGroupImportStatusId <> 2
	)
	AND (td.TotalAmountSS > 0 OR td.TotalAmount > 0)
	AND td.ClaimHeaderGroupCodeInDB IS NOT NULL 
	AND td.CreatedDate >= @StartDateFrom
	AND td.CreatedDate < @EndDateTo

	ORDER BY ProductGroup 

SELECT
    IDENTITY(INT, 1, 1) AS RowNo,
    a.DocumentID,
    a.S3Key
INTO #Pool
FROM 
(
    SELECT TOP(1000)
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
				DocumentID INT
			);

			INSERT INTO ISC_SmileDoc.dbo.Document
			(
				DocumentListID
				,ProjectPermissionID
				,BranchID
				,DocumentDate
				,VoucherRef
				,IsEnable
				,DateAction
				,PersonIDAction
				,DocumentStatusID
				,DateStatus
				,PersonIDStatus
				,IPAddress
				,GUI
			)
			OUTPUT Inserted.DocumentID INTO @Document(DocumentID)
			SELECT 
				1	DocumentListID
				,1	ProjectPermissionID
				,90		BranchID
				,@D		DocumentDate
				,NULL	VoucherRef
				,1		IsEnable
				,@D		DateAction
				,1		PersonIDAction
				,2		DocumentStatusID
				,@D		DateStatus
				,1		PersonIDStatus
				,NULL	IPAddress
				,NULL	GUI
			FROM #Tmp

			SELECT
				t.RowNo,
				d.DocumentID
			INTO #Map
			FROM
			(
				SELECT 
					RowNo,
					ROW_NUMBER() OVER (ORDER BY RowNo) AS Seq
				FROM #Tmp
			) t
			INNER JOIN @Document d
				ON t.Seq = d.Seq;

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
				m.DocumentID              AS DocumentID
				,1                        AS DocumentIndexID
				,t.ClaimHeaderCodeInDB    AS DocumentIndexData
				,@D                       AS DateAction
				,1                        AS PersonIDAction
				,NULL                     AS IPAddress
			FROM #Tmp t
			INNER JOIN #Map m
				ON t.RowNo = m.RowNo;

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
				m.DocumentID     AS DocumentID         -- ใช้ DocumentID จาก #Map
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
			INNER JOIN #Tmp t
				ON p.RowNo = t.RowNo  
			INNER JOIN #Map m
				ON t.RowNo = m.RowNo;

		--Result--

		SELECT
			*
		FROM #Tmp

END TRY
BEGIN CATCH

	Print('บันทึก ไม่สำเร็จ');

	IF @@Trancount > 0 ROLLBACK;
END CATCH

IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;
IF OBJECT_ID('tempdb..#Pool') IS NOT NULL DROP TABLE #Pool;
IF OBJECT_ID('tempdb..#Map') IS NOT NULL DROP TABLE #Map;