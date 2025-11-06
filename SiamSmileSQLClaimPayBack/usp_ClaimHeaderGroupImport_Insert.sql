USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_ClaimHeaderGroupImport_Insert]    Script Date: 6/11/2568 15:15:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
--	Author:		Siriphong Narkphung
--	Create date: 2022-11-01
--	Update date: 2023-02-02 Add Parameter @BillingDate and save it to ClaimHeaderGroupImport in column BillingDate
--				 2023-03-24 เพิ่ม join [vw_CodeGroup_ClaimStyle] 06958 
--				 2023-07-03 เพิ่ม insert InsuranceCompanyName from ClaimHeaderGroupImport 06958
--	UpdatedDate: bell 20230815 0857  เพิ่ม CreatedByBranchCode 
--	UpdatedDate: 2023-10-17 change select TmpDetail from union to If
--	UpdatedDate: 2025-04-11 Wetpisit.P เพิ่ม where tmp.IsValid = 1 เอาเฉพาะรายการที่ไม่ติด validate,เอาเงื่อนไขเช็ค xResult ออกเนื่องจากมีการเปลี่ยนเงื่อนไขการ validate
--	UpdatedDate: 2025-09-25 08:38 (Bunchuai Chaiket) 
--				 - เพิ่มการ Insert การสร้างรายการลง ClaimHeaderGroupImportCancel
--				 - เพิ่ม parameters @ImportFrom เพื่อแยกว่ารายการที่ Import มาจากช่องทางไหน กำหนด 1 ImportExcel 2 Import จากการตั้งเบิก
-- UpdateDate:	2025-11-06 15:20 Sorawit Kamlangsub
--				- Add ClaimMisc
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[usp_ClaimHeaderGroupImport_Insert]
	-- Add the parameters for the stored procedure here
	@TmpCode VARCHAR(20) 
	,@FileName NVARCHAR(255)
	,@CreateByUseId INT
	,@ImportFrom INT
AS
BEGIN
--WAITFOR DELAY '00:05:00';
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE
--	@TmpCode VARCHAR(20)  = 'IMCHG6810000133'
--	,@FileName NVARCHAR(255) = 'EX_importBillingRequestGroup.xlsx'
--	,@CreateByUseId INT = 0
--	,@ImportFrom INT = 1;

DECLARE @ClaimHeaderSSS INT = 2;
DECLARE @ClaimHeaderSSSPA INT = 3;
DECLARE @ClaimCompensate INT = 4;
DECLARE @ClaimHeaderPA30 INT = 5;
DECLARE @Compensate_Include DECIMAL(16,2) = 0;
DECLARE @CountItemFile INT;
DECLARE @D DATETIME2 = SYSDATETIME();
DECLARE @ClaimHeaderGroupImportFileId INT;
DECLARE @IsResult    BIT             = 1;		
DECLARE @Result        VARCHAR(100) = '';
DECLARE @xIsResult BIT=0;
DECLARE @xResult VARCHAR(100)='0';
DECLARE @Msg        NVARCHAR(500)= '';
DECLARE @DiscountSS_PA DECIMAL(16,2) = 0;
DECLARE @Orgen DECIMAL(16,2) = 0;
DECLARE @CancelDetail1 NVARCHAR(500)= N'Import บ.ส. เรียบร้อย อยู่ระหว่างรอการ Generate Group วางบิล';
DECLARE @CancelDetail2 NVARCHAR(500)= N'ได้รับข้อมูล บ.ส. เรียบร้อย อยู่ระหว่างรอการ Generate Group วางบิล';

DECLARE @TmpOut TABLE (ClaimHeaderGroupImportId INT ,ClaimHeaderGroupCode VARCHAR(30)) 
----------------------------------------------

IF @IsResult = 1
BEGIN


	DECLARE @TmpResultVaildate TABLE (xIsResult BIT,xResult VARCHAR(100),xMsg NVARCHAR(max));

	INSERT INTO @TmpResultVaildate( xIsResult , xResult , xMsg )
	EXECUTE dbo.usp_TmpClaimHeaderGroupImport_Validate_V2 @TmpCode;

	SELECT @xIsResult = xIsResult
			,@xResult = xResult
	FROM @TmpResultVaildate;

	IF (@xIsResult <> 1)
		BEGIN
			SET @IsResult = 0;
			SET @Msg = N'กรุณาตรวจสอบข้อมูลใหม่อีกครั้ง';
		END	
END	
---------------------------------------------------------------------


IF @IsResult = 1								
	BEGIN	

		DECLARE @ClaimHeaderGroupTypeId INT;
		
		SELECT 
			tmp.TmpClaimHeaderGroupImportId
			,tmp.TmpCode
			,tmp.ClaimHeaderGroupCode
			,tmp.ItemCount
			,tmp.TotalAmount
			,tmp.BillingDate
			,tmp.IsValid
			,tmp.ValidateResult
			,tmp.InsuranceCompanyId
			,tmp.ClaimHeaderGroupTypeId
			,tmp.ClaimTypeCode
		INTO #Tmp
		FROM dbo.TmpClaimHeaderGroupImport tmp
		WHERE tmp.TmpCode = @TmpCode AND tmp.IsValid = 1


		SELECT h.ClaimHeaderGroup_id
               ,h.InsuranceCompany_Name 
		INTO #TmpCompany
		FROM 
			(
		SELECT g.ClaimHeaderGroup_id,
               g.InsuranceCompany_Name 
		FROM #Tmp m
			INNER JOIN 
				(
					SELECT ClaimHeaderGroup_id,InsuranceCompany_Name 
					FROM sss.dbo.DB_ClaimHeader 
					GROUP BY ClaimHeaderGroup_id,InsuranceCompany_Name
				)g
				ON m.ClaimHeaderGroupCode = ClaimHeaderGroup_id

			UNION

			SELECT g.ClaimCompensateGroupCode
				,g.InsuranceCompany_Name
			FROM #Tmp m
				INNER JOIN SSS.dbo.ClaimCompensateGroup g
					ON m.ClaimHeaderGroupCode = g.ClaimCompensateGroupCode
			UNION

			SELECT g.Code
				,g.InsuranceCompany_Name
			FROM #Tmp m
				INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup g
					ON m.ClaimHeaderGroupCode = g.Code

			UNION

			SELECT 
				g.ClaimHeaderGroupCode
				,g.InsuranceCompanyName	InsuranceCompany_Name
			FROM #Tmp m
				INNER JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] g
					ON m.ClaimHeaderGroupCode = g.ClaimHeaderGroupCode

				) h

		SELECT @ClaimHeaderGroupTypeId = MIN(ClaimHeaderGroupTypeId)
		FROM #Tmp
		
			DECLARE @TmpDetail TABLE (
				ClaimHeaderGroupCode VARCHAR(30)
				 ,ClaimCode VARCHAR(20)
				 ,Province NVARCHAR(100)
				 ,IdentityCard VARCHAR(20)
				 ,CustName NVARCHAR(500)
				 ,DateHappen DATETIME
				 ,Pay FLOAT
				 ,HospitalId INT 
				 ,HospitalName NVARCHAR(250)
				 ,DateIn DATETIME
				 ,DateOut DATETIME
				 ,ApplicationCode VARCHAR(20)
				 ,ProductId INT
				 ,Product NVARCHAR(255)
				 ,DateNotice DATETIME
				 ,StartCoverDate DATE
				 ,ClaimAdmitTypeCode VARCHAR(20)
				 ,ClaimAdmitType NVARCHAR(255)
				 ,ClaimType NVARCHAR(255)
				 ,ICD10_1Code VARCHAR(20)
				 ,ICD10 NVARCHAR(255)
				 ,IPDCount INT
				 ,ICUCount INT
				 ,Net FLOAT
				 ,Compensate_Include FLOAT
				 ,Pay_Total FLOAT
				 ,DiscountSS DECIMAL(16, 2)
				 ,PaySS_Total DECIMAL(16, 2)
				 ,PolicyNo VARCHAR(50)
				 ,SchoolName NVARCHAR(255)
				 ,CustomerDetailCode VARCHAR(20)
				 ,SchoolLevel NVARCHAR(200)
				 ,Accident NVARCHAR(255)
				 ,ChiefComplain NVARCHAR(200)
				 ,Orgen DECIMAL(16, 2)
				 ,Amount_Compeasate_in FLOAT
				 ,Amount_Compeasate_out FLOAT
				 ,Amount_Pay FLOAT
				 ,Amount_Dead FLOAT
				 ,Remark NVARCHAR(500)
				 ,CreatedByBranchCode VARCHAR(20)
			);

		----- PH , PA30 -----
		IF @ClaimHeaderGroupTypeId IN(2,5)
			BEGIN
				INSERT INTO @TmpDetail
				(
				    ClaimHeaderGroupCode,
				    ClaimCode,
				    Province,
				    IdentityCard,
				    CustName,
				    DateHappen,
				    Pay,
				    HospitalId,
				    HospitalName,
				    DateIn,
				    DateOut,
				    ApplicationCode,
				    ProductId,
				    Product,
				    DateNotice,
				    StartCoverDate,
				    ClaimAdmitTypeCode,
				    ClaimAdmitType,
				    ClaimType,
				    ICD10_1Code,
				    ICD10,
				    IPDCount,
				    ICUCount,
				    Net,
				    Compensate_Include,
				    Pay_Total,
				    DiscountSS,
				    PaySS_Total,
				    PolicyNo,
				    SchoolName,
				    CustomerDetailCode,
				    SchoolLevel,
				    Accident,
				    ChiefComplain,
				    Orgen,
				    Amount_Compeasate_in,
				    Amount_Compeasate_out,
				    Amount_Pay,
				    Amount_Dead,
				    Remark,
				    CreatedByBranchCode
				)
				SELECT 	
					h.ClaimHeaderGroup_id AS ClaimHeaderGroupCode
					,h.Code AS ClaimCode
					,pv.Detail AS Province
					,c.ZCard_id AS IdentityCard
					,CONCAT(ct.Detail,c.FirstName,' ',c.LastName) AS CustName
					,h.DateHappen
					,v.Pay
					,hos.Organize_ID AS HospitalId
					,hos.OrganizeDetail AS HospitalName
					,ci.AdmitDate AS DateIn
					,ci.LeaveDate AS DateOut
					,h.App_id AS ApplicationCode
					,pro.Product_ID AS ProductId
					,pro.ProductDetail AS Product
					,h.DateNotice
					,c.StartCoverDate
					,h.ClaimAdmitType_id AS ClaimAdmitTypeCode
					,cat.Detail AS ClaimAdmitType
					,clt.Detail AS ClaimType
					,h.ICD10_1 AS ICD10_1Code
					,icd10.Detail_Thai AS ICD10
					,ci.IPDCount
					,ci.ICUCount
					,v.net AS Net
					,v.Compensate_Include
					,v.Pay_Total
					,v.DiscountSS
					,v.PaySS_Total
					,NULL AS PolicyNo
					,NULL AS SchoolName
					,NULL AS CustomerDetailCode
					,NULL AS SchoolLevel
					,NULL AS Accident
					,cf.Detail AS ChiefComplain
					,NULL AS Orgen
					,NULL AS Amount_Compeasate_in
					,NULL AS Amount_Compeasate_out
					,NULL AS Amount_Pay
					,NULL AS Amount_Dead
					,NULL AS Remark
					,ci.BranchID		CreatedByBranchCode	
				FROM #Tmp t
					LEFT JOIN SSS.dbo.DB_ClaimHeader AS h
						ON t.ClaimHeaderGroupCode = h.ClaimHeaderGroup_id
					LEFT JOIN SSS.dbo.DB_Customer AS c
						ON h.App_id = c.App_id
					LEFT JOIN SSS.dbo.DB_Payer AS py
						ON c.Payer_id = py.Code
					LEFT JOIN SSS.dbo.DB_Address AS ad
						ON py.WorkAddress_id = ad.Code
					LEFT JOIN SSS.dbo.SM_Tumbol AS sd
						ON ad.Tumbol_id = sd.Code
					LEFT JOIN SSS.dbo.SM_Amphoe AS d
						ON sd.Amphoe_id = d.Code
					LEFT JOIN SSS.dbo.SM_Province AS pv
						ON d.Province_id = pv.Code
					LEFT JOIN SSS.dbo.MT_Title AS ct
						ON c.Title_id = ct.Code
					LEFT JOIN SSS.dbo.DB_ClaimVoucher AS v
						ON h.Code = v.Code
					LEFT JOIN DataCenterV1.Organize.Organize AS hos
						ON h.Hospital_id = hos.OrganizeCode
					LEFT JOIN SSS.dbo.DB_ClaimInvoice AS ci
						ON h.Code = ci.ClaimHeader_id
					LEFT JOIN DataCenterV1.Product.Product AS pro
						ON h.Product_id = pro.ProductCode
					LEFT JOIN SSS.dbo.MT_ClaimAdmitType AS cat
						ON h.ClaimAdmitType_id = cat.Code
					LEFT JOIN SSS.dbo.MT_ClaimType AS clt
						ON h.ClaimType_id = clt.Code
					LEFT JOIN SSS.dbo.MT_ICD10 AS icd10
						ON h.ICD10_1 = icd10.Code
					LEFT JOIN SSS.dbo.MT_ChiefComplain cf
						ON h.ChiefComplain_id = cf.Code
					LEFT JOIN SSS.dbo.MT_Product p
						ON h.Product_id = p.Code
				--WHERE @ClaimHeaderGroupTypeId IN (@ClaimHeaderSSS,@ClaimHeaderPA30)						
			END
		----- PA -----
		ELSE IF @ClaimHeaderGroupTypeId = 3
			BEGIN
				-------------------------------------------SSSPA---------------------------------------------
				INSERT INTO @TmpDetail
				(
				    ClaimHeaderGroupCode,
				    ClaimCode,
				    Province,
				    IdentityCard,
				    CustName,
				    DateHappen,
				    Pay,
				    HospitalId,
				    HospitalName,
				    DateIn,
				    DateOut,
				    ApplicationCode,
				    ProductId,
				    Product,
				    DateNotice,
				    StartCoverDate,
				    ClaimAdmitTypeCode,
				    ClaimAdmitType,
				    ClaimType,
				    ICD10_1Code,
				    ICD10,
				    IPDCount,
				    ICUCount,
				    Net,
				    Compensate_Include,
				    Pay_Total,
				    DiscountSS,
				    PaySS_Total,
				    PolicyNo,
				    SchoolName,
				    CustomerDetailCode,
				    SchoolLevel,
				    Accident,
				    ChiefComplain,
				    Orgen,
				    Amount_Compeasate_in,
				    Amount_Compeasate_out,
				    Amount_Pay,
				    Amount_Dead,
				    Remark,
				    CreatedByBranchCode
				)
				SELECT 
					hg.Code															AS ClaimHeaderGroupCode
					,h.Code															AS ClaimCode
					,pv.Detail														AS Province
					,cd.ZCard_ID													AS IdentityCard
					,CONCAT(cdt.Detail,cd.FirstName,' ',cd.LastName)				AS CustName
					,h.DateHappen													AS DateHappen
					,h.Amount_Total													AS Pay
					,hos.Organize_ID												AS HospitalId
					,hos.OrganizeDetail												AS HospitalName
					,h.DateIn														AS DateIn
					,h.DateOut														AS DateOut
					,c.App_id														AS ApplicationCode
					,NULL															AS ProductId
					,p.Detail														AS Product
					,NULL															AS DateNotice
					,NULL															AS StartCoverDate
					,h.ClaimType_id													AS ClaimAdmitTypeCode ---xxxx
					,ctpa.Detail													AS ClaimAdmitType---xxxx
					,CASE 
						WHEN cst.Code = '4110' OR cst.Code = '4120' THEN 'เคลมโรงพยาบาล'  
						ELSE 'เคลมลูกค้า' 
					END AS ClaimType  --2023-03-24 06958
					,icd.Code														AS ICD10_1Code
					,icd.Detail_Thai												AS ICD10
					,NULL															AS IPDCount
					,NULL															AS ICUCount
					,NULL															AS Net
					,NULL															AS Compensate_Include
					,h.Amount_Net													AS Pay_Total
					,h.DiscountSS													AS DiscountSS
					,h.PaySS_Total													AS PaySS_Total
					,ISNULL(CASE h.ClaimType_id
								WHEN '4009' THEN ccy.[9602]
								WHEN '4010' THEN ccy.[9604]
								ELSE ccy.[9601]
							END,ccy.[9605])											AS PolicyNo
					,sch.Detail														AS SchoolName
					,h.CustomerDetail_id											AS CustomerDetailCode
					,lvl.Detail														AS SchoolLevel
					,acc.Detail														AS Accident
					,cco.Detail														AS ChiefComplain
					,@Orgen															AS Orgen
					,h.Amount_Compensate_in											AS Amount_Compeasate_in
					,h.Amount_Compensate_out										AS Amount_Compeasate_out
					,h.Amount_Pay													AS Amount_Pay
					,CASE 
						WHEN h.ClaimType_id = '4006' THEN h.Amount_Compensate
						WHEN h.ClaimType_id = '4006_2' THEN h.Amount_Compensate
						WHEN h.ClaimType_id = '4007' THEN h.Amount_Compensate
						ELSE 0
					END																AS Amount_Dead
					,h.Remark														AS Remark
					,h.CreatedByBranch_id											CreatedByBranchCode
				FROM #Tmp t
					LEFT JOIN SSSPA.dbo.DB_ClaimHeaderGroup AS hg
						ON t.ClaimHeaderGroupCode = hg.Code
					LEFT JOIN SSSPA.dbo.DB_ClaimHeader AS h
						ON hg.Code = h.ClaimheaderGroup_id
					LEFT JOIN SSSPA.dbo.DB_CustomerDetail AS cd
						ON h.CustomerDetail_id = cd.Code
					LEFT JOIN SSSPA.dbo.DB_Customer AS c
						ON cd.Application_id = c.App_id
					LEFT JOIN SSSPA.dbo.MT_Company AS sch
						ON c.School_id = sch.Code
					LEFT JOIN SSSPA.dbo.MT_Product AS p
						ON c.Product_id = p.Code
					LEFT JOIN SSS.dbo.SM_Tumbol AS sd
						ON sch.Tumbol_id = sd.Code
					LEFT JOIN SSS.dbo.SM_Amphoe AS d
						ON sd.Amphoe_id = d.Code
					LEFT JOIN SSS.dbo.SM_Province AS pv
						ON d.Province_id = pv.Code
					LEFT JOIN SSSPA.dbo.MT_Title AS cdt
						ON cd.Title_id = cdt.Code
					LEFT JOIN DataCenterV1.Organize.Organize AS hos
						ON h.Hospital_id = hos.OrganizeCode
					LEFT JOIN SSS.dbo.MT_ICD10 icd
						ON h.ICD10_1 = icd.Code
					LEFT JOIN 
						(
							SELECT p.App_id
								,p.[9605]
								,p.[9604]
								,p.[9603]
								,p.[9602]
								,p.[9601] 
							FROM 
							(SELECT 
								cp.App_id
								,cp.PolicyType_id
								,cp.Detail
							FROM SSSPA.dbo.DB_CustomerPolicy cp
							)d 
							PIVOT
							(
								 MAX(Detail)FOR PolicyType_id IN([9601],[9602],[9603],[9604],[9605])
							)p
						)ccy
						ON c.App_id = ccy.App_id
					--------------------------------------------------------------------
					LEFT JOIN (
						SELECT * FROM SSSPA.dbo.SM_Code WHERE CodeGroup_id = '8600'
					) AS lvl
						ON c.LevelSchool_id = lvl.Code
					LEFT JOIN (
						SELECT * FROM SSSPA.dbo.SM_Code WHERE CodeGroup_id = '4000'
					) AS ctpa
						ON h.ClaimType_id = ctpa.Code
					LEFT JOIN SSSPA.dbo.MT_AccidentCause AS acc
						ON h.AccidentCause_id = acc.Code
					LEFT JOIN SSS.dbo.MT_ChiefComplain AS cco
						ON h.ChiefComplain_id = cco.Code
					LEFT JOIN [SSSPA].[dbo].[vw_CodeGroup_ClaimStyle] cst
						ON h.ClaimStyle_id = cst.Code
				--WHERE @ClaimHeaderGroupTypeId = @ClaimHeaderSSSPA
			END
		----- ClaimCompensate -----
		ELSE IF @ClaimHeaderGroupTypeId = 4
			BEGIN
				-----ClaimCompensate-----------------------------------
				INSERT INTO @TmpDetail
				(
				    ClaimHeaderGroupCode,
				    ClaimCode,
				    Province,
				    IdentityCard,
				    CustName,
				    DateHappen,
				    Pay,
				    HospitalId,
				    HospitalName,
				    DateIn,
				    DateOut,
				    ApplicationCode,
				    ProductId,
				    Product,
				    DateNotice,
				    StartCoverDate,
				    ClaimAdmitTypeCode,
				    ClaimAdmitType,
				    ClaimType,
				    ICD10_1Code,
				    ICD10,
				    IPDCount,
				    ICUCount,
				    Net,
				    Compensate_Include,
				    Pay_Total,
				    DiscountSS,
				    PaySS_Total,
				    PolicyNo,
				    SchoolName,
				    CustomerDetailCode,
				    SchoolLevel,
				    Accident,
				    ChiefComplain,
				    Orgen,
				    Amount_Compeasate_in,
				    Amount_Compeasate_out,
				    Amount_Pay,
				    Amount_Dead,
				    Remark,
				    CreatedByBranchCode
				)
				SELECT	
					cg.ClaimCompensateGroupCode						AS ClaimHeaderGroupCode
					,cc.ClaimHeaderCode								AS ClaimCode
					,pv.Detail										AS Province
					,c.ZCard_id										AS IdentityCard
					,CONCAT(ct.Detail,c.FirstName,' ',c.LastName)	AS CustName
					,cc.DateHappen
					,cc.CompensateRemain							AS Pay
					,hos.Organize_ID								AS HospitalId
					,hos.OrganizeDetail								AS HospitalName
					,cc.DateIn										AS DateIn
					,cc.DateOut										AS DateOut
					,h.App_id										AS ApplicationCode
					,pro.Product_ID									AS ProductId
					,pro.ProductDetail								AS Product
					,cc.DateNotice
					,c.StartCoverDate
					,cc.ClaimAdmitTypeCode							AS ClaimAdmitTypeCode
					,cat.Detail										AS ClaimAdmitType
					,clt.Detail										AS ClaimType
					,cc.ICD10Code									AS ICD10_1Code
					,icd10.Detail_Thai								AS ICD10
					,ci.IPDCount
					,ci.ICUCount
					,cc.CompensateRemain							AS Net
					,@Compensate_Include							AS Compensate_Include
					,cc.CompensateRemain							AS Pay_Total
					,@DiscountSS_PA									AS DiscountSS
					,cc.CompensateRemain							AS PaySS_Total
					,NULL											AS PolicyNo
					,NULL											AS SchoolName
					,NULL											AS CustomerDetailCode
					,NULL											AS SchoolLevel
					,NULL											AS Accident
					,cf.Detail										AS ChiefComplain
					,NULL											AS Orgen
					,NULL											AS Amount_Compeasate_in
					,NULL											AS Amount_Compeasate_out
					,NULL											AS Amount_Pay
					,NULL											AS Amount_Dead
					,NULL											AS Remark	
					,'9901'											AS CreatedByBranchCode  -- 10-04-2024 Fix Branch สำนักงานใหญ่ type โอนแยก cc.CreatedByBranchCode	
				FROM #Tmp AS t
					LEFT JOIN SSS.dbo.ClaimCompensateGroup AS cg
						ON t.ClaimHeaderGroupCode = cg.ClaimCompensateGroupCode
					LEFT JOIN 
						(
							SELECT c1.*
									,t.Branch_id		CreatedByBranchCode
							FROM SSS.dbo.ClaimCompensate c1
								LEFT JOIN sss.dbo.DB_Team t
									ON c1.CreatedByCode = t.Code
							WHERE c1.IsActive = 1
						)	AS cc
						ON cg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
					LEFT JOIN SSS.dbo.DB_ClaimHeader AS h
						ON cc.ClaimHeaderCode = h.Code
				---------------------------------------
					LEFT JOIN SSS.dbo.DB_Customer AS c
						ON h.App_id = c.App_id
					LEFT JOIN SSS.dbo.DB_Payer AS py
						ON c.Payer_id = py.Code
					LEFT JOIN SSS.dbo.DB_Address AS ad
						ON py.WorkAddress_id = ad.Code
					LEFT JOIN SSS.dbo.SM_Tumbol AS sd
						ON ad.Tumbol_id = sd.Code
					LEFT JOIN SSS.dbo.SM_Amphoe AS d
						ON sd.Amphoe_id = d.Code
					LEFT JOIN SSS.dbo.SM_Province AS pv
						ON d.Province_id = pv.Code
				----------------------------------------
					LEFT JOIN SSS.dbo.MT_Title AS ct
						ON c.Title_id = ct.Code
					LEFT JOIN DataCenterV1.Organize.Organize AS hos
						ON cc.HospitalCode = hos.OrganizeCode
					LEFT JOIN SSS.dbo.DB_ClaimInvoice AS ci
						ON cc.ClaimHeaderCode = ci.ClaimHeader_id
					LEFT JOIN DataCenterV1.Product.Product AS pro
						ON cc.ProductCode = pro.ProductCode
					LEFT JOIN SSS.dbo.MT_ClaimAdmitType AS cat
						ON cc.ClaimAdmitTypeCode = cat.Code
					LEFT JOIN SSS.dbo.MT_ClaimType AS clt
						ON h.ClaimType_id = clt.Code
					LEFT JOIN SSS.dbo.MT_ICD10 AS icd10
						ON cc.ICD10Code= icd10.Code
					LEFT JOIN SSS.dbo.MT_ChiefComplain cf
						ON h.ChiefComplain_id = cf.Code
				--WHERE @ClaimHeaderGroupTypeId = @ClaimCompensate
			END

		--ClaimMisc
		ELSE IF @ClaimHeaderGroupTypeId = 6
			BEGIN
				INSERT INTO @TmpDetail
				(
				    ClaimHeaderGroupCode,
				    ClaimCode,
				    Province,
				    IdentityCard,
				    CustName,
				    DateHappen,
				    Pay,
				    HospitalId,
				    HospitalName,
				    DateIn,
				    DateOut,
				    ApplicationCode,
				    ProductId,
				    Product,
				    DateNotice,
				    StartCoverDate,
				    ClaimAdmitTypeCode,
				    ClaimAdmitType,
				    ClaimType,
				    ICD10_1Code,
				    ICD10,
				    IPDCount,
				    ICUCount,
				    Net,
				    Compensate_Include,
				    Pay_Total,
				    DiscountSS,
				    PaySS_Total,
				    PolicyNo,
				    SchoolName,
				    CustomerDetailCode,
				    SchoolLevel,
				    Accident,
				    ChiefComplain,
				    Orgen,
				    Amount_Compeasate_in,
				    Amount_Compeasate_out,
				    Amount_Pay,
				    Amount_Dead,
				    Remark,
				    CreatedByBranchCode
				)
				SELECT	
					cm.ClaimHeaderGroupCode							ClaimHeaderGroupCode
					,cm.ClaimMiscNo									ClaimCode
					,NULL											Province
					,cm.CitizenId									IdentityCard
					,cm.CustomerName								CustName
					,cm.DateHappen									DateHappen
					,cm.ClaimAmount									Pay
					,cm.HospitalId									HospitalId
					,cm.HospitalName								HospitalName
					,cm.DateIn										DateIn
					,cm.DateOut										DateOut
					,cm.ApplicationCode								ApplicationCode
					,cm.ProductGroupId								ProductId
					,pd.ProductGroupDetail							[Product]
					,cm.DateNotice									DateNotice
					,cm.StartCoverDate								StartCoverDate
					,NULL											ClaimAdmitTypeCode
					,cxa.ClaimAdmitType								ClaimAdmitType
					,NULL											ClaimType
					,NULL											ICD10_1Code
					,NULL											ICD10
					,NULL											IPDCount
					,cm.ICUCount									ICUCount
					,cm.ClaimAmount									Net
					,@Compensate_Include							Compensate_Include
					,cm.ClaimAmount									Pay_Total
					,NULL											DiscountSS
					,cm.ClaimAmount									PaySS_Total
					,cm.PolicyNo									PolicyNo
					,NULL											SchoolName
					,NULL											CustomerDetailCode
					,NULL											SchoolLevel
					,NULL											Accident
					,chp.ChiefComplainName							ChiefComplain
					,NULL											Orgen
					,NULL											Amount_Compeasate_in
					,NULL											Amount_Compeasate_out
					,cm.ClaimAmount									Amount_Pay
					,NULL											Amount_Dead
					,cm.RemarkClaim									Remark	
					,dtB.tempcode									CreatedByBranchCode  
				FROM #Tmp t
				LEFT JOIN [ClaimMiscellaneous].[misc].[ClaimMisc] cm
					ON cm.ClaimHeaderGroupCode = t.ClaimHeaderGroupCode
				LEFT JOIN [DataCenterV1].[Product].[ProductGroup] pd
					ON cm.ProductGroupId = pd.ProductGroup_ID
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
						).value('.', 'nvarchar(255)'), 1, 1, '')	ClaimAdmitType
					FROM [ClaimMiscellaneous].[misc].[ClaimMiscXClaimAdmitType] x
					WHERE x.IsActive = 1
					GROUP BY x.ClaimMiscId
				) cxa
					ON cxa.ClaimMiscId = cm.ClaimMiscId
				LEFT JOIN 
					(
						SELECT
							ChiefComplainId
							,ChiefComplainName
						FROM [ClaimMiscellaneous].[misc].[ChiefComplain]
						WHERE IsActive = 1
					) chp
					ON chp.ChiefComplainId = cm.ChiefComplainId
				LEFT JOIN DataCenterV1.Address.Branch dtB
					ON cm.BranchId = dtB.Branch_ID;

			END


		SELECT m.ClaimCode
				,dcr.PolicyNo
		INTO #TmpDcrPolicyNo
		FROM 
		(
		SELECT ClaimCode
				,CAST( FORMAT(DateHappen,'yyyy-MM-01') AS DATE) PeriodDateHappen 
				,ApplicationCode
		FROM @TmpDetail
		)m
			INNER JOIN sss.dbo.DB_DCR dcr
				ON m.ApplicationCode = dcr.App_Id
				AND m.PeriodDateHappen = dcr.Period;

		------------------------------------------------------
		SELECT @CountItemFile = COUNT(TmpCode) 
		FROM #Tmp;

		BEGIN TRY								
			BEGIN TRANSACTION

				---INSERT File------
				INSERT INTO dbo.ClaimHeaderGroupImportFile
						 (
							 [FileName]
							 ,ItemCount
							 ,ClaimHeaderGroupTypeId
							 ,IsActive
							 ,CreatedDate
							 ,CreatedByUserId
							 ,UpdatedDate
							 ,UpdatedByUserId
						 )
				SELECT @FileName				[FileName]
					,@CountItemFile				ItemCount
					,@ClaimHeaderGroupTypeId	ClaimHeaderGroupTypeId
					,1							IsActive
					,@D							CreatedDate
					,@CreateByUseId				CreatedByUserId
					,@D							UpdatedDate
					,@CreateByUseId				UpdatedByUserId

				SET @ClaimHeaderGroupImportFileId = SCOPE_IDENTITY();

				---INSERT GROUP-----
				INSERT INTO dbo.ClaimHeaderGroupImport
						 (
							 ClaimHeaderGroupCode
							 ,ClaimGroupImportFileId
							 ,ItemCount
							 ,TotalAmount
							 ,BillingDate
							 ,ClaimHeaderGroupImportStatusId
							 ,InsuranceCompanyId
							 ,BillingRequestGroupId
							 ,IsActive
							 ,CreatedDate
							 ,CreatedByUserId
							 ,UpdatedDate
							 ,UpdatedByUserId
							 ,ClaimTypeCode
							 ,InsuranceCompanyName
						 )
				OUTPUT Inserted.ClaimHeaderGroupImportId , Inserted.ClaimHeaderGroupCode INTO @TmpOut
				SELECT t1.ClaimHeaderGroupCode
					,@ClaimHeaderGroupImportFileId	ClaimGroupImportFileId
					,t1.ItemCount					
					,t1.TotalAmount					
					
					,t1.BillingDate					
					,2								ClaimHeaderGroupImportStatusId
					,t1.InsuranceCompanyId
					,NULL							BillingRequestGroupId
					,1								IsActive
					,@D								CreatedDate
					,@CreateByUseId					CreatedByUserId
					,@D								UpdatedDate
					,@CreateByUseId					CreatedByUserId
					,t1.ClaimTypeCode
					,tc.InsuranceCompany_Name
				FROM #Tmp t1
					LEFT JOIN #TmpCompany tc
						ON t1.ClaimHeaderGroupCode = tc.ClaimHeaderGroup_id

				---INSERT DETAIL-----
				INSERT INTO dbo.ClaimHeaderGroupImportDetail
						 (
							 ClaimHeaderGroupImportId
							 ,ClaimCode
							 ,ClaimHeaderGroupCode
							 ,Province
							 ,IdentityCard
							 ,CustName
							 ,DateHappen
							 ,Pay
							 ,HospitalId
							 ,HospitalName
							 ,DateIn
							 ,DateOut
							 ,ApplicationCode
							 ,ProductId
							 ,Product
							 ,DateNotice
							 ,StartCoverDate
							 ,ClaimAdmitTypeCode
							 ,ClaimAdmitType
							 ,ClaimType
							 ,ICD10_1Code
							 ,ICD10
							 ,IPDCount
							 ,ICUCount
							 ,Net
							 ,Compensate_Include
							 ,Pay_Total
							 ,DiscountSS
							 ,PaySS_Total
							 ,PolicyNo
							 ,SchoolName
							 ,CustomerDetailCode
							 ,SchoolLevel
							 ,Accident
							 ,ChiefComplain
							 ,Orgen
							 ,Amount_Compensate_in
							 ,Amount_Compensate_out
							 ,Amount_Pay
							 ,Amount_Dead
							 ,Remark
							 ,IsActive
							 ,CreatedDate
							 ,CreatedByUserId
							 ,UpdatedDate
							 ,UpdatedByUserId
							 ,CreatedByBranchId
						 )
				SELECT 
					u.ClaimHeaderGroupImportId
					,m.ClaimCode
					,m.ClaimHeaderGroupCode
					,m.Province
					,m.IdentityCard
					,m.CustName
					,m.DateHappen
					,m.Pay
					,m.HospitalId
					,m.HospitalName
					,m.DateIn
					,m.DateOut
					,m.ApplicationCode
					,m.ProductId
					,m.Product
					,m.DateNotice
					,m.StartCoverDate
					,m.ClaimAdmitTypeCode
					,m.ClaimAdmitType
					,m.ClaimType
					,m.ICD10_1Code
					,m.ICD10
					,m.IPDCount
					,m.ICUCount
					,m.Net
					,m.Compensate_Include
					,m.Pay_Total
					,m.DiscountSS
					,m.PaySS_Total
					--,m.PolicyNo
					,CASE 	
						WHEN @ClaimHeaderGroupTypeId IN (2,4,5) THEN p.PolicyNo
						ELSE m.PolicyNo
						END	PolicyNo
					,m.SchoolName
					,m.CustomerDetailCode
					,m.SchoolLevel
					,m.Accident
					,m.ChiefComplain
					,m.Orgen
					,m.Amount_Compeasate_in
					,m.Amount_Compeasate_out
					,m.Amount_Pay
					,m.Amount_Dead
					,m.Remark
					,1						IsActive
					,@D						CreatedDate
					,@CreateByUseId			CreatedByUserId
					,@D						UpdatedDate
					,@CreateByUseId			UpdatedByUserId
					,dtB.Branch_ID			BranchId
				FROM @TmpDetail m
					LEFT JOIN @TmpOut u
						ON m.ClaimHeaderGroupCode = u.ClaimHeaderGroupCode
					LEFT JOIN #TmpDcrPolicyNo p 
						ON m.ClaimCode = p.ClaimCode
					LEFT JOIN DataCenterV1.Address.Branch dtB
						ON m.CreatedByBranchCode = dtB.tempcode;

				--Delete TmpClaimHeaderGroupImport
				--SELECT *
				DELETE m
				FROM dbo.TmpClaimHeaderGroupImport m 
				WHERE m.TmpCode = @TmpCode;

				-- Insert ClaimHeaderGroupImportCancel
				INSERT INTO [dbo].[ClaimHeaderGroupImportCancel]
						      ([ClaimHeaderGroupImportId]
						      ,[CancelDetail]
						      ,[IsActive]
						      ,[CreatedByUserId]
						      ,[CreatedDate])
						SELECT 
							i.ClaimHeaderGroupImportId								ClaimHeaderGroupImportId
							,IIF(@ImportFrom = 1, @CancelDetail1, @CancelDetail2)	CancelDetail
							,1														IsActive
							,@CreateByUseId											CreatedByUserId
							,@D														CreatedDate
						FROM @TmpOut i;

			SET @IsResult = 1			  					
			SET @Msg = 'บันทึก สำเร็จ'	 						
										  					
			COMMIT TRANSACTION			  					
		END TRY							  					
		BEGIN CATCH						  					
										  					
			SET @IsResult = 0			  					
			SET @Msg = 'บันทึก ไม่สำเร็จ'		
							
			IF @@TRANCOUNT > 0 ROLLBACK	  					
		END CATCH


		IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;
		IF OBJECT_ID('tempdb..#TmpFile') IS NOT NULL  DROP TABLE #TmpFile;
		IF OBJECT_ID('tempdb..#TmpGroup') IS NOT NULL  DROP TABLE #TmpGroup;
		IF OBJECT_ID('tempdb..#TmpCompany') IS NOT NULL  DROP TABLE #TmpCompany;
		IF OBJECT_ID('tempdb..#TmpDcrPolicyNo') IS NOT NULL  DROP TABLE #TmpDcrPolicyNo;	
		IF OBJECT_ID('tempdb..@TmpDetail') IS NOT NULL  DELETE FROM @TmpDetail;
	END	;

										  					
IF @IsResult = 1 BEGIN	SET @Result = 'Success'; END;	
ELSE BEGIN	SET @Result = 'Failure'; END ;				
							  								
            							  					
       SELECT @IsResult IsResult		  					
		,@Result Result					  					
		,@Msg	 Msg 					  					

END
