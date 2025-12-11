USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [Claim].[usp_ClaimPayBackDetail_InsertV4]    Script Date: 11/12/2568 16:35:17 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Kittisak.Ph (อ้างอิง usp_ClaimPayBackDetail_InsertV3)
-- Description:	Add ClaimHospital and ClaimCompensate บันทึกตั้งเบิกเคลม
-- Create date: 2024-10-09
-- Update date: 2025-02-26 เพิ่มเช็คบันทึกสถานะส่งตั้งเบิกเฉพาะเคลมออนไลน์ 
-- Update date: 2025-08-11 Krekpon.D 
-- Description: ClaimGroupType 6 When is PA
-- Update date: 2025-09-02 08:57 Bunchuai Chaiket
-- Description: Change condition SELECT #TmpX IF InsCode = @InsuranceCompanyId SET GroupId = 2
-- Update date: 2025-10-21 13:48 Sorawit Kamlangsub
-- Description: Change to EXECUTE usp_ClaimPayBackDetail_InsertV5
-- Update date: 2025-10-22 13:48 Sorawit Kamlangsub
-- Description: Add ClaimMisc
-- Update date: 2025-11-06 Kittisak.Ph Add RoundNumber to ClaimWithdrawal
-- Update date: 2025-11-27 Sorawit Kamlangsub Add ClaimMisc
-- Update date: 2025-12-4 Sorawit Kamlangsub แก้ไข @TmpD เพิ่มขนาด Field ProductCode จาก 20 เป็น 255
-- Update date: 2025-12-9 Sorawit Kamlangsub แก้ไข ClaimMisc เพิ่ม Left Join DataCenterV1 ด้วย cm.InsCode เอา Organize_Id มาเก็บใน InsId
-- =============================================
ALTER PROCEDURE [Claim].[usp_ClaimPayBackDetail_InsertV4]
	@ClaimGroupCodeList		NVARCHAR(MAX)
	  , @ProductGroupId			INT
	  , @ClaimGroupTypeId		INT 
	  , @CreatedByUserId		INT 
AS
BEGIN
	
	SET NOCOUNT ON;
	
	DECLARE @IsResult	BIT				= 1;
	DECLARE @Result		VARCHAR(100)	= '';
	DECLARE @Msg		NVARCHAR(500)	= '';

	IF @IsResult = 0 SET @Msg = 'Not allowed to use';

	DECLARE @D DATETIME						  = GETDATE()
	DECLARE @ProductGroupId_PH INT			  = 2	--PH
	DECLARE @ProductGroupId_PA INT			  = 3	--PA 
	DECLARE @CountDuplicate INT
	DECLARE @InsuranceCompanyCode VARCHAR(30) = '100000000041' --'100000000019'
	DECLARE @SMICutOffDate DATE				  = '2024-10-01'	--'2024-09-01'
	DECLARE @InsuranceCompanyId INT			  = 699804 


	DECLARE @TmpD TABLE (
		ClaimHeaderGroupCode VARCHAR(30),
		ProductGroupId INT,
		BranchCode VARCHAR(20),
		BranchId INT,
		ClaimGroupTypeId INT,
		InsCode VARCHAR(20),
		InsId INT,
		ClaimCode VARCHAR(20),
		Amount DECIMAL(16, 2),
		ProductCode VARCHAR(255),
		[Product] NVARCHAR(255),
		HospitalCode VARCHAR(20),
		Hospital NVARCHAR(255),
		ClaimAdmitTypeCode VARCHAR(20),
		ClaimAdmitType NVARCHAR(255),
		ChiefComplainCode VARCHAR(20),
		ChiefComplain NVARCHAR(max),
		ICD10Code VARCHAR(20),
		ICD10 NVARCHAR(max),
		ClaimOnLineCode VARCHAR(20),
		CustomerName NVARCHAR(255),
		AdmitDate DATETIME,
		SchoolName NVARCHAR(255),
		GroupId INT
	);

	DECLARE @TmpGroup TABLE (
		ClaimGroupTypeId INT,
		BranchId INT,
		gId INT,
		sumPremium DECIMAL(16, 2),
		ClaimPaybackCode VARCHAR(50),
		GroupId int
	);

	DECLARE @TmpH TABLE (
		ClaimHeaderGroupCode VARCHAR(30),
		ClaimGroupTypeId INT,
		ProductGroupId INT,
		BranchId INT,
		InsId INT,
		ItemCount INT,
		SumAmount DECIMAL(16, 2),
		ClaimOnLineCode VARCHAR(20),
		hId INT,
		HospitalCode VARCHAR(20),
		GroupId INT
	);

----------------Kittisak.Ph 2024-04-05-------------------------------------------
	DECLARE @TmpXClaim TABLE(
			ClaimOnLineId UNIQUEIDENTIFIER
			,ClaimOnLineItemId UNIQUEIDENTIFIER
			,ClaimCode NVARCHAR(50)
			,ClaimPay DECIMAL(16,2)
			,ClaimPayBackXClaimCreatedByUserId INT
			,ClaimPayBackXClaimCreatedDate DATETIME2
			,RoundNo int
		);
---------------------------------------------------------------------------------

	SELECT DISTINCT Element
	INTO #Tmplst
	from dbo.func_SplitStringToTable(@ClaimGroupCodeList,',');

	SELECT @CountDuplicate = COUNT(pb.ClaimGroupCode)
	FROM dbo.ClaimPayBackDetail  pb
	INNER JOIN #Tmplst lstrS
			   ON (pb.ClaimGroupCode = lstrS.Element)
	WHERE pb.IsActive = 1;


	IF @IsResult = 1
	BEGIN
		IF @CountDuplicate > 0
		BEGIN
			SET @IsResult = 0;
			SET @Msg = 'ClaimHeaderGroupCode Data duplication';
		END	
	END	

	IF @IsResult = 1
	BEGIN
	
		IF @ProductGroupId = 2 AND @ClaimGroupTypeId = 5
			BEGIN

				INSERT INTO @TmpD
				(
				    ClaimHeaderGroupCode
				  , ProductGroupId
				  , BranchId
				  , ClaimGroupTypeId
				  , InsCode
				  , InsId
				  , ClaimCode
				  , Amount
				  , ProductCode
				  , [Product]
				  , HospitalCode
				  , Hospital
				  , ClaimAdmitTypeCode
				  , ClaimAdmitType
				  , ChiefComplainCode
				  , ChiefComplain
				  , ICD10Code
				  , ICD10
				  , ClaimOnLineCode
				  , CustomerName
				  ,	AdmitDate
				  ,	SchoolName 
				  , GroupId 
				)
				SELECT ccg.ClaimCompensateGroupCode	ClaimHeaderGroupCode
					, @ProductGroupId				ProductGroupId
					, 70							BranchId
					, @ClaimGroupTypeId				ClaimGroupTypeId
					, cc.InsuranceCompanyCode		InsCode
					, o.Organize_ID					InsId
					, cc.ClaimHeaderCode			ClaimCode
					, cc.CompensateRemain			Amount
					, cc.ProductCode
					, p.Detail						[Product]
					, cc.HospitalCode				
					, hos.Detail					Hospital
					, cl.ClaimAdmitType_id			ClaimAdmitTypeCode
					, cat.Detail					ClaimAdmitType
					, cl.ChiefComplain_id			ChiefComplainCode
					, ccp.Detail					ChiefComplain
					, cl.ICD10_1					ICD10Code
					, icd.Detail_Thai				ICD10
					, cl.ClaimOnLineCode		
					, NULL
					, NULL
					, NULL
					,1		--GroupId
				FROM sss.dbo.ClaimCompensate cc
				INNER JOIN sss.dbo.ClaimCompensateGroup ccg
					ON cc.ClaimCompensateGroupId = ccg.ClaimCompensateGroupId
				INNER JOIN #Tmplst lst
					ON ccg.ClaimCompensateGroupCode = lst.Element
				LEFT JOIN sss.dbo.DB_ClaimHeader cl
					ON cc.ClaimHeaderCode = cl.Code
				LEFT JOIN DataCenterV1.Organize.Organize o
					ON cc.InsuranceCompanyCode = o.OrganizeCode
				LEFT JOIN sss.dbo.MT_Product p
					ON cc.ProductCode = p.Code
				LEFT JOIN sss.dbo.MT_Company hos
					ON cc.HospitalCode = hos.Code
				LEFT JOIN sss.dbo.MT_ClaimAdmitType cat
					ON cl.ClaimAdmitType_id = cat.Code
				LEFT JOIN sss.dbo.MT_ChiefComplain ccp
					ON cl.ChiefComplain_id = ccp.Code
				LEFT JOIN SSS.dbo.MT_ICD10 icd
					ON cl.ICD10_1 = icd.Code


				INSERT INTO @TmpGroup
				(
				    ClaimGroupTypeId
				  , BranchId
				  , gId
				  , sumPremium
				  ,GroupId
				)
				SELECT @ClaimGroupTypeId		ClaimGroupTypeId
					, 70						BranchId
					, 1							gId
					, SUM(Amount)				sumPremium
					,1
				FROM @TmpD
				GROUP BY ClaimGroupTypeId, BranchId


				INSERT INTO @TmpH
				(
				    ClaimHeaderGroupCode
				  , ClaimGroupTypeId
				  , ProductGroupId
				  , BranchId
				  , InsId
				  , ItemCount
				  , SumAmount
				  , ClaimOnLineCode
				  , hId
				  , HospitalCode
				  ,GroupId
				)
				SELECT g.ClaimHeaderGroupCode
					, g.ClaimGroupTypeId
					, g.ProductGroupId
					, g.BranchId
					, g.InsId
					, s.ItemCount
					, s.SumAmount
					, s.ClaimOnLineCode
					, ROW_NUMBER() OVER(ORDER BY (g.ClaimHeaderGroupCode) asc ) hId
					, g.HospitalCode
					,1
				FROM
					(
						SELECT ClaimHeaderGroupCode
							, ClaimGroupTypeId
							, ProductGroupId 
							, BranchId
							, InsId
							, HospitalCode
						FROM @TmpD
						GROUP BY ClaimHeaderGroupCode
								, ClaimGroupTypeId
								, ProductGroupId
								, BranchId
								, InsId
								, HospitalCode

					)g
				LEFT JOIN 
					(
						SELECT ClaimHeaderGroupCode
							, COUNT(ClaimCode)		ItemCount
							, SUM(Amount)			SumAmount
							, MAX(ClaimOnLineCode)	ClaimOnLineCode
						FROM @TmpD
						GROUP BY ClaimHeaderGroupCode
					)s
					ON g.ClaimHeaderGroupCode = s.ClaimHeaderGroupCode		

                        END
                ELSE IF @ProductGroupId IN (4,11) AND @ClaimGroupTypeId = 7
                        BEGIN
                                                                                                
                                INSERT INTO @TmpD
                                (
                                    ClaimHeaderGroupCode
                                  , ProductGroupId
                                  , BranchCode
                                  , BranchId
                                  , ClaimGroupTypeId
                                  , InsCode
                                  , InsId
                                  , ClaimCode
                                  , Amount
                                  , ProductCode
                                  , [Product]
                                  , HospitalCode
                                  , Hospital
                                  , ClaimAdmitTypeCode
                                  , ClaimAdmitType
                                  , ChiefComplainCode
                                  , ChiefComplain
                                  , ICD10Code
                                  , ICD10
                                  , ClaimOnLineCode
                                  , CustomerName
                                  , AdmitDate
                                  , SchoolName
                                  , GroupId
                                )
                                SELECT
                                        cm.ClaimHeaderGroupCode
                                        ,pd.ProductGroup_ID			ProductGroupId
                                        ,NULL						BranchCode
                                        ,cm.BranchId
                                        ,@ClaimGroupTypeId			ClaimGroupTypeId
                                        ,cm.InsuranceCompanyCode	InsCode
                                        ,ins.Organize_ID			InsId
                                        ,cm.ClaimMiscNo				ClaimCode
                                        ,ISNULL(cm.PayAmount, 0)	Amount
                                        ,cm.ProductCode
                                        ,pd.ProductGroupDetail		[Product]
                                        ,h.HospitalCode				HospitalCode
                                        ,h.HospitalName				Hospital
                                        ,NULL						ClaimAdmitTypeCode
                                        ,cxa.ClaimAdmitType			ClaimAdmitType
                                        ,NULL						ChiefComplainCode
                                        ,c.ChiefComplainName		ChiefComplain
                                        ,NULL						ICD10Code
                                        ,NULL						ICD10
                                        ,cm.ClaimOnLineCode
                                        ,cm.CustomerName
                                        ,cm.DateIn					AdmitDate
                                        ,NULL						SchoolName
                                        ,1							GroupId
                                FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
                                        LEFT JOIN [DataCenterV1].[Product].[ProductGroup] pd
                                                ON cm.ProductGroupId = pd.ProductGroup_ID
                                        LEFT JOIN  
                                                (
                                                        SELECT
                                                                HospitalId
                                                                ,HospitalName
                                                                ,HospitalCode
                                                        FROM [ClaimMiscellaneous].[misc].[Hospital]
                                                        WHERE IsActive = 1
                                                ) h
                                                ON h.HospitalId = cm.HospitalId
                                        LEFT JOIN
                                                (
                                                        SELECT
                                                                ChiefComplainId
                                                                ,ChiefComplainName
                                                        FROM [ClaimMiscellaneous].[misc].[ChiefComplain]
                                                        WHERE IsActive = 1
                                                ) c
                                                ON c.ChiefComplainId = cm.ChiefComplainId
                                        INNER JOIN #Tmplst lst
                                                ON cm.ClaimHeaderGroupCode = lst.Element
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
										LEFT JOIN 
										(
											SELECT 
												OrganizeCode
												,Organize_ID
											FROM [DataCenterV1].[Organize].[Organize]
											WHERE IsActive = 1
										) ins
											ON ins.OrganizeCode = cm.InsuranceCompanyCode
											
                                WHERE cm.IsActive = 1                                        
                                SELECT x.ClaimHeaderGroupCode
                                          ,x.ProductGroupId
                                          ,x.BranchCode
                                          ,x.BranchId			BranchId
                                          ,x.ClaimGroupTypeId
                                          ,x.InsCode
                                          ,x.InsId				InsId
                                          ,x.ClaimCode
                                          ,x.ClaimOnLineCode
                                          ,1					GroupId
                                INTO #TmpX2
                                FROM @TmpD x
                                INSERT INTO @TmpGroup
                                (
                                    ClaimGroupTypeId
                                  , BranchId
                                  , gId
                                  , sumPremium
                                  ,GroupId
                                )
                                SELECT @ClaimGroupTypeId	ClaimGroupTypeId
                                        , BranchId			BranchId
                                        , 1					gId
                                        , SUM(Amount)		sumPremium
                                        ,1
                                FROM @TmpD
                                GROUP BY ClaimGroupTypeId, BranchId
                                INSERT INTO @TmpH
                                (
									ClaimHeaderGroupCode
                                  , ClaimGroupTypeId
                                  , ProductGroupId
                                  , BranchId
                                  , InsId
                                  , ItemCount
                                  , SumAmount
                                  , ClaimOnLineCode
                                  , hId
                                  , HospitalCode
                                  ,GroupId
                                )
                                SELECT g.ClaimHeaderGroupCode
                                          ,g.ClaimGroupTypeId
                                          ,g.ProductGroupId
                                          ,g.BranchId
                                          ,g.InsId
                                          ,s.ItemCount
                                          ,s.SumAmount
                                          ,s.ClaimOnLineCode
                                          ,ROW_NUMBER() OVER(ORDER BY (g.ClaimHeaderGroupCode) asc ) hId
                                          ,s.HospitalCode
                                          ,GroupId
                                FROM
                                (
                                SELECT ClaimHeaderGroupCode
                                                ,ClaimGroupTypeId
                                          ,ProductGroupId
                                          ,BranchId
                                          ,InsId
                                          ,GroupId
                                FROM #TmpX2
                                GROUP BY ClaimHeaderGroupCode
                                                ,ClaimGroupTypeId
                                                ,ProductGroupId
                                                ,BranchId
                                                ,InsId
                                                ,GroupId
                                )g
                                LEFT JOIN
                                        (
                                                SELECT ClaimHeaderGroupCode
                                                                ,COUNT(ClaimCode)		ItemCount
                                                                ,SUM(Amount)			SumAmount
                                                                ,MAX(ClaimOnLineCode)	ClaimOnLineCode
                                                                ,HospitalCode
                                                FROM @TmpD
                                                GROUP BY ClaimHeaderGroupCode, HospitalCode
                                        )s
                                        ON g.ClaimHeaderGroupCode = s.ClaimHeaderGroupCode
			END
		ELSE
			BEGIN
			    
				SELECT x.ClaimHeaderGroupCode
					  ,x.ProductGroupId
					  ,x.BranchCode
					  ,b.Branch_ID			BranchId
					  ,x.ClaimGroupTypeId
					  ,x.InsCode
					  ,o.Organize_ID		InsId
					  ,x.ClaimCode
					  ,x.ClaimOnLineCode
					  ,CASE WHEN x.InsCode = @InsuranceCompanyCode AND x.CreatedDate >= @SMICutOffDate THEN 2
							--WHEN x.InsCode = @InsuranceCompanyCode AND @ClaimGroupTypeId = 4 THEN 2 AND @ClaimGroupTypeId = 2
						ELSE 1 END AS GroupId
				INTO #TmpX
				FROM
				( 
					SELECT 
							g.Code					ClaimHeaderGroupCode
							,@ProductGroupId_PH		ProductGroupId	--2PH 3PA
							,g.Branch_id			BranchCode
							,@ClaimGroupTypeId		ClaimGroupTypeId
							,g.InsuranceCompany_id	InsCode
							,i.ClaimHeader_id		ClaimCode
							,g.ClaimOnLineCode		ClaimOnLineCode
							,cl.CreatedDate	
	
					FROM sss.dbo.DB_ClaimHeaderGroupItem i
						INNER JOIN #Tmplst lst
							ON i.ClaimHeaderGroup_id = lst.Element
						INNER JOIN sss.dbo.DB_ClaimHeaderGroup g
							ON lst.Element = g.Code
						INNER JOIN sss.dbo.DB_ClaimHeader cl
						ON cl.Code = i.ClaimHeader_id
	
				UNION ALL
	
				SELECT
						g.Code					ClaimHeaderGroupCode
						,@ProductGroupId_PA		ProductGroupId	--2PH 3PA
						,g.Branch_id			BranchCode
						,CASE   
							WHEN @ClaimGroupTypeId = 3 AND ISNULL(g.IsClaimOnLine,0) = 0 THEN 3
							WHEN @ClaimGroupTypeId = 6 AND ISNULL(g.IsClaimOnLine,0) = 1 THEN 6 -- Krekpon.D 20250811 Update ClaimGroupType 6 When is PA
							WHEN ISNULL(g.IsClaimOnLine,0) = 1 THEN 2
							WHEN @ClaimGroupTypeId = 4 THEN 4
						 END ClaimGroupTypeId
						,g.InsuranceCompany_id	InsCode
						,i.ClaimHeader_id		ClaimCode
						,g.ClaimOnLineCode		ClaimOnLineCode
						,cl.CreatedDate
	
				FROM ssspa.dbo.DB_ClaimHeaderGroupItem i
					INNER JOIN #Tmplst lst
						ON i.ClaimHeaderGroup_id = lst.Element
					INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup g
						ON lst.Element = g.Code
					INNER JOIN SSSPA.dbo.DB_ClaimHeader cl
					ON cl.Code = i.ClaimHeader_id
				)x
					LEFT JOIN DataCenterV1.Organize.Organize o
						ON x.InsCode = o.OrganizeCode
					LEFT JOIN DataCenterV1.Address.Branch b
						ON x.BranchCode = b.tempcode;
	
	
				INSERT INTO @TmpD
				(
				    ClaimHeaderGroupCode
				  , ProductGroupId
				  , BranchCode
				  , BranchId
				  , ClaimGroupTypeId
				  , InsCode
				  , InsId
				  , ClaimCode
				  , Amount
				  , ProductCode
				  , [Product]
				  , HospitalCode
				  , Hospital
				  , ClaimAdmitTypeCode
				  , ClaimAdmitType
				  , ChiefComplainCode
				  , ChiefComplain
				  , ICD10Code
				  , ICD10
				  , ClaimOnLineCode
				  , CustomerName
				  ,	AdmitDate
				  ,	SchoolName 
				  ,GroupId
				)
				SELECT d.ClaimHeaderGroupCode
					  ,d.ProductGroupId
					  ,d.BranchCode
					  ,d.BranchId
					  ,d.ClaimGroupTypeId
					  ,d.InsCode
					  ,d.InsId
					  ,d.ClaimCode
					  ,d.Amount
					  ,d.ProductCode
					  ,d.[Product]
					  ,d.HospitalCode
					  ,d.Hospital
					  ,d.ClaimAdmitTypeCode
					  ,d.ClaimAdmitType
					  ,d.ChiefComplainCode
					  ,d.ChiefComplain
					  ,d.ICD10Code
					  ,d.ICD10
					  ,d.ClaimOnLineCode
					  ,d.CustomerName
					  ,d.AdmitDate
					  ,d.SchoolName 
					  ,d.GroupId
				FROM
				(
					SELECT 
							 lst.ClaimHeaderGroupCode
							,lst.ProductGroupId
							,lst.BranchCode
							,lst.BranchId
							,lst.ClaimGroupTypeId
							,lst.InsCode
							,lst.InsId
							,lst.ClaimCode
							--,(ISNULL(cv.Pay,0) + ISNULL(cv.Compensate_net,0) ) Amount
							--,IIF(ISNULL(cv.net,0) <> 0 ,ISNULL(cv.Pay_Total,0),ISNULL(cv.Compensate_net,0))  Amount  --เงื่อนไขใน บส.  ปรับให้ออกเหมือน บส. คอนเฟริมกับพี่โบว์แล้ว
							,ISNULL(cv.PaySS_Total,0)   Amount  -- เปลี่ยนไปใช้ PaySS_Total รวมหักส่วนลดแล้ว 20231227
							,cl.Product_id				ProductCode
							,p.Detail					[Product]
							,cl.Hospital_id				HospitalCode
							,hos.Detail					Hospital
							,cl.ClaimAdmitType_id		ClaimAdmitTypeCode
							,cat.Detail					ClaimAdmitType
							,cl.ChiefComplain_id		ChiefComplainCode
							,ccp.Detail					ChiefComplain
							,cl.ICD10_1					ICD10Code
							,icd.Detail_Thai			ICD10
							,lst.ClaimOnLineCode		ClaimOnLineCode	
							,ci.AdmitDate				AdmitDate								--Update Chanadol 2023-12-07
							,CONCAT(tt.Detail, cm.FirstName, ' ', cm.LastName)	 AS CustomerName --Update Chanadol 2023-12-07
							,NULL						SchoolName
							--,IIF(lst.InsCode ='100000000004' AND cl.CreatedDate <'2024-08-01', 1, 2) GroupId
							,CASE WHEN lst.InsCode = @InsuranceCompanyCode AND cl.CreatedDate >= @SMICutOffDate  THEN 2
								  --WHEN lst.InsCode =@InsuranceCompanyCode AND @ClaimGroupTypeId =4 THEN 2 AND @ClaimGroupTypeId = 2
							ELSE 1 END AS GroupId
					FROM sss.dbo.DB_ClaimHeader cl
						INNER JOIN sss.dbo.DB_ClaimVoucher cv
							ON cl.Code = cv.Code
						INNER JOIN 
							(
								SELECT ClaimHeaderGroupCode
									  ,ProductGroupId
									  ,BranchCode
									  ,BranchId
									  ,ClaimGroupTypeId
									  ,InsCode
									  ,InsId
									  ,ClaimCode
									  ,ClaimOnLineCode
								FROM #TmpX
								WHERE ProductGroupId = 2
							)lst
							ON cl.Code = lst.ClaimCode
						LEFT JOIN sss.dbo.MT_Product p
							ON cl.Product_id = p.Code
						LEFT JOIN sss.dbo.MT_Company hos
							ON cl.Hospital_id = hos.Code
						LEFT JOIN sss.dbo.MT_ClaimAdmitType cat
							ON cl.ClaimAdmitType_id = cat.Code
						LEFT JOIN sss.dbo.MT_ChiefComplain ccp
							ON cl.ChiefComplain_id = ccp.Code
						LEFT JOIN SSS.dbo.MT_ICD10 icd
							ON cl.ICD10_1 = icd.Code
						-- Update Chanadol 2023-12-07
						LEFT JOIN SSS.dbo.DB_ClaimInvoice ci
							ON cl.Code = ci.ClaimHeader_id
						LEFT JOIN SSS.dbo.DB_Customer     cm
							ON cl.App_id = cm.App_id
						LEFT JOIN SSS.dbo.MT_Title        tt
							ON cm.Title_id = tt.Code
	
					UNION ALL
	
					SELECT 
							 lst.ClaimHeaderGroupCode
							,lst.ProductGroupId
							,lst.BranchCode
							,lst.BranchId
							,lst.ClaimGroupTypeId
							,lst.InsCode
							,lst.InsId
							,lst.ClaimCode
							--,ISNULL(cl.Amount_Net,0)	Amount
							,ISNULL(cl.PaySS_Total,0)	Amount -- 20231227
							,cl.Product_id				ProductCode
							,pp.Detail					[Product]
							,cl.Hospital_id				HospitalCode
							,hos.Detail					Hospital	
							,cl.ClaimType_id			ClaimAdmitTypeCode
							,clt.Detail					ClaimAdmitType
							,cl.AccidentCause_id		ChiefComplainCode
							,adc.Detail					ChiefComplain		
							,cl.ICD10_1					ICD10Code
							,icd.Detail_Thai			ICD10	
							,lst.ClaimOnLineCode		ClaimOnLineCode	
							,cl.DateIn					AdmitDate									--Update Chanadol 2023-12-07
							,CONCAT(tt.Detail, cd.FirstName, ' ', cd.LastName)	 AS CustomerName	--Update Chanadol 2023-12-07
							,CONCAT(ISNULL(c.CompanyTitle, ''), c.Detail)		 AS SchoolName	
							--,IIF(lst.InsCode ='100000000004' AND cl.CreatedDate <'2024-08-01', 1, 2) GroupId
							,CASE WHEN lst.InsCode =@InsuranceCompanyCode AND cl.CreatedDate >= @SMICutOffDate   THEN 2
								  -- WHEN lst.InsCode =@InsuranceCompanyCode AND @ClaimGroupTypeId = 4 THEN 2 AND @ClaimGroupTypeId = 2
							ELSE 1 END AS GroupId
					FROM SSSPA.dbo.DB_ClaimHeader cl
						INNER JOIN 
							(
								SELECT ClaimHeaderGroupCode
									  ,ProductGroupId
									  ,BranchCode
									  ,BranchId
									  ,ClaimGroupTypeId
									  ,InsCode
									  ,InsId
									  ,ClaimCode
									  ,ClaimOnLineCode
								FROM #TmpX
								WHERE ProductGroupId = 3
							)lst
							ON cl.Code = lst.ClaimCode
						LEFT JOIN ssspa.dbo.SM_Code clt
							ON cl.ClaimType_id = clt.Code
						LEFT JOIN ssspa.dbo.MT_AccidentCause adc
							ON cl.AccidentCause_id = adc.Code
						--LEFT JOIN ssspa.dbo.vw_ICD10 icd
						--	ON cl.ICD10_1 = icd.Code
						LEFT JOIN SSS.dbo.MT_ICD10 icd
							ON cl.ICD10_1 = icd.Code
						LEFT JOIN sss.dbo.MT_Company hos
							ON cl.Hospital_id = hos.Code
						LEFT JOIN ssspa.dbo.MT_Product pp
							ON cl.Product_id =pp.Code
						--Update Chanadol 2023-12-07
						LEFT JOIN SSSPA.dbo.DB_CustomerDetail   cd
							ON cl.CustomerDetail_id = cd.Code
						LEFT JOIN SSSPA.dbo.MT_Title      tt
							ON cd.Title_id = tt.Code
						LEFT JOIN ssspa.dbo.DB_Customer			cm
							ON cd.Application_id = cm.App_id
						LEFT JOIN SSSPA.dbo.MT_Company c
							ON cm.School_id = c.Code
					)d;
	
					
					INSERT INTO @TmpGroup
					(
					    ClaimGroupTypeId
					  , BranchId
					  , gId
					  , sumPremium
					  ,GroupId
					)
					SELECT DISTINCT h.ClaimGroupTypeId
						  ,h.BranchId
						  ,s.gId
						  ,s.sumPremium
						  ,s.GroupId
					FROM
					(
						SELECT ClaimGroupTypeId
							  ,BranchId
							  ,GroupId
							  --,ROW_NUMBER() OVER(ORDER BY ClaimGroupTypeId ASC,BranchId ASC ) gId
						FROM #TmpX
						--GROUP BY ClaimGroupTypeId,BranchId
					)h
					LEFT JOIN 
						(
							--SELECT ClaimGroupTypeId,BranchId,SUM(Amount) sumPremium
							SELECT 
								ClaimGroupTypeId
								,BranchId
								,SUM(Amount) sumPremium
								,GroupId
								,ROW_NUMBER() OVER(ORDER BY ClaimGroupTypeId ASC,BranchId ASC ) gId
							FROM @TmpD
							GROUP BY ClaimGroupTypeId, BranchId, GroupId
						)s
							ON  h.ClaimGroupTypeId = s.ClaimGroupTypeId
								AND h.BranchId = s.BranchId;	
	
			--เคลมออนไลน์ ไม่ต้อง save HospitalCode Update --2023-12-12
			IF @ClaimGroupTypeId <> 2
				BEGIN
					    INSERT INTO @TmpH
						(
							ClaimHeaderGroupCode
						  , ClaimGroupTypeId
						  , ProductGroupId
						  , BranchId
						  , InsId
						  , ItemCount
						  , SumAmount
						  , ClaimOnLineCode
						  , hId
						  , HospitalCode
						  ,GroupId
						)
						SELECT g.ClaimHeaderGroupCode
							  ,g.ClaimGroupTypeId
							  ,g.ProductGroupId
							  ,g.BranchId
							  ,g.InsId
							  ,s.ItemCount
							  ,s.SumAmount
							  ,s.ClaimOnLineCode
							  ,ROW_NUMBER() OVER(ORDER BY (g.ClaimHeaderGroupCode) asc ) hId
							  ,s.HospitalCode
							  ,GroupId
						FROM
						(
						SELECT ClaimHeaderGroupCode
								,ClaimGroupTypeId
							  ,ProductGroupId
							  ,BranchId
							  ,InsId
							  ,GroupId
						FROM #TmpX
						GROUP BY ClaimHeaderGroupCode
								,ClaimGroupTypeId
								,ProductGroupId
								,BranchId
								,InsId
								,GroupId
						)g
						LEFT JOIN 
							(
								SELECT ClaimHeaderGroupCode
										,COUNT(ClaimCode)	ItemCount
										,SUM(Amount)		SumAmount
										,MAX(ClaimOnLineCode) ClaimOnLineCode
										,HospitalCode
								FROM @TmpD
								GROUP BY ClaimHeaderGroupCode, HospitalCode
							)s
							ON g.ClaimHeaderGroupCode = s.ClaimHeaderGroupCode
				END
				ELSE	
				BEGIN
				    INSERT INTO @TmpH
					(
						ClaimHeaderGroupCode
					  , ClaimGroupTypeId
					  , ProductGroupId
					  , BranchId
					  , InsId
					  , ItemCount
					  , SumAmount
					  , ClaimOnLineCode
					  , hId
					  ,GroupId
					)
					SELECT g.ClaimHeaderGroupCode
						  ,g.ClaimGroupTypeId
						  ,g.ProductGroupId
						  ,g.BranchId
						  ,g.InsId
						  ,s.ItemCount
						  ,s.SumAmount
						  ,s.ClaimOnLineCode
						  ,ROW_NUMBER() OVER(ORDER BY (g.ClaimHeaderGroupCode) asc ) hId
						  ,GroupId
					FROM
					(
					SELECT ClaimHeaderGroupCode
							,ClaimGroupTypeId
						  ,ProductGroupId
						  ,BranchId
						  ,InsId
						  ,GroupId
					FROM #TmpX
					GROUP BY ClaimHeaderGroupCode
							,ClaimGroupTypeId
							,ProductGroupId
							,BranchId
							,InsId
							,GroupId
					)g
						LEFT JOIN 
							(
								SELECT ClaimHeaderGroupCode
										,COUNT(ClaimCode)	ItemCount
										,SUM(Amount)		SumAmount
										,MAX(ClaimOnLineCode) ClaimOnLineCode
								FROM @TmpD
								GROUP BY ClaimHeaderGroupCode
							)s
							ON g.ClaimHeaderGroupCode = s.ClaimHeaderGroupCode
				END
			END		
		
	--Group
		DECLARE @g_TransactionCodeControlTypeDetail varchar(6) = 'CPBG'
		DECLARE @g_Total int
		DECLARE @g_YY varchar(2)
		DECLARE @g_MM varchar(2)
		DECLARE @g_RunningFrom int
		DECLARE @g_RunningTo INT
		DECLARE @g_lenght	INT = 6
		SELECT @g_Total = MAX(gId) 

		FROM @TmpGroup;
	
		EXECUTE [dbo].[usp_GenerateCode_FromTo] 
		   @g_TransactionCodeControlTypeDetail
		  ,@g_Total
		  ,@g_YY OUTPUT
		  ,@g_MM OUTPUT
		  ,@g_RunningFrom OUTPUT
		  ,@g_RunningTo OUTPUT
	
		--Header
		DECLARE @h_TransactionCodeControlTypeDetail varchar(6) = 'CPBH'
		DECLARE @h_Total int
		DECLARE @h_YY varchar(2)
		DECLARE @h_MM varchar(2)
		DECLARE @h_RunningFrom int
		DECLARE @h_RunningTo INT
		DECLARE @h_lenght	INT = 6
		SELECT @h_Total = MAX(hId)
		FROM @TmpH
	
		EXECUTE [dbo].[usp_GenerateCode_FromTo] 
		   @h_TransactionCodeControlTypeDetail
		  ,@h_Total
		  ,@h_YY OUTPUT
		  ,@h_MM OUTPUT
		  ,@h_RunningFrom OUTPUT
		  ,@h_RunningTo OUTPUT
	
		DECLARE @TmpOutGroup TABLE(ClaimGroupTypeId	INT,BranchId	INT,gId	INT,GroupId INT, ClaimPayBackCode VARCHAR(20))
		DECLARE @TmpOutD TABLE (ClaimHeaderGroupCode VARCHAR(50),cdId INT,ClaimPayBackId INT, ClaimCode VARCHAR(20),InsuranceCompanyId INT)
		DECLARE @TmpOutXClaim TABLE (ClaimCode VARCHAR(30),cxId INT,cdId INT) --Kittisak.Ph 2024-04-05
	
		-----------------------------------
		-- start process recheck
		DECLARE @CountDuplicateClaim INT;

		SELECT @CountDuplicateClaim = COUNT(pb.ClaimGroupCode)
		FROM dbo.ClaimPayBackDetail  pb
			INNER JOIN #Tmplst lstrS
				ON (pb.ClaimGroupCode = lstrS.Element)
		WHERE pb.IsActive = 1;
		IF @CountDuplicateClaim IS NULL SET @CountDuplicateClaim = 0;
	
		IF @CountDuplicateClaim > 0
		BEGIN
			SET @IsResult = 0
			SET @Msg = 'ClaimHeaderGroupCode Data Duplicate'
		END	


----------------Kittisak.Ph 2024-04-05-------------------------------------------
	--เคลมออนไลน์
	IF @ClaimGroupTypeId = 2				--Update Chanadol 2025-02-26 
	BEGIN

	DECLARE @roundAmount INT = 5;
	DECLARE @lastNumber INT;
	DECLARE @startNumber INT;
	DECLARE @total INT;
	
	SELECT TOP 1 @lastNumber = cw.RoundNo
	FROM [ClaimOnlineV2].[dbo].ClaimWithdrawal cw
	WHERE cw.ClaimPayBackXClaimCreatedDate = (
		SELECT MAX(ClaimPayBackXClaimCreatedDate)
		FROM [ClaimOnlineV2].[dbo].ClaimWithdrawal
	)
	ORDER BY cw.RoundNo DESC;

	SELECT @total = COUNT(ClaimCode) from @TmpD

	--SELECT @lastNumber lastNumber
	SET @startNumber = ISNULL(@lastNumber, 0) + 1;
	--SELECT @startNumber
		
		--ปรับ IsActive รายการที่ส่งตั้งเบิกครั้งก่อน 2025-11-12 By Kittisak.Ph
		UPDATE cwd
		SET cwd.IsActive=0
		FROM ClaimOnlineV2.dbo.ClaimWithdrawal cwd
		INNER JOIN @TmpD tmpd 
		ON tmpd.ClaimCode = cwd.ClaimCode

	    INSERT INTO @TmpXClaim(
			ClaimOnLineId 
			,ClaimOnLineItemId 
			,ClaimCode 
			,ClaimPay 
			,ClaimPayBackXClaimCreatedByUserId 
			,ClaimPayBackXClaimCreatedDate 
			,RoundNo
		)
		SELECT
			ci.ClaimOnLineId
			,ci.ClaimOnLineItemId
			,d.ClaimCode
			,d.Amount ClaimPay
			,@CreatedByUserId AS ClaimPayBackXClaimCreatedByUserId
			,@D ClaimPayBackXClaimCreatedDate
			,(( (@startNumber - 1) + (ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1) ) % @roundAmount) + 1
		FROM @TmpD d
			INNER JOIN ClaimOnlineV2.dbo.ClaimOnlineItem ci
				ON d.ClaimCode = ci.ClaimCode
		WHERE ci.IsActive = 1
		--left JOIN vw_ClaimOnlineItem vcol ON vcol.ClaimCode =d.ClaimCode
	END
	ELSE	
	BEGIN
	    INSERT INTO @TmpXClaim(
			ClaimOnLineId 
			,ClaimOnLineItemId 
			,ClaimCode 
			,ClaimPay 
			,ClaimPayBackXClaimCreatedByUserId 
			,ClaimPayBackXClaimCreatedDate 
		)
		SELECT
			NULL
			,NULL
			,d.ClaimCode
			,d.Amount ClaimPay
			,@CreatedByUserId AS ClaimPayBackXClaimCreatedByUserId
			,@D ClaimPayBackXClaimCreatedDate
	FROM @TmpD d
	END
	
---------------------------------------------------------------------------------
	
		IF @IsResult = 1
		BEGIN
	    
	
		-----------------------------------
		BEGIN TRY
			Begin TRANSACTION
	
	
				INSERT INTO dbo.ClaimPayBack
						(ClaimPayBackCode
						,Amount
						,ClaimPayBackStatusId
						,ClaimGroupTypeId
						,BranchId
						,ClaimPayBackTransferId
						,IsActive
						,CreatedByUserId
						,CreatedDate
						,UpdatedByUserId
						,UpdatedDate
						,GroupId
						)
				OUTPUT Inserted.ClaimGroupTypeId,Inserted.BranchId,Inserted.ClaimPayBackId,Inserted.GroupId,Inserted.ClaimPayBackCode INTO @TmpOutGroup(ClaimGroupTypeId,BranchId,gId,GroupId,ClaimPayBackCode) --Update Chanadol 20241112
				SELECT 
						CONCAT(@g_TransactionCodeControlTypeDetail,@g_YY,@g_MM ,dbo.func_ConvertIntToString((@g_RunningFrom + ig.gId - 1),@g_lenght)) Code
						,ig.sumPremium
						--,2
						,IIF(ig.GroupId = 2, 5, 2)
						,ig.ClaimGroupTypeId
						,ig.BranchId
						,NULL
						,1
						,@CreatedByUserId
						,@D
						,@CreatedByUserId
						,@D
						,ig.GroupId
				FROM @TmpGroup ig
				ORDER BY ig.gId;
			
			
				INSERT INTO dbo.ClaimPayBackDetail
						(ClaimPayBackDetailCode
						,ClaimPayBackId
						,ClaimGroupCode
						,ItemCount
						,Amount
						,ProductGroupId
						,InsuranceCompanyId
						,CancelRemark
						,IsActive
						,CreatedByUserId
						,CreatedDate
						,UpdatedByUserId
						,UpdatedDate
						,ClaimOnLineCode
						,HospitalCode
						)
				OUTPUT Inserted.ClaimGroupCode,Inserted.ClaimPayBackDetailId,Inserted.ClaimPayBackId,Inserted.InsuranceCompanyId INTO @TmpOutD (ClaimHeaderGroupCode,cdId,ClaimPayBackId,InsuranceCompanyId)
				SELECT	
						CONCAT(@h_TransactionCodeControlTypeDetail,@h_YY,@h_MM ,dbo.func_ConvertIntToString((@h_RunningFrom + h.hId - 1),@h_lenght)) Code
						,o.gId
						,h.ClaimHeaderGroupCode
						,h.ItemCount
						,h.SumAmount
						,h.ProductGroupId
						,h.InsId
						,NULL
						,1
						,@CreatedByUserId
						,@D
						,@CreatedByUserId
						,@D
						,h.ClaimOnLineCode
						,h.HospitalCode
				FROM @TmpH h
					LEFT JOIN @TmpOutGroup o
						ON h.ClaimGroupTypeId = o.ClaimGroupTypeId
						AND h.BranchId = o.BranchId AND o.GroupId = h.GroupId
				ORDER BY h.hId;
			
			
				INSERT INTO dbo.ClaimPayBackXClaim
						(ClaimPayBackDetailId
						,ClaimCode
						,ProductCode
						,ProductName
						,HospitalCode
						,HospitalName
						,ClaimAdmitTypeCode
						,ClaimAdmitType
						,ChiefComplainCode
						,ChiefComplain
						,ICD10Code
						,ICD10
						,ClaimPay
						,ClaimTransfer
						,IsActive
						,CreatedByUserId
						,CreatedDate
						,UpdatedByUserId
						,UpdatedDate
						,CustomerName
						,AdmitDate
						,SchoolName)
						OUTPUT Inserted.ClaimCode,Inserted.ClaimPayBackXClaimId,Inserted.ClaimPayBackDetailId INTO @TmpOutXClaim (ClaimCode,cxId,cdId) --Kittisak.Ph 2024-04-05
				SELECT o.cdId
						,d.ClaimCode
						,d.ProductCode
						,d.[Product]
						,d.HospitalCode
						,d.Hospital
						,d.ClaimAdmitTypeCode
						,d.ClaimAdmitType
						,d.ChiefComplainCode
						,d.ChiefComplain
						,d.ICD10Code
						,d.ICD10
						,d.Amount
						,0
						,1
						,@CreatedByUserId
						,@D
						,@CreatedByUserId
						,@D
						,d.CustomerName				
						,d.AdmitDate
						,d.SchoolName
				FROM @TmpD d
					LEFT JOIN @TmpOutD o
						ON d.ClaimHeaderGroupCode = o.ClaimHeaderGroupCode
				ORDER BY o.cdId;
	
----------------Kittisak.Ph 2024-04-05-------------------------------------------
--บันทึกสถานะส่งตั้งเบิกเฉพาะเคลมออนไลน์ 
	IF @ClaimGroupTypeId = 2				--Update Kittisak.Ph 2025-02-25 
	BEGIN

		INSERT INTO [ClaimOnlineV2].[dbo].[ClaimWithdrawal]
		(
		[ClaimWithdrawalId]
      ,[ClaimOnLineId]
      ,[ClaimOnLineItemId]
      ,[ClaimPayBackXClaimId]
      ,[ClaimCode]
      ,[ClaimPay]
      ,[IsActive]
      ,[ClaimPayBackXClaimCreatedByUserId]
      ,[ClaimPayBackXClaimCreatedDate]
      ,[RoundNo]
	  )
		SELECT NEWID()
		,ClaimOnLineId
			,ClaimOnLineItemId
			,x.cxId
			,tx.ClaimCode
			,tx.ClaimPay
			,1
			,ClaimPayBackXClaimCreatedByUserId
			,ClaimPayBackXClaimCreatedDate
			,tx.RoundNo
		FROM @TmpXClaim tx
		LEFT JOIN @TmpOutXClaim x ON tx.ClaimCode = x.ClaimCode

	END

---------------------------------------------------------------------------------

------------------------------------- Krekpon.D Mind 06588 2024-06-27 -------------------------------------------
	IF @ClaimGroupTypeId = 4
		BEGIN
				INSERT INTO [dbo].[ClaimPayBackDetailReport]
		           ([ClaimGroupCode]
		           ,[HospitalName]
		           ,[ClaimCode]
		           ,[CustomerName]
		           ,[Amount]
		           ,[SendDate]
		           ,[PaymentDate]
		           ,[ClaimGroupTypeId]
		           ,[IsActive]
		           ,[CreatedByUserId]
		           ,[CreatedDate]
		           ,[UpdatedByUserId]
		           ,[UpdatedDate])
				SELECT  claimD.Code AS ClaimGroupCode,
							sssHospital.Detail AS HospitalName,
							claimD.CLCode AS ClaimCode,
							claimD.CustomerName AS CustomerName,
							claimD.Amount AS Amount,
							GETDATE()  AS SendDate,
							NULL AS PaymentDate,
							@ClaimGroupTypeId AS ClaimGroupTypeId,
							1 AS IsActive,
							@CreatedByUserId AS CreatedByUserId,
							GETDATE() AS CreatedDate,
							@CreatedByUserId AS UpdatedByUserId,
							GETDATE() AS UpdatedDate
					 FROM (
					
							SELECT chg.Code AS Code
								, chg.Hospital_id AS Hospital_id
								, sch.Code AS CLCode
								, scv.PaySS_Total AS Amount
								,CONCAT(mtt.Detail, cust.FirstName, ' ' , cust.LastName ) AS CustomerName
							 
					        FROM sss.dbo.DB_ClaimHeaderGroup chg
					         INNER JOIN sss.dbo.DB_ClaimHeader sch
								ON chg.code = sch.ClaimHeaderGroup_id 
					         INNER JOIN sss.dbo.DB_Customer cust
								ON sch.App_id = cust.App_id
					         INNER JOIN sss.dbo.MT_Title mtt
								ON cust.Title_id = mtt.Code
					         INNER JOIN sss.dbo.DB_ClaimVoucher scv
								ON sch.code = scv.Code
							 INNER JOIN #Tmplst tchc
								ON chg.Code = tchc.Element
				
					        UNION ALL
					
					        SELECT pachg.Code AS Code
					         , pachg.Hospital_id AS Hospital_id
					         , pach.Code AS CLCode
							 , pach.PaySS_Total AS Amount
					         ,CONCAT(pamtt.Detail, pacustd.FirstName, ' ' , pacustd.LastName ) AS CustomerName
				
					        FROM SSSPA.dbo.DB_ClaimHeaderGroup pachg
								INNER JOIN SSSPA.dbo.DB_ClaimHeader pach
									ON pachg.Code = pach.ClaimheaderGroup_id
								INNER JOIN SSSPA.dbo.DB_CustomerDetail pacustd
									ON pach.CustomerDetail_id = pacustd.Code
								INNER JOIN SSSPA.dbo.MT_Title pamtt
									ON pacustd.Title_id = pamtt.Code
								INNER JOIN #Tmplst tchc
									ON pachg.Code = tchc.Element 
						) claimD
							INNER JOIN SSS.dbo.MT_Company sssHospital
								ON claimD.Hospital_id = sssHospital.Code
				
					IF OBJECT_ID('tempdb..#TmpClaimHeaderCode') IS NOT NULL  DROP TABLE #TmpClaimHeaderCode;
					
			END		
-----------------------------------------------------------------------------------------------------------

			SET @IsResult	= 1;
			SET @Msg		= 'บันทึก สำเร็จ';
	
			COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
	
			SET @IsResult	= 0;
			SET @Msg		= ERROR_MESSAGE()
	
			IF @@Trancount > 0 ROLLBACK;
		END CATCH

		END
	END


	IF @IsResult = 1 BEGIN	SET @Result = IIF(1=0,1,0) END	
	ELSE BEGIN				SET @Result = 'Failure' END;	

	--SELECT @IsResult IsResult
	--		,@Result Result
	--		,@Msg	 Msg; 

	SELECT DISTINCT @IsResult IsResult
		,@Result Result
		,@Msg	 Msg
		,txc.ClaimOnLineId
		,txc.ClaimOnLineItemId
		,tog.ClaimPayBackCode
		,tod.ClaimHeaderGroupCode   ClaimGroupCode
		,toc.cxId					ClaimPayBackXClaimId
		,txc.ClaimCode
		,txc.ClaimPay
		,5 AS ReceiveTypeId
		,9 AS TransferTypeId ----SMI โอนให้ลูกค้า
		,tod.InsuranceCompanyId
		,@CreatedByUserId AS UpdatedByUserId		
		,@D AS UpdatedDate 
	FROM @TmpOutGroup tog
	LEFT JOIN @TmpOutD tod
		ON tog.gId = tod.ClaimPayBackId AND	tod.InsuranceCompanyId = @InsuranceCompanyId
	LEFT JOIN @TmpOutXClaim toc
		ON tod.cdId = toc.cdId
	LEFT JOIN @TmpXClaim txc
		ON toc.ClaimCode = txc.ClaimCode
	--INNER JOIN dbo.vw_ClaimOnlineItem vcol
	--	ON txc.ClaimCode = vcol.ClaimCode
	--WHERE tod.InsuranceCompanyId = @InsuranceCompanyId

	IF OBJECT_ID('tempdb..#TmpX') IS NOT NULL  DROP TABLE #TmpX;	
	IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;	
	IF OBJECT_ID('tempdb..#TmpX2') IS NOT NULL  DROP TABLE #TmpX2;

	IF OBJECT_ID('tempdb..@TmpH') IS NOT NULL  DELETE FROM @TmpH;	
	IF OBJECT_ID('tempdb..@TmpGroup') IS NOT NULL  DELETE FROM @TmpGroup;	
	IF OBJECT_ID('tempdb..@TmpD') IS NOT NULL  DELETE FROM @TmpD;

	--DECLARE @N INT = NULL;
	--DECLARE @G UNIQUEIDENTIFIER
	--DECLARE @DE DECIMAL(16, 2)

	--SELECT DISTINCT @IsResult IsResult
	--	,@Result Result
	--	,@Msg	 Msg
	--	,@G ClaimOnLineId
	--	,@G ClaimOnLineItemId
	--	,'' ClaimPayBackCode
	--	,'' ClaimGroupCode
	--	,@N	ClaimPayBackXClaimId
	--	,''	ClaimCode
	--	,@DE ClaimPay
	--	,1 ReceiveTypeId
	--	,1 TransferTypeId
	--	,@N InsuranceCompanyId
	--	,1 UpdatedByUserId		
	--	,@D AS UpdatedDate 

	END

