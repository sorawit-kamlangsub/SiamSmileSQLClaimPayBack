USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_Report_ClaimPayBackTransferAll_Select]    Script Date: 22/4/2569 13:19:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sahatsawat golffy 06958
-- Create date: 20231221
-- Update date: 20240111 Kittisak.Ph เปลี่ยนฟิลด์ดึงข้อมูลธนาคาร
-- Description:
-- =============================================
ALTER PROCEDURE [dbo].[usp_Report_ClaimPayBackTransferAll_Select]
	-- Add the parameters for the stored procedure here
	@SearchTypeId		INT 
	,@DateFrom			DATE 
	,@DateTo			DATE 
	,@InsuranceId		INT = NULL
	,@ProductGroupId	INT = NULL
	,@BranchId			INT = NULL	
	,@ClaimGroupTypeId	INT = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	
	DECLARE @_SearchTypeId		INT = @SearchTypeId
	DECLARE @_DateFrom			DATE = @DateFrom
	DECLARE @_DateTo			DATE  =@DateTo
	DECLARE @_InsuranceId		INT = @InsuranceId
	DECLARE @_ProductGroupId	INT = @ProductGroupId
	DECLARE @_BranchId			INT = @BranchId	
	DECLARE @_ClaimGroupTypeId	INT = @ClaimGroupTypeId
    -- Insert statements for procedure here
	
	IF @_DateTo IS NOT NULL SET @_DateTo = DATEADD(DAY,1,@_DateTo);

	-------------------------------------------------------

	--SearchType 1 วันที่ส่งตั้งเบิก ,2 วันที่การเงิน โอนเงิน

	DECLARE @TmpDetail TABLE (
					ClaimPayBackDetailId INT
					 ,ClaimPayBackDetailCode VARCHAR(20)
					 ,ClaimPayBackId INT
					 ,BranchId INT
					 ,Branch NVARCHAR(100)  --xxxx
					 ,Area NVARCHAR(200) --xxxx
					 ,ClaimGroupCode NVARCHAR(250) --xxxx
					 ,ClaimOnLineCode NVARCHAR(100)
					 ,ItemCount INT --xxxx only claimhos
					 ,Amount DECIMAL(16, 2) --xxxx
					 ,ClaimGroupType NVARCHAR(200) --xxxx
					 ,ProductGroupId INT
					 ,ProductGroupDetail NVARCHAR(255) --xxxx
					 ,InsuranceCompanyId INT
					 ,InsuranceCompany NVARCHAR(300) --xxxx
					 ,empClaimOnLineApprove NVARCHAR(200)
					 ,TransferDate DATETIME --xxxx
					 ,IsActive BIT	
					 ,CreatedByUserId INT
					 ,CreatedDate DATETIME --xxxx
					 ,TransferUpdatedDate DATETIME
					 ,UpdatedByUserId INT
					 ,UpdatedDate DATETIME
					 ---ClaimHospital
					 ,HospitalProvince NVARCHAR(100)
					 ,HospitalName NVARCHAR(300)
					 --ClaimCompensate
					 ,ClaimCompensateCode VARCHAR(20)
					 ,ClaimCode VARCHAR(20)
					 ,CustName NVARCHAR(200)
					 --All
					 ,Bank NVARCHAR(200)
					 ,BankAccountName NVARCHAR(max)
					 ,BankAccountNo NVARCHAR(20)
					 ,empClaimApproved NVARCHAR(200)
					 ,empClaimPayBackCreated NVARCHAR(200)
					 ,PhoneNo VARCHAR(10)
				);


	IF @_ClaimGroupTypeId IN(2,3) --เคลมออนไลน์,เคลมสาขา
	BEGIN
		INSERT INTO @TmpDetail
		(
			ClaimPayBackDetailId,
			ClaimPayBackDetailCode,
			ClaimPayBackId,
			BranchId,
			Branch,
			Area,
			ClaimGroupCode,
			ClaimOnLineCode,
			ItemCount,
			Amount,
			ClaimGroupType,
			ProductGroupId,
			ProductGroupDetail,
			InsuranceCompanyId,
			InsuranceCompany,
			empClaimOnLineApprove,
			TransferDate,
			IsActive,
			CreatedByUserId,
			CreatedDate,
			TransferUpdatedDate,
			UpdatedByUserId,
			UpdatedDate,
			HospitalProvince,
			HospitalName,
			ClaimCompensateCode,
			ClaimCode,
			CustName,
			Bank,
			BankAccountName,
			BankAccountNo,
			empClaimApproved,
			empClaimPayBackCreated,
			PhoneNo
		)
		SELECT d.ClaimPayBackDetailId
			  ,d.ClaimPayBackDetailCode
			  ,d.ClaimPayBackId
			  ,b.BranchId
			  ,brh.BranchDetail				Branch
			  ,area.AreaDetail				Area
			  ,d.ClaimGroupCode
			  ,d.ClaimOnLineCode
			  ,d.ItemCount
			  ,d.Amount
			  ,cg_t.ClaimGroupType
			  ,d.ProductGroupId
			  ,pg.ProductGroupDetail
			  ,d.InsuranceCompanyId
			  ,x.InsuranceCompany_Name		InsuranceCompany	--Kittisak.Ph 20230703
			  --,CONCAT(pu.EmployeeCode, ' - ', pu.FirstName,' ',pu.LastName)	  AS empClaimOnLineApprove -- update 2023-06-26 Chanadol
			  ,'' AS empClaimOnLineApprove
			  ,t.TransferDate
			  ,d.IsActive
			  ,d.CreatedByUserId
			  ,d.CreatedDate
			  ,t.UpdatedDate			TransferUpdatedDate
			  ,d.UpdatedByUserId
			  ,d.UpdatedDate 
			  ,NULL
			  ,NULL
			  ,NULL
			  ,NULL
			  ,NULL
			  ,NULL
			  ,NULL
			  ,NULL
			  ,NULL
			  ,NULL
			  ,NULL
		FROM dbo.ClaimPayBackDetail d
			INNER JOIN dbo.ClaimPayBack b
				ON d.ClaimPayBackId = b.ClaimPayBackId
			LEFT JOIN dbo.ClaimPayBackTransfer t
				ON b.ClaimPayBackTransferId = t.ClaimPayBackTransferId
			LEFT JOIN DataCenterV1.Address.Branch brh
				ON b.BranchId = brh.Branch_ID
			LEFT JOIN DataCenterV1.Address.Area area
				ON brh.Area_ID = area.Area_ID
			LEFT JOIN dbo.ClaimGroupType cg_t
				ON b.ClaimGroupTypeId = cg_t.ClaimGroupTypeId
			LEFT JOIN DataCenterV1.Product.ProductGroup pg
				ON d.ProductGroupId = pg.ProductGroup_ID
			LEFT JOIN -- --Kittisak.Ph 20230703
							(
								SELECT Code AS Code
									, InsuranceCompany_Name
								FROM sss.dbo.DB_ClaimHeaderGroup
								UNION
								SELECT Code
									, InsuranceCompany_Name
								FROM SSSPA.dbo.DB_ClaimHeaderGroup
							) x
			ON d.ClaimGroupCode = x.Code

			-- update 2023-06-26 Chanadol
			--LEFT JOIN ClaimOnLine.dbo.ClaimOnLine c
			--	ON c.ClaimOnLineCode = d.ClaimOnLineCode
			--LEFT JOIN DataCenterV1.Person.vw_PersonUser pu
			--	ON c.TransferFirstPersonId = pu.UserId
		WHERE ((@_SearchTypeId = 1 AND (d.CreatedDate >= @_DateFrom AND d.CreatedDate < @_DateTo))
			  OR (@_SearchTypeId = 2 AND (t.TransferDate >= @_DateFrom AND t.TransferDate < @_DateTo)))
		AND (d.ProductGroupId = @_ProductGroupId OR @_ProductGroupId IS NULL)
		AND (b.ClaimGroupTypeId = @_ClaimGroupTypeId OR @_ClaimGroupTypeId IS NULL)
		AND (d.InsuranceCompanyId = @_InsuranceId OR @_InsuranceId IS NULL)
		AND (b.BranchId = @_BranchId OR @_BranchId IS NULL)
		AND d.IsActive = 1
	END
	ELSE
	IF @_ClaimGroupTypeId = 5 --เคลมโอนแยก
	BEGIN

		SELECT brh.BranchDetail					Branch
				,d.ClaimGroupCode
				,d.Amount
				,cg_t.ClaimGroupType
				,pg.ProductGroupDetail
				,x.InsuranceCompany_Name		InsuranceCompany	--Kittisak.Ph 20230703
				,t.TransferDate
				,d.CreatedDate
				,cs.ClaimCompensateCode
				,cs.ClaimHeaderCode				ClaimCode
				,tcust.Detail + dc.FirstName + ' ' + dc.LastName as CustName
				,CASE WHEN BankCodeTransfer IS NOT NULL THEN mb.Detail ELSE mtb.Detail END AS Bank  --Update 2024-01-11 Kittisak.Ph
				,CASE WHEN cs.BankAccountNameTransfer IS NOT NULL THEN cs.BankAccountNameTransfer
				  ELSE 
				  CASE 
							WHEN PATINDEX('%[0-9]%', cs.Remark) > 0
								THEN LEFT(cs.Remark, PATINDEX('%[0-9]%', cs.Remark) - 1)
								ELSE cs.Remark end
					END AS BankAccountName
					,CASE WHEN cs.BankAccountNoTransfer IS NOT NULL THEN cs.BankAccountNoTransfer
					ELSE 
					CASE 
							WHEN PATINDEX('%[0-9]%', cs.Remark) > 0
								THEN SUBSTRING(cs.Remark, PATINDEX('%[0-9]%', cs.Remark), LEN(cs.Remark))
								ELSE cs.Remark end
					END AS BankAccountNo
				--,mb.Detail						Bank
				--,cs.BankAccountNameTransfer    BankAccountName					--Update Chanadol 2023-12-22
				--,cs.BankAccountNoTransfer	   BankAccountNo
				--,CASE 
				--WHEN PATINDEX('%[0-9]%', cs.Remark) > 0
				--	THEN LEFT(cs.Remark, PATINDEX('%[0-9]%', cs.Remark) - 1)
				--	ELSE cs.Remark
				--END AS BankAccountName
				--,CASE 
				--WHEN PATINDEX('%[0-9]%', cs.Remark) > 0
				--	THEN SUBSTRING(cs.Remark, PATINDEX('%[0-9]%', cs.Remark), LEN(cs.Remark))
				--	ELSE cs.Remark
				--END AS BankAccountNo  --Update 2023-12-14 Chanadol
				--,cs.BankAccountNo
				,empa.PersonName empClaimApproved
				,empc.PersonName empClaimPayBackCreated
				,cs.PhoneNo
		INTO #TmpDetail2
		FROM dbo.ClaimPayBackDetail d
			INNER JOIN dbo.ClaimPayBack b
				ON d.ClaimPayBackId = b.ClaimPayBackId
			LEFT JOIN dbo.ClaimPayBackTransfer t
				ON b.ClaimPayBackTransferId = t.ClaimPayBackTransferId
			LEFT JOIN DataCenterV1.Address.Branch brh
				ON b.BranchId = brh.Branch_ID
			LEFT JOIN dbo.ClaimGroupType cg_t
				ON b.ClaimGroupTypeId = cg_t.ClaimGroupTypeId
			LEFT JOIN DataCenterV1.Product.ProductGroup pg
				ON d.ProductGroupId = pg.ProductGroup_ID
			LEFT JOIN 
							(
								SELECT ClaimCompensateGroupId
									, ClaimCompensateGroupCode Code
									, InsuranceCompany_Name
									,CreatedByCode
								FROM sss.dbo.ClaimCompensateGroup		
							) x
			ON d.ClaimGroupCode = x.Code
			LEFT JOIN 
				(
					SELECT	
									ClaimCompensateGroupId
									,ClaimHeaderCode
									,BankCodeTransfer
									,BankCode
									,ClaimCompensateCode
									,PhoneNo 
									,BankAccountNameTransfer
									,Remark
									,BankAccountNoTransfer
					FROM sss.dbo.ClaimCompensate
					WHERE IsActive = 1				
				) cs
				ON x.ClaimCompensateGroupId = cs.ClaimCompensateGroupId
			LEFT JOIN sss.dbo.DB_ClaimHeader ch
				ON cs.ClaimHeaderCode = ch.Code
			LEFT JOIN 
				(
					SELECT pu.User_ID
						,em.EmployeeCode
						,CONCAT(em.EmployeeCode, ' ', ps.FirstName , ' ' , ps.LastName) PersonName
					FROM DataCenterV1.Person.PersonUser pu
					INNER JOIN DataCenterV1.Person.Person ps
						ON pu.Person_ID = ps.Person_ID
					INNER JOIN DataCenterV1.Employee.Employee em
						ON pu.Employee_ID = em.Employee_ID
					WHERE pu.IsActive = 1
				)empa
			ON x.CreatedByCode = empa.EmployeeCode
			LEFT JOIN 
				(
					SELECT pu.User_ID
						,em.EmployeeCode
						,CONCAT(em.EmployeeCode, ' ', ps.FirstName , ' ' , ps.LastName) PersonName
					FROM DataCenterV1.Person.PersonUser pu
					INNER JOIN DataCenterV1.Person.Person ps
						ON pu.Person_ID = ps.Person_ID
					INNER JOIN DataCenterV1.Employee.Employee em
						ON pu.Employee_ID = em.Employee_ID
					WHERE pu.IsActive = 1
				)empc
			ON d.CreatedByUserId = empc.User_ID
			LEFT JOIN sss.dbo.MT_Bank mb
				ON cs.BankCodeTransfer = mb.Code --Update 2023-12-22 Chanadol
				LEFT JOIN sss.dbo.MT_Bank mtb ON cs.BankCode = mtb.Code  --Update 2024-01-11 Kittisak.Ph
			LEFT JOIN SSS.dbo.DB_Customer dc
				ON ch.App_id = dc.App_id
			INNER JOIN sss.dbo.MT_Title tcust
					ON dc.Title_id = tcust.Code
		WHERE ((@_SearchTypeId = 1 AND (d.CreatedDate >= @_DateFrom AND d.CreatedDate < @_DateTo))
					  OR (@_SearchTypeId = 2 AND (t.TransferDate >= @_DateFrom AND t.TransferDate < @_DateTo)))
				AND (d.ProductGroupId = @_ProductGroupId OR @_ProductGroupId IS NULL)
				AND (b.ClaimGroupTypeId = @_ClaimGroupTypeId OR @_ClaimGroupTypeId IS NULL)
				AND (d.InsuranceCompanyId = @_InsuranceId OR @_InsuranceId IS NULL)
				AND (b.BranchId = @_BranchId OR @_BranchId IS NULL)
				AND d.IsActive = 1
		--ORDER BY InsuranceCompany, d.ClaimGroupCode
	
		INSERT INTO @TmpDetail
		(
			ClaimPayBackDetailId,
			ClaimPayBackDetailCode,
			ClaimPayBackId,
			BranchId,
			Branch,
			Area,
			ClaimGroupCode,
			ClaimOnLineCode,
			ItemCount,
			Amount,
			ClaimGroupType,
			ProductGroupId,
			ProductGroupDetail,
			InsuranceCompanyId,
			InsuranceCompany,
			empClaimOnLineApprove,
			TransferDate,
			IsActive,
			CreatedByUserId,
			CreatedDate,
			TransferUpdatedDate,
			UpdatedByUserId,
			UpdatedDate,
			HospitalProvince,
			HospitalName,
			ClaimCompensateCode,
			ClaimCode,
			CustName,
			Bank,
			BankAccountName,
			BankAccountNo,
			empClaimApproved,
			empClaimPayBackCreated,
			PhoneNo
		)
		SELECT NULL
				,NULL
				,NULL
				,NULL
				,Branch
				,NULL
				,ClaimGroupCode
				,NULL
				,NULL
				,Amount
				,ClaimGroupType
				,NULL
				,ProductGroupDetail
				,NULL
				,InsuranceCompany
				,NULL
				,TransferDate
				,NULL
				,NULL
				,CreatedDate
				,NULL
				,NULL
				,NULL
				,NULL
				,NULL
				,ClaimCompensateCode
				,ClaimCode
				,CustName
				,Bank
				,BankAccountName
				,BankAccountNo
				,empClaimApproved
				,empClaimPayBackCreated
				,PhoneNo
		FROM #TmpDetail2
	END;

		SELECT ClaimPayBackDetailId,
			   ClaimPayBackDetailCode,
			   ClaimPayBackId,
			   BranchId,
			   Branch,
			   Area,
			   ClaimGroupCode,
			   ClaimOnLineCode,
			   ItemCount,
			   Amount,
			   ClaimGroupType,
			   ProductGroupId,
			   ProductGroupDetail,
			   InsuranceCompanyId,
			   InsuranceCompany,
			   empClaimOnLineApprove,
			   TransferDate,
			   IsActive,
			   CreatedByUserId,
			   CreatedDate,
			   TransferUpdatedDate,
			   UpdatedByUserId,
			   UpdatedDate,
			   HospitalProvince,
			   HospitalName,
			   ClaimCompensateCode,
			   ClaimCode,
			   CustName,
			   Bank,
			   BankAccountName,
			   BankAccountNo,
			   empClaimApproved,
			   empClaimPayBackCreated ,
			   PhoneNo
		FROM @TmpDetail
		ORDER BY HospitalName, ProductGroupDetail, InsuranceCompany, ClaimGroupCode ASC

	IF OBJECT_ID('tempdb..@TmpDetail') IS NOT NULL  DELETE FROM @TmpDetail;
	IF OBJECT_ID('tempdb..#TmpDetail') IS NOT NULL  DROP TABLE #TmpDetail;
	IF OBJECT_ID('tempdb..#TmpDetail2') IS NOT NULL  DROP TABLE #TmpDetail2;

		--DECLARE @Date DATETIME = NULL
		--DECLARE @INT INT = NULL
		--DECLARE @BIT BIT = NULL
		--DECLARE @Decimal DECIMAL(16, 2) = NULL
		--SELECT
		--    @INT AS ClaimPayBackDetailId,
		--    '' AS ClaimPayBackDetailCode,
		--    @INT AS ClaimPayBackId,
		--    @INT AS BranchId,
		--    '' AS Branch,
		--    '' AS Area,
		--    '' AS ClaimGroupCode,
		--    '' AS ClaimOnLineCode,
		--    @INT AS ItemCount,
		--    @Decimal AS Amount,
		--    '' AS ClaimGroupType,
		--    @INT AS ProductGroupId,
		--    '' AS ProductGroupDetail,
		--    @INT AS InsuranceCompanyId,
		--    '' AS InsuranceCompany,
		--    '' AS empClaimOnLineApprove,
		--    @Date AS TransferDate,
		--    @BIT AS IsActive,
		--    @INT AS CreatedByUserId,
		--    @Date AS CreatedDate,
		--    @Date AS TransferUpdatedDate,
		--    @INT AS UpdatedByUserId,
		--    @Date AS UpdatedDate,
		--    '' AS HospitalProvince,
		--    '' AS HospitalName,
		--    '' AS ClaimCompensateCode,
		--    '' AS ClaimCode,
		--    '' AS CustName,
		--    '' AS Bank,
		--    '' AS BankAccountName,
		--    '' AS BankAccountNo,
		--    '' AS empClaimApproved,
		--    '' AS empClaimPayBackCreated,
		--	'' AS PhoneNo
	END
