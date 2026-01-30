USE [ClaimPayBack]
GO

--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO



-- =============================================
-- Author:		Krekpon.D
-- Create date: 2025-08-22 11.06
-- Description: ข้อมูลรายละเอียดการโอนเงินของเคลมเสียชีวิต ทุพพลภาพ
-- Update date: 2025-09-05 10:52 Krekpon.D
-- Description: ปรับการ join ข้อมูลและ where ข้อมูลด้วย BeneficiaryId
-- Update date: 2025-12-24 16:37 Sorawit.k
-- Description: Add ClaimMisc @ClaimGroupTypeId = 7
-- Update date: 2026-01-14 14:35 Krekpon.D
-- Description: ปรับข้อมูลตาม ProductType ใน dropdown
-- Update date: 2026-01-21 11:55 Krekpon.D
-- Description: ดึงข้อมูลของผู้เอาประกัน และ COL
-- =============================================
--ALTER PROCEDURE [dbo].[usp_ClaimPayBackReportNonClaimCompensateDetail_Select] 
--	-- Add the parameters for the stored procedure here
--	 @DateFrom			DATE 
--	,@DateTo			DATE 
--	,@InsuranceId		INT = NULL
--	,@ProductGroupId	INT = NULL	
--	,@ClaimGroupTypeId	INT = NULL
--AS
--BEGIN
--	SET NOCOUNT ON;

	DECLARE 
	 @DateFrom			DATE = '2026-01-29'
	,@DateTo			DATE = '2026-01-29'
	,@InsuranceId		INT = NULL
	,@ProductGroupId	INT = 11	
	,@ClaimGroupTypeId	INT = 7;

	--DECLARE @Value NVARCHAR(Max) = NULL
	--DECLARE @IntVal INT = NULL
	--DECLARE @DeciVal Decimal = NULL
	--DeCLARE @DATETimes DATETIME = NULL
	--SELECT @Value AS InsuranceCompany_Name,
	--			@Value AS Branch,
	--			@Value AS ProductGroupDetailName,
	--			@Value AS ClaimGroupCode,
	--			@Value AS ClaimNo,
	--			@Value AS COL,
	--			@Value AS CustomerName,
	--			@Value AS BeneficiaryName,
	--			@Value AS Relationship,
	--			@DeciVal AS Amount,
	--			@Value AS BankAccountName,
	--			@Value AS BankAccountNo,
	--			@Value As BankName,
	--			@DATETimes AS TransferDate

	DECLARE @_ClaimGroupTypeId INT = @ClaimGroupTypeId;
	SELECT 
		pu.User_ID
		,e.EmployeeCode
		,CONCAT(e.EmployeeCode,' ',pT.TitleDetail,p.FirstName,' ',p.LastName) PersonName
	INTO #TmpPersonUser
	FROM DataCenterV1.Person.PersonUser pu
	LEFT JOIN  DataCenterV1.Person.Person p 
		ON pu.Person_ID = p.Person_ID
			AND p.IsActive = 1
	LEFT JOIN DataCenterV1.Employee.Employee e
		ON pu.Employee_ID = e.Employee_ID
			AND e.IsActive = 1
	LEFT JOIN DataCenterV1.Person.Title pT 
		ON p.Title_ID = pT.Title_ID
	WHERE pu.IsActive = 1

	CREATE INDEX IX_TmpPersonUser_User_ID ON #TmpPersonUser(User_ID);
	CREATE INDEX IX_TmpPersonUser_Code ON #TmpPersonUser(EmployeeCode);

	 DECLARE @TmpClaimPayBack TABLE (
	 ClaimGroupCodeFromCPBD NVARCHAR(150),
	 ClaimGroupType NVARCHAR(100),
	 ItemCount		 INT,
     Amount			 DECIMAL(16,2),
	 ProductGroupDetailName NVARCHAR(20),
	 BranchId		 INT,
	 COL			 NVARCHAR(150),
	 CreatedDate	 DATETIME,
	 CreatedByUser NVARCHAR(150),
	 HospitalCode VARCHAR(20)
     )

	 
-- สร้าง temp table
CREATE TABLE #InsuranceType (
    ProductGroup_ID INT,
    ProductGroupDetail NVARCHAR(100),
    IsActive bit
);

INSERT INTO #InsuranceType (ProductGroup_ID, ProductGroupDetail, IsActive)
VALUES
    (1, N'รอข้อมูล',0),
    (2, N'PH',0),
    (3, N'PA',0),
    (4, N'Motor',0),
    (5, N'PL',0),
    (6, N'House',0),
    (7, N'PA อื่นๆ',1),
    (8, N'ประกันเดินทาง',0),
    (9, N'เบ็ดเตล็ด',0),
    (10, N'CriticalIllness',0),
    (11, N'Miscellaneous',0);
 -- เอาข้อมูลลงใน temp แล้วไป JOIN ต่อกับฝั่ง Base อื่น
 INSERT INTO @TmpClaimPayBack(
      ClaimGroupCodeFromCPBD,
      Amount,
	  ProductGroupDetailName,
	  BranchId,
	  COL,
	  CreatedDate,
	  HospitalCode
      )
 SELECT   
     cpbd.ClaimGroupCode AS ClaimGroupCode,
     cpbd.Amount AS Amount,
	 dppg.ProductGroupDetail AS ProductGroupDetailName,
	 cpb.BranchId AS BranchId,
	 cpbd.ClaimOnLineCode AS COL,
	 cpb.CreatedDate AS CreatedDate,
	 cpbd.HospitalCode	AS HospitalCode
 FROM  ClaimPayBack cpb
	 LEFT JOIN ClaimPayBackDetail cpbd
		ON cpb.ClaimPayBackId = cpbd.ClaimPayBackId
	 LEFT JOIN [DataCenterV1].[Product].ProductGroup dppg
		ON cpbd.ProductGroupId = dppg.ProductGroup_ID
	INNER JOIN #InsuranceType it
		ON dppg.ProductGroup_ID = it.ProductGroup_ID
WHERE   cpb.ClaimGroupTypeId = @ClaimGroupTypeId
	AND cpb.IsActive = 1 
	AND cpbd.IsActive = 1
	AND ((cpb.CreatedDate >= @DateFrom) AND (cpb.CreatedDate < DATEADD(Day,1,@DateTo)))
    AND (
			(	
				@ProductGroupId <> 11
					AND
				cpbd.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL
			)
			OR
			(
				@ProductGroupId = 11
				AND
				(
					@ProductGroupId IS NOT NULL	AND it.ProductGroup_ID = 7
				)
			) 
		)
	AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)

	--SELECT เอาไปใช้งาน
    SELECT		icu.InsuranceCompany_Name AS InsuranceCompany_Name,
				dab.BranchDetail AS Branch,
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN TmpCPB.ProductGroupDetailName
					WHEN @_ClaimGroupTypeId = 7		  THEN icu.ProductTypeName
					ELSE NULL
				END ProductGroupDetailName,
				TmpCPB.ClaimGroupCodeFromCPBD AS ClaimGroupCode,
				icu.ClaimCode AS ClaimNo ,
				IIF(@_ClaimGroupTypeId IN (6,7) , TmpCPB.COL,NULL) AS COL,
				IIF(@_ClaimGroupTypeId IN (6,7) ,icu.CustomerName,NULL) AS CustomerName, 
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN CONCAT(cptOnline.TitleDetail,cptOnline.FirstName,' ',cptOnline.LastName)
					WHEN @_ClaimGroupTypeId = 7		  THEN CONCAT(cptMisc.TitleDetail,cptMisc.FirstName,' ',cptMisc.LastName)
					ELSE NULL
				END BeneficiaryName,
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN cptOnline.Relationship
					WHEN @_ClaimGroupTypeId = 7		  THEN cptMisc.RelationDetail
					ELSE NULL
				END Relationship,
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN cptOnline.Amount
					WHEN @_ClaimGroupTypeId = 7		  THEN cptMisc.Amount
					ELSE NULL
				END Amount,
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN cptOnline.BankAccountName
					WHEN @_ClaimGroupTypeId = 7		  THEN cptMisc.BankAccountName
					ELSE NULL
				END BankAccountName,
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN cptOnline.BankAccountNo
					WHEN @_ClaimGroupTypeId = 7		  THEN cptMisc.BankAccountNo
					ELSE NULL
				END BankAccountNo,
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN cptOnline.BankName
					WHEN @_ClaimGroupTypeId = 7		  THEN cptMisc.BankName
					ELSE NULL
				END BankName,
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN cptOnline.TransferDate
					WHEN @_ClaimGroupTypeId = 7		  THEN cptMisc.TransferDate
					ELSE NULL
				END TransferDate,
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN IIF(cptOnline.TransferCauseName IS NOT NULL,'โอนเพิ่ม', 'ปกติ')
					WHEN @_ClaimGroupTypeId = 7		  THEN cptMisc.PaymentTypeName
					ELSE NULL
				END ExtraTransfer,
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN IIF(cptOnline.TransferCauseName IS NOT NULL,cptOnline.TransferCauseName, NULL)
					WHEN @_ClaimGroupTypeId = 7		  THEN cptMisc.TransferCauseName
					ELSE NULL
				END TransferCauseName,
				CASE 
					WHEN @_ClaimGroupTypeId IN (2,4,6) THEN cptOnline.TransferRemark
					WHEN @_ClaimGroupTypeId = 7		  THEN cptMisc.Remark
					ELSE NULL
				END TransferRemark

FROM @TmpClaimPayBack TmpCPB
	 LEFT JOIN(
								SELECT chg.Code AS Code
									, chg.InsuranceCompany_Name AS InsuranceCompany_Name
									, cat.Detail AS ClaimAdmitType
									, chg.Hospital_id AS Hospital
									, chg.CreatedBy_id AS ApprovedUserFromSSS
									,CONCAT(tt.Detail,ct.FirstName,' ',ct.LastName) AS CustomerName
									,ch.Code AS ClaimCode
									,NULL		HeaderId
									,NULL		ProductTypeName
								FROM sss.dbo.DB_ClaimHeaderGroup chg
								LEFT JOIN SSS.dbo.MT_ClaimAdmitType cat
									ON chg.ClaimAdmitType_id = cat.Code
								LEFT JOIN SSS.dbo.DB_ClaimHeader ch
									ON ch.ClaimHeaderGroup_id = chg.Code
								LEFT JOIN SSS.dbo.DB_Customer ct
									ON ct.App_id = ch.App_id
								LEFT JOIN SSS.dbo.MT_Title tt
									ON tt.Code = ct.Title_id
								
								
								UNION ALL

								SELECT DISTINCT pachg.Code AS Code
									, pachg.InsuranceCompany_Name AS InsuranceCompany_Name
									, smc.Detail AS ClaimAdmitType
									, pachg.Hospital_id AS Hospital
									, pachg.CreatedBy_id AS ApprovedUserFromSSS
									,CONCAT(tt.Detail,cd.FirstName,' ',cd.LastName) AS CustomerName
									,ch.Code AS ClaimCode
									,NULL		HeaderId
									,NULL		ProductTypeName
								FROM SSSPA.dbo.DB_ClaimHeaderGroup pachg
								LEFT JOIN SSSPA.dbo.SM_Code smc
									ON pachg.ClaimTypeGroup_id = smc.Code
								LEFT JOIN SSSPA.dbo.DB_ClaimHeader ch
									ON ch.ClaimheaderGroup_id = pachg.Code
								LEFT JOIN SSSPA.dbo.DB_CustomerDetail cd
									ON cd.Code = ch.CustomerDetail_id
								LEFT JOIN SSSPA.dbo.MT_Title tt
									ON tt.Code = cd.Title_id
								UNION ALL

								-- ClaimMisc
								SELECT 
									cm.ClaimHeaderGroupCode		Code
									,cm.InsuranceCompanyName	InsuranceCompany_Name
									,cxa.ClaimAdmitType			ClaimAdmitType
									,h.HospitalCode				Hospital
									,u.EmployeeCode				ApprovedUserFromSSS
									,cm.CustomerName			CustomerName
									,cm.ClaimMiscNo				ClaimCode
									,cm.ClaimMiscId				HeaderId
									,pd.ProductTypeName
								FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
								LEFT JOIN [ClaimMiscellaneous].[misc].[Hospital] h
									ON h.HospitalId = cm.HospitalId 
								LEFT JOIN #TmpPersonUser u
									ON u.[User_ID] = cm.CreatedByUserId
								LEFT JOIN
								(
									SELECT
										 x.ClaimMiscId
										 ,STUFF((
												 SELECT ',' + a.ClaimAdmitTypeName
												 FROM [ClaimMiscellaneous].[misc].[ClaimMiscXClaimAdmitType] x2
													JOIN [ClaimMiscellaneous].[misc].[ClaimAdmitType] a
														 ON a.ClaimAdmitTypeId = x2.ClaimAdmitTypeId
												 WHERE x2.IsActive = 1
													AND a.IsActive  = 1
													AND x2.ClaimMiscId = x.ClaimMiscId
												 FOR XML PATH(''), TYPE
										 ).value('.', 'nvarchar(255)'), 1, 1, '')        ClaimAdmitType
									FROM [ClaimMiscellaneous].[misc].[ClaimMiscXClaimAdmitType] x
									WHERE x.IsActive = 1
									GROUP BY x.ClaimMiscId
								) cxa
									ON cxa.ClaimMiscId = cm.ClaimMiscId
								LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimEvent] ce
									ON cm.ClaimEventId = ce.ClaimEventId
								LEFT JOIN 
								(
									SELECT 
										ProductTypeId
										,ProductTypeName
									FROM [ClaimMiscellaneous].[misc].[ProductType] 
									WHERE IsActive = 1
								) pd
									ON pd.ProductTypeId = cm.ProductTypeId
								
				) icu
		ON TmpCPB.ClaimGroupCodeFromCPBD = icu.Code
	LEFT JOIN [DataCenterV1].[Address].Branch dab
		ON TmpCPB.BranchId = dab.Branch_ID
	LEFT JOIN
		(
			SELECT
				ci.ClaimCode
				,smc.Detail				Relationship
				,cpt.PaymentAmount		Amount
				,be.BankAccountName
				,be.BankAccountNo		BankAccountNo
				,tt.Detail				TitleDetail		
				,be.FirstName
				,be.LastName
				,cpt.PaymentDate		TransferDate
				,org.OrganizeDetail		BankName
				,cpg.TransferCauseName
				,cpg.TransferRemark
			FROM ClaimOnlineV2.dbo.ClaimOnlineItem ci
				INNER JOIN ClaimOnlineV2.dbo.Beneficiary be
					ON be.ClaimOnLineId = ci.ClaimOnLineId	
				INNER JOIN (
							SELECT 
								pg.BeneficiaryId
								,pg.ClaimPayGroupId
								,pg.PaymentStatusId
								,fc.TransferCauseName
								,pg.TransferRemark
								,pg.ClaimOnLineId
							FROM ClaimOnlineV2.dbo.ClaimPayGroup pg
								LEFT JOIN ClaimOnlineV2.dbo.TransferCause fc
									ON pg.TransferCauseId = fc.TransferCauseId
							WHERE PaymentStatusId = 4
								AND pg.IsActive = 1
							) cpg
					ON be.ClaimOnLineId = cpg.ClaimOnLineId
				LEFT JOIN (
					SELECT 
					PaymentDate
					,ClaimPayGroupId
					,PaymentAmount
					FROM ClaimOnlineV2.dbo.ClaimPayTransaction
					WHERE PremiumSourceStatusId = 5
						AND IsActive = 1
				) cpt
					ON cpt.ClaimPayGroupId = cpg.ClaimPayGroupId
				LEFT JOIN SSS.dbo.MT_Title tt
					ON tt.Code = be.TitleId
				LEFT JOIN SSS.dbo.SM_Code smc
					ON smc.Code = be.RelationId
				LEFT JOIN DataCenterV1.Organize.Organize org
					ON be.BankId = org.Organize_ID
			WHERE be.IsActive = 1
			AND be.BeneficiaryId = cpg.BeneficiaryId			
			AND @_ClaimGroupTypeId = 6

		) cptOnline
		ON cptOnline.ClaimCode = icu.ClaimCode

	LEFT JOIN (
		SELECT *
		FROM
		(
		SELECT *
		FROM (
			SELECT
				cm.ClaimMiscId,
				cptMisc.TransferDate,
				cptMisc.Amount,
				cptMisc.PaymentTypeName,
				cptMisc.TitleDetail,
				cptMisc.FirstName,
				cptMisc.LastName,
				cptMisc.RelationDetail,
				cptMisc.BankAccountName,
				cptMisc.BankAccountNo,
				cptMisc.ClaimMiscStatusId,
				cptMisc.BankName,
				cptMisc.TransferCauseName,
				cptMisc.Remark,
				cptMisc.ProductTypeId,
				ROW_NUMBER() OVER (
					PARTITION BY cm.ClaimMiscId, cptMisc.PaymentTypeName,cptMisc.RelationDetail
					ORDER BY cptMisc.TransferDate DESC
				) AS rn
			FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
			LEFT JOIN (
				SELECT
					cmph.ClaimMiscId,
					cmpd.PaymentDate AS TransferDate,
					cmpd.Amount,
					pmt.PaymentTypeName,
					be.TitleDetail,
					be.FirstName,
					be.LastName,
					be.RelationDetail,
					be.BankAccountName,
					be.BankAccountNo,
					cm2.ClaimMiscStatusId,
					bank.BankName,
					tfc.TransferCauseName,
					cmpd.Remark,
					cm2.ProductTypeId
				FROM [ClaimMiscellaneous].[misc].[ClaimMiscPaymentHeader] cmph
				INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMiscPayment] cmpd
					ON cmpd.ClaimMiscPaymentHeaderId = cmph.ClaimMiscPaymentHeaderId
					AND cmpd.IsActive = 1
					AND cmpd.PremiumSourceStatusId = 5
				LEFT JOIN [ClaimMiscellaneous].[misc].[PaymentType] pmt
					ON pmt.PaymentTypeId = cmph.PaymentTypeId
					AND pmt.IsActive = 1
				INNER JOIN [ClaimMiscellaneous].[misc].[Beneficiary] be
					ON be.ClaimMiscId = cmph.ClaimMiscId
					AND be.IsActive = 1
				INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm2
					ON cm2.ClaimMiscId = cmph.ClaimMiscId
					AND cm2.IsActive = 1
				LEFT JOIN [ClaimMiscellaneous].[ext].[Bank] bank
					ON be.BankId = bank.BankId
				LEFT JOIN [ClaimMiscellaneous].[misc].[TransferCause] tfc
					ON tfc.TransferCauseId = cmpd.TransferCauseId
				WHERE cmph.IsActive = 1
			) cptMisc
				ON cptMisc.ClaimMiscId = cm.ClaimMiscId
		) x
		WHERE x.rn = 1
		) rs
	) cptMisc
		ON cptMisc.ClaimMiscId = icu.HeaderId	

	WHERE @_ClaimGroupTypeId = 6 
	OR ( cptMisc.ProductTypeId = 38 AND @_ClaimGroupTypeId = 7)

	ORDER BY icu.ClaimCode

IF OBJECT_ID('tempdb..#TmpPersonUser') IS NOT NULL DROP TABLE #TmpPersonUser;
IF OBJECT_ID('tempdb..#InsuranceType') IS NOT NULL  DROP TABLE #InsuranceType;
--END



