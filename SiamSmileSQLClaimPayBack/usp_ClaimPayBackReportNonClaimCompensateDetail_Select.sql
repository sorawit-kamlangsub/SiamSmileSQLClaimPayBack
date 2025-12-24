USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimPayBackReportNonClaimCompensateDetail_Select]    Script Date: 24/12/2568 11:15:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Krekpon.D
-- Create date: 2025-08-22 11.06
-- Description: ข้อมูลรายละเอียดการโอนเงินของเคลมเสียชีวิต ทุพพลภาพ
-- Update date: 2025-09-05 10:52 Krekpon.D
-- Description: ปรับการ join ข้อมูลและ where ข้อมูลด้วย BeneficiaryId
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimPayBackReportNonClaimCompensateDetail_Select] 
	-- Add the parameters for the stored procedure here
	 @DateFrom			DATE 
	,@DateTo			DATE 
	,@InsuranceId		INT = NULL
	,@ProductGroupId	INT = NULL	
	,@ClaimGroupTypeId	INT = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
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
WHERE   cpb.ClaimGroupTypeId = @ClaimGroupTypeId
	AND cpb.IsActive = 1 
	AND cpbd.IsActive = 1
	AND ((cpb.CreatedDate >= @DateFrom) AND (cpb.CreatedDate < DATEADD(Day,1,@DateTo)))
    AND (cpbd.ProductGroupId = @ProductGroupId OR @ProductGroupId IS NULL)
	AND (cpbd.InsuranceCompanyId = @InsuranceId OR @InsuranceId IS NULL)

	--SELECT เอาไปใช้งาน
    SELECT		icu.InsuranceCompany_Name AS InsuranceCompany_Name,
				dab.BranchDetail AS Branch,
				TmpCPB.ProductGroupDetailName AS ProductGroupDetailName,
				TmpCPB.ClaimGroupCodeFromCPBD AS ClaimGroupCode,
				icu.ClaimCode AS ClaimNo ,
				IIF(@ClaimGroupTypeId IN (6) , TmpCPB.COL,NULL) AS COL,
				IIF(@ClaimGroupTypeId IN (6) ,icu.CustomerName,NULL) AS CustomerName, 
				CONCAT(tt.Detail,be.FirstName,' ',be.LastName) AS BeneficiaryName,
				smc.Detail AS Relationship,
				cpt.PaymentAmount AS Amount,
				be.BankAccountName AS BankAccountName,
				be.BankAccountNo AS BankAccountNo,
				org.OrganizeDetail AS BankName,
				cpt.PaymentDate AS TransferDate
				,IIF(cpg.TransferCauseName IS NOT NULL,'โอนเพิ่ม', 'ปกติ')	ExtraTransfer
				,IIF(cpg.TransferCauseName IS NOT NULL,cpg.TransferCauseName, NULL)  TransferCauseName
				,cpg.TransferRemark

FROM @TmpClaimPayBack TmpCPB
	 LEFT JOIN(
								SELECT chg.Code AS Code
									, chg.InsuranceCompany_Name AS InsuranceCompany_Name
									, cat.Detail AS ClaimAdmitType
									, chg.Hospital_id AS Hospital
									, chg.CreatedBy_id AS ApprovedUserFromSSS
									,CONCAT(tt.Detail,ct.FirstName,' ',ct.LastName) AS CustomerName
									,ch.Code AS ClaimCode

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

								FROM SSSPA.dbo.DB_ClaimHeaderGroup pachg
								LEFT JOIN SSSPA.dbo.SM_Code smc
									ON pachg.ClaimTypeGroup_id = smc.Code
								LEFT JOIN SSSPA.dbo.DB_ClaimHeader ch
									ON ch.ClaimheaderGroup_id = pachg.Code
								LEFT JOIN SSSPA.dbo.DB_CustomerDetail cd
									ON cd.Code = ch.CustomerDetail_id
								LEFT JOIN SSSPA.dbo.MT_Title tt
									ON tt.Code = cd.Title_id
								
				) icu
		ON TmpCPB.ClaimGroupCodeFromCPBD = icu.Code
	LEFT JOIN [DataCenterV1].[Address].Branch dab
		ON TmpCPB.BranchId = dab.Branch_ID
	INNER JOIN ClaimOnlineV2.dbo.ClaimOnlineItem ci
		ON icu.ClaimCode = ci.ClaimCode
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
	INNER JOIN (
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
	ORDER BY icu.ClaimCode

IF OBJECT_ID('tempdb..@TmpClaimPayBack') IS NOT NULL  DELETE FROM @TmpClaimPayBack;
END
