USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [Claim].[usp_ClaimHeaderGroupDetail_SelectV3]    Script Date: 11/12/2568 11:16:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO



-- =============================================
-- Author:		Sahatsawat golffy 06958 (อ้างอิง usp_ClaimHeaderGroupDetail_SelectV2)
-- Create date: 20230920
-- Update date: 2023-12-01 update Chanadol koonkam Check Itemcount in claimcompensategroup
--				2023-12-26 Update add IPD (H) & Day Case (H) to ClaimHospital
--				2024-01-11 Update OpdDateCutoff,IpdDateCutoff
--				2024-01-15 Add New @CutoffEndDate
-- Description:	Add ClaimHospital and ClaimCompensate
-- =============================================
ALTER PROCEDURE [Claim].[usp_ClaimHeaderGroupDetail_SelectV3]
	 @ProductGroupId		INT 	 
	,@InsuranceId			INT				= NULL	
	,@ClaimGroupTypeId		INT				= NULL	  
	,@BranchId				INT				= NULL	
	,@CreateByUser_Code		VARCHAR(20)		= NULL

	,@IndexStart			INT				= NULL	
	,@PageSize				INT				= NULL
	,@SortField				NVARCHAR(MAX)	= NULL
	,@OrderType				NVARCHAR(MAX)	= NULL
	,@SearchDetail			NVARCHAR(MAX)	= NULL 
	,@IsShowDocumentLink	BIT				= NULL
	,@ProductTypeId			INT				= NULL

AS
BEGIN

	EXECUTE [Claim].[usp_ClaimHeaderGroupDetail_SelectV4] @ProductGroupId,@InsuranceId,@ClaimGroupTypeId,@BranchId,@CreateByUser_Code,@IndexStart,@PageSize,@SortField,@OrderType,@SearchDetail,@IsShowDocumentLink,@ProductTypeId;	

	--Old Version 2024-02-22 Kittisak.Ph
	--DECLARE @pInsCode				VARCHAR(20);	
	--DECLARE @pBranchCode			VARCHAR(20);	
	--DECLARE @pProductGroupId		INT				= @ProductGroupId;
	--DECLARE @pClaimGroupTypeId		INT				= @ClaimGroupTypeId;
	--DECLARE @pIsShowDocumentLink	BIT				= @IsShowDocumentLink;
	--DECLARE @pCreateByUserCode		VARCHAR(20)		= @CreateByUser_Code

	--DECLARE @pIndexStart			INT				= @IndexStart;
	--DECLARE @pPageSize				INT				= @PageSize;
	--DECLARE @pSortField				NVARCHAR(MAX)	= @SortField;
	--DECLARE @pOrderType				NVARCHAR(MAX)	= @OrderType;
	--DECLARE @pSearchDetail			NVARCHAR(MAX)	= LTRIM(RTRIM(REPLACE(@SearchDetail, '', '')));	

	--DECLARE @Tmplst TABLE (
	--	ClaimHeaderGroup_id VARCHAR(30),
	--	ClaimHeader_id VARCHAR(20),
	--	ProductGroup_id INT,
	--	Branch_id VARCHAR(20),
	--	CreatedBy_id VARCHAR(20),
	--	CreatedDate DATETIME,
	--	InsuranceCompany_id VARCHAR(20),
	--	IsClaimOnLine BIT,
	--	InsuranceCompany_Name NVARCHAR(300),
	--	rwId INT
	--	--ClaimCompensateCode VARCHAR(20)
	--);

	--DECLARE @TmpClaim TABLE (
	--	ClaimHeaderGroup_id VARCHAR(30),
	--	ClaimHeader_id VARCHAR(20),
	--	Amount DECIMAL(16, 2)
	--);

	--DECLARE @TmpDoc TABLE (
	--	ClaimHeaderGroup_id VARCHAR(30),
	--	ClaimHeader_id VARCHAR(20)
	--);

	--DECLARE @CreatedDateFrom DATE = '2023-11-27';
	--DECLARE @CreateDateFromClaimHosAndClaimComp DATE = '2023-12-08';  --update Chanadol 2023-10-31 up Prod enter DateNow
	--DECLARE @OpdDateCutoff DATE ='2023-12-08';
	--DECLARE @IpdDateCutoff DATE ='2023-10-26';
	--DECLARE @CutoffEndDate DATE = '2024-01-09'  --Uporod 9-1-2024

	--IF @InsuranceId IS NOT NULL	
	--	BEGIN
	--		SELECT @pInsCode = OrganizeCode 
	--		FROM DataCenterV1.Organize.Organize 
	--		WHERE Organize_ID = @InsuranceId;
	--	END

	--IF @BranchId IS NOT NULL	
	--	BEGIN
	--		SELECT @pBranchCode = tempcode 
	--		FROM DataCenterV1.Address.Branch 
	--		WHERE Branch_ID = @BranchId;
	--	END

	------------------------------------------------------------------------------
	--IF @pIndexStart		IS NULL	SET @pIndexStart	= 0;
	--IF @pPageSize		IS NULL	SET @pPageSize		= 10;
	--IF @pSearchDetail	IS NULL	SET @pSearchDetail	= '';
	------------------------------------------------------------------------------

	--SET @pSortField = NULL;
	--SET @pOrderType = NULL;
	--IF @ClaimGroupTypeId = 4	SET @pIsShowDocumentLink = NULL

	---- @pClaimGroupTypeId
	--	-- 4 เคลมโรงพยาบาล
	--	-- 5 เคลมโอนแยก
	---- @pProductGroupId
	--	-- 2 PH
	--	-- 3 PA

	---- @Tmplst เอาไว้เก็บข้อมูลรายละเอียดเคลม
	---- @TmpClaim เอาไว้เก็บจำนวนเงินของเคลม
	---- #TmpT ข้อมูล PH
	---- #TmpG รวมข้อมูล PH PA
	---- #TmpDoc เอกสารใน smileDoc

	--IF @pClaimGroupTypeId = 5 AND @pProductGroupId = 2 -- (เคลมโอนแยก, PH)
	--	BEGIN


	--		-- รายละเอียดของเคลม	    
	--		INSERT INTO @Tmplst 
	--		(	ClaimHeaderGroup_id
	--			, ClaimHeader_id
	--			, ProductGroup_id
	--			, Branch_id
	--			, CreatedBy_id
	--			, CreatedDate
	--			, InsuranceCompany_id
	--			, InsuranceCompany_Name
	--			, rwId
	--		)
	--		SELECT x.ClaimHeaderGroup_id
	--			  ,x.ClaimCompensateCode
	--			  ,x.ProductGroup_id
	--			  ,x.Branch_id
	--			  ,x.CreatedByCode
	--			  ,x.CreatedDate
	--			  ,x.InsuranceCompanyCode
	--			  ,x.InsuranceCompany_Name
	--			  ,ROW_NUMBER() OVER(ORDER BY (x.ClaimHeaderGroup_id) asc )	rwId
	--		FROM
	--		(
	--			SELECT ccg.ClaimCompensateGroupCode		ClaimHeaderGroup_id
	--					 ,cc.ClaimHeaderCode					ClaimHeader_id
	--					 ,cc.ClaimCompensateCode
	--					 ,2										ProductGroup_id	
	--					 ,'9901'								Branch_id -- เป็นสำนักงานใหญ่
	--					 ,ccg.CreatedByCode						
	--					 ,ccg.CreatedDate
	--					 ,ccg.InsuranceCompanyCode	
	--					 ,ccg.InsuranceCompany_Name	
	--			FROM SSS.dbo.ClaimCompensate cc WITH(NOLOCK)
	--				INNER JOIN SSS.dbo.ClaimCompensateGroup ccg WITH(NOLOCK)
	--					ON cc.ClaimCompensateGroupId = ccg.ClaimCompensateGroupId
	--			WHERE (@pProductGroupId = 2) AND (ccg.ItemCount > 0) -- Update Chanadol 2023-12-01 
	--		)x
	--		WHERE	(x.InsuranceCompanyCode = @pInsCode OR @pInsCode IS NULL)
	--			AND	(x.ClaimHeaderGroup_id LIKE CONCAT(N'' , @pSearchDetail , '%') OR @pSearchDetail IS NULL )
	--			AND (x.CreatedDate >= @CreateDateFromClaimHosAndClaimComp)
	--			AND (x.CreatedByCode = @pCreateByUserCode OR @pCreateByUserCode IS NULL)  --Update Chanadol 2023-10-31 
	--			AND (RIGHT(x.ClaimHeaderGroup_id,1) = '0')
	--			AND  NOT EXISTS ( 
	--								SELECT b.ClaimGroupCode
	--								FROM dbo.ClaimPayBackDetail b
	--								WHERE b.IsActive = 1
	--								AND b.ClaimGroupCode = x.ClaimHeaderGroup_id
	--							)
	--			AND NOT EXISTS (
	--								SELECT c.ClaimCode
	--								FROM dbo.ClaimPayBackXClaim c
	--								LEFT JOIN dbo.ClaimPayBackDetail cd
	--									ON c.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
	--								LEFT JOIN dbo.ClaimPayBack cp
	--									ON cd.ClaimPayBackId = cp.ClaimPayBackId
	--								WHERE c.ClaimCode = x.ClaimHeader_id
	--								AND c.IsActive = 1
	--								AND cp.ClaimGroupTypeId = 5
	--							)	
	--		-- หาจำนวนเงินของเคลม
	--		INSERT INTO @TmpClaim
	--		(
	--		    ClaimHeaderGroup_id
	--		  , ClaimHeader_id
	--		  , Amount
	--		)
	--		SELECT a.ClaimHeaderGroup_id
	--			 , a.ClaimHeader_id
	--			 , a.CompensateRemain
	--		FROM
	--			(
	--				SELECT a.ClaimHeaderGroup_id
	--					 , a.ClaimHeader_id
	--					 , cc.CompensateRemain
	--				FROM sss.dbo.ClaimCompensate cc
	--				INNER JOIN @Tmplst           a
	--					ON cc.ClaimCompensateCode = a.ClaimHeader_id
	--				WHERE @pProductGroupId = 2
	--			) a;

	--	END
	--ELSE
	--	BEGIN
	--		-- หาข้อมูลจาก SSS โดยที่เงื่อนไขไม่เหมือนกัน นำมารวมกัน
	--		-- เก็บข้อมูลเคลม ของ SSS ไว้ใน #TmpT
	--		SELECT g.Code           ClaimHeaderGroup_id
	--				, t.ClaimHeader_id ClaimHeader_id
	--				, 2                ProductGroup_id
	--				, g.Branch_id      Branch_id
	--				, g.CreatedBy_id
	--				, g.CreatedDate
	--				, g.InsuranceCompany_id
	--				, g.IsClaimOnLine
	--				, g.InsuranceCompany_Name
	--		INTO #TmpT
	--		FROM SSS.dbo.DB_ClaimHeaderGroupItem   t WITH (NOLOCK)
	--		INNER JOIN SSS.dbo.DB_ClaimHeaderGroup g WITH (NOLOCK)
	--			ON t.ClaimHeaderGroup_id = g.Code
	--			LEFT JOIN SSS.dbo.DB_ClaimHeader ch
	--			ON g.Code = ch.ClaimHeaderGroup_id
	--		INNER JOIN SSS.dbo.MT_ClaimAdmitType cat
	--			ON g.ClaimAdmitType_id = cat.Code 
	--		INNER JOIN SSS.dbo.MT_ClaimType ct
	--			ON cat.ClaimType_id = ct.Code
	--		WHERE (@pProductGroupId = 2) 
	--		AND g.CreatedDate >= @OpdDateCutoff--'2023-12-08'		
	--			AND g.ClaimAdmitType_id NOT IN ('1001', '3001')
	--			AND
	--				(
	--					(
	--						@pClaimGroupTypeId = 2
	--						AND g.IsClaimOnLine = 1 -- เคลมออนไลน์
	--					)
	--					OR
	--					(
	--						@pClaimGroupTypeId = 3
	--						AND (g.IsClaimOnLine IS NULL OR g.IsClaimOnLine =0) 
	--						AND ct.Code = 2000 -- เคลมสาขา
	--					)
	--					OR
	--					(
	--						@pClaimGroupTypeId = 4
	--						AND g.IsClaimOnLine IS NULL
	--						AND ct.Code = 1000 -- เคลมรพ
	--					)
	--				)
	--		UNION -- Update 2023-12-26 Chanadol
	--		SELECT g.Code           ClaimHeaderGroup_id
	--				, t.ClaimHeader_id ClaimHeader_id
	--				, 2                ProductGroup_id
	--				, g.Branch_id      Branch_id
	--				, g.CreatedBy_id
	--				, g.CreatedDate
	--				, g.InsuranceCompany_id
	--				, g.IsClaimOnLine
	--				, g.InsuranceCompany_Name
	--		FROM SSS.dbo.DB_ClaimHeaderGroupItem   t WITH (NOLOCK)
	--		INNER JOIN SSS.dbo.DB_ClaimHeaderGroup g WITH (NOLOCK)
	--			ON t.ClaimHeaderGroup_id = g.Code
	--		LEFT JOIN SSS.dbo.DB_ClaimHeader ch
	--			ON t.ClaimHeaderGroup_id = ch.ClaimHeaderGroup_id
	--		INNER JOIN SSS.dbo.MT_ClaimAdmitType cat
	--			ON g.ClaimAdmitType_id = cat.Code
	--		INNER JOIN SSS.dbo.MT_ClaimType ct
	--			ON cat.ClaimType_id = ct.Code
	--		WHERE (@pProductGroupId = 2)
	--			--AND g.CreatedDate >= @IpdDateCutoff--'2023-10-26'
	--			--AND (ch.ClaimPaybackStatus = 1 AND g.ClaimAdmitType_id IN ('1001', '3001'))
	--			AND (
	--			(	
	--			g.CreatedDate > @CutoffEndDATE AND ch.ClaimPaybackStatus = 1) -- Kittisak.Ph 2024-01-15 cg หลัง วันที่ 09-01-2024 เช็ค ClaimPaybackStatus=1 เพื่อแสดงปุ่ม
	--			)
	--			AND g.ClaimAdmitType_id IN ('1001', '3001') --Kittisak.Ph 2024-01-15
	--			AND
	--				(
	--					(
	--						@pClaimGroupTypeId = 4
	--						AND g.IsClaimOnLine IS NULL
	--						AND ct.Code = 1000 -- เคลมรพ		
	--					)
	--				)-- Update 2023-12-26 Chanadol
		

	--		-- นำข้อมูลเคลม #TmpT (SSS) มารวมกับข้อมูลเคลม SSSPA เก็บไว้ใน #TmpG
	--		SELECT ClaimHeaderGroup_id
	--				, ClaimHeader_id
	--				, ProductGroup_id
	--				, Branch_id
	--				, CreatedBy_id
	--				, CreatedDate
	--				, InsuranceCompany_id
	--				, IsClaimOnLine
	--				, InsuranceCompany_Name
	--		INTO #TmpG
	--		FROM #TmpT
	--		UNION ALL
	--		SELECT g.Code              ClaimHeaderGroup_id
	--				, item.ClaimHeader_id ClaimHeader_id
	--				, 3                   ProductGroup_id
	--				, g.Branch_id         Branch_id
	--				, g.CreatedBy_id
	--				, g.CreatedDate
	--				, g.InsuranceCompany_id
	--				, g.IsClaimOnLine
	--				, g.InsuranceCompany_Name
	--		FROM SSSPA.dbo.DB_ClaimHeaderGroupItem   item WITH (NOLOCK)
	--		INNER JOIN SSSPA.dbo.DB_ClaimHeaderGroup g WITH (NOLOCK)
	--			ON item.ClaimHeaderGroup_id = g.Code
	--		WHERE (@pProductGroupId = 3)
	--			AND
	--				(
	--					(
	--						@pClaimGroupTypeId = 2
	--						AND g.IsClaimOnLine = 1 -- เคลมออนไลน์
	--					)
	--					OR
	--					(
	--						@pClaimGroupTypeId = 3
	--						AND g.IsClaimOnLine IS NULL
	--						AND g.ClaimStyle_id in ('4130', '4140') -- เคลมสาขา
	--					)
	--					OR
	--					(
	--						@pClaimGroupTypeId = 4
	--						AND g.IsClaimOnLine IS NULL
	--						AND g.ClaimStyle_id in ('4110', '4120') -- เคลมรพ
	--					)
	--				)

	--		-- รายละเอียดของเคลม	 
	--		INSERT INTO @Tmplst 
	--		(	ClaimHeaderGroup_id
	--			, ClaimHeader_id
	--			, ProductGroup_id
	--			, Branch_id
	--			, CreatedBy_id
	--			, CreatedDate
	--			, InsuranceCompany_id
	--			, IsClaimOnLine
	--			, InsuranceCompany_Name
	--			, rwId
	--		)
	--		SELECT g.ClaimHeaderGroup_id
	--			 , g.ClaimHeader_id
	--			 , g.ProductGroup_id
	--			 , g.Branch_id
	--			 , g.CreatedBy_id
	--			 , g.CreatedDate
	--			 , g.InsuranceCompany_id
	--			 , g.IsClaimOnLine
	--			 , g.InsuranceCompany_Name
	--			 , ROW_NUMBER() OVER (ORDER BY (g.ClaimHeaderGroup_id) ASC) rwId
	--		FROM #TmpG g					
							
	--		WHERE (
	--				  g.Branch_id = @pBranchCode
	--				  OR @pBranchCode IS NULL
	--			  )
	--			AND
	--				(
	--					g.InsuranceCompany_id = @pInsCode
	--					OR @pInsCode IS NULL
	--				)
	--			AND
	--				(
	--					g.ClaimHeaderGroup_id LIKE CONCAT(N'', @pSearchDetail, '%')
	--					OR @pSearchDetail IS NULL
	--				)
	--			AND (
	--					(
	--						@pClaimGroupTypeId IN(2,3) 
	--						AND g.CreatedDate >= @CreatedDateFrom
	--					)
	--					OR 
	--					(
	--						@pClaimGroupTypeId = 4 
	--						AND g.CreatedDate >= @IpdDateCutoff--@CreateDateFromClaimHosAndClaimComp
	--					)
	--				)
	--			AND (g.CreatedBy_id = @pCreateByUserCode OR @pCreateByUserCode IS NULL) --Update Chanadol 2023-10-31 
	--			AND (RIGHT(g.ClaimHeaderGroup_id, 1) = '0')
	--			AND NOT EXISTS
	--			(
	--				SELECT b.ClaimGroupCode
	--				FROM dbo.ClaimPayBackDetail b
	--				WHERE b.IsActive = 1
	--					AND b.ClaimGroupCode = ClaimHeaderGroup_id
	--			)
	--			AND NOT EXISTS
	--			(
	--				SELECT c.ClaimCode
	--				FROM dbo.ClaimPayBackXClaim c
	--				LEFT JOIN dbo.ClaimPayBackDetail cd
	--					ON c.ClaimPayBackDetailId = cd.ClaimPayBackDetailId
	--				LEFT JOIN dbo.ClaimPayBack cp
	--					ON cd.ClaimPayBackId = cp.ClaimPayBackId
	--				WHERE c.ClaimCode = g.ClaimHeader_id
	--				AND c.IsActive = 1
	--				AND cp.ClaimGroupTypeId <> 5
	--			);

	--		-- หาจำนวนเงินของเคลม
	--		INSERT INTO @TmpClaim
	--		(
	--		    ClaimHeaderGroup_id
	--		  , ClaimHeader_id
	--		  , Amount
	--		)
	--		SELECT a.ClaimHeaderGroup_id
	--			, a.ClaimHeader_id
	--			, a.Amount
	--		FROM
	--		(
	--			SELECT a.ClaimHeaderGroup_id
	--					, a.ClaimHeader_id
	--					--, IIF(ISNULL(v.net, 0) <> 0, ISNULL(v.Pay_Total, 0), ISNULL(v.Compensate_net, 0)) Amount
	--					,v.PaySS_Total Amount
	--			FROM SSS.dbo.DB_ClaimVoucher v WITH (NOLOCK)
	--			INNER JOIN @Tmplst           a
	--				ON v.Code = a.ClaimHeader_id
	--			WHERE @pProductGroupId = 2
	--				--AND v.PaySS_Total > 0
	--			UNION ALL
	--			SELECT a.ClaimHeaderGroup_id
	--					, a.ClaimHeader_id
	--					--, v.Amount_Net Amount
	--					, v.PaySS_Total Amount
	--			FROM SSSPA.dbo.DB_ClaimHeader v WITH (NOLOCK)
	--			INNER JOIN @Tmplst            a
	--				ON v.Code = a.ClaimHeader_id
	--			WHERE @pProductGroupId = 3
	--				--AND v.PaySS_Total > 0
	--		) a;


	--	END

	---- เคลมรพ. ไม่ต้องเช็คเอกสาร
	--IF @pClaimGroupTypeId <> 4
	--	BEGIN
	--		SELECT c.ClaimHeaderGroup_id
	--				, c.ClaimHeader_id
	--		INTO #TmpDoc
	--		FROM ISC_SmileDoc.dbo.Document               d WITH (NOLOCK)
	--		LEFT JOIN ISC_SmileDoc.dbo.DocumentIndexData dd WITH (NOLOCK)
	--			ON d.DocumentID = dd.DocumentID
	--		INNER JOIN @TmpClaim                         c
	--			ON dd.DocumentIndexData = c.ClaimHeader_id COLLATE DATABASE_DEFAULT
	--		WHERE d.DocumentStatusID IN (2, 4)
	--		GROUP BY c.ClaimHeaderGroup_id
	--				, c.ClaimHeader_id;
	--	END


	---- Response เคลมโรงพยาบาล
	--IF @pClaimGroupTypeId = 4
	--	BEGIN

	--		SELECT d.ClaimHeaderGroup_id                                ClaimHeaderGroup_id
	--				, b.Detail                                             Branch
	--				, pg.ProductGroupDetail                                ProductGroup
	--				, CONCAT(eC.Code, ' ', eC.FirstName, ' ', eC.LastName) CreatedByName
	--				, d.CreatedDate                                        CreatedDate
	--				, gt.ClaimGroupType                                    ClaimGroupType
	--				, c.ItemCount                                          ItemCount
	--				, c.Amount                                             Amount
	--				, org.Organize_ID                                      InsuranceCompanyId
	--				, d.InsuranceCompany_Name                              InsuranceCompany
	--				, 0													DocumentCount
	--				, COUNT(d.ClaimHeaderGroup_id) OVER ()                 TotalCount
	--		FROM
	--			(
	--				SELECT ClaimHeaderGroup_id
	--						, MIN(rwId) minId
	--				FROM @Tmplst
	--				GROUP BY ClaimHeaderGroup_id
	--			)                                       g
	--		INNER JOIN
	--			(
	--				SELECT *
	--						, @ClaimGroupTypeId ClaimGroupTypeId
	--				FROM @Tmplst
	--			)                                       d
	--			ON g.minId = d.rwId
	--		INNER JOIN
	--			(
	--				SELECT ClaimHeaderGroup_id
	--						, COUNT(ClaimHeader_id) ItemCount
	--						, SUM(Amount)           Amount
	--				FROM @TmpClaim
	--				GROUP BY ClaimHeaderGroup_id
	--			)                                       c
	--			ON g.ClaimHeaderGroup_id = c.ClaimHeaderGroup_id
	--		LEFT JOIN SSS.dbo.MT_Branch                 b
	--			ON d.Branch_id = b.Code
	--		LEFT JOIN SSS.dbo.DB_Employee               eC
	--			ON d.CreatedBy_id = eC.Code
	--		LEFT JOIN DataCenterV1.Product.ProductGroup pg
	--			ON d.ProductGroup_id = pg.ProductGroup_ID
	--		LEFT JOIN DataCenterV1.Organize.Organize    org
	--			ON d.InsuranceCompany_id = org.OrganizeCode
	--		LEFT JOIN dbo.ClaimGroupType                gt
	--			ON d.ClaimGroupTypeId = gt.ClaimGroupTypeId
	--		WHERE org.Organize_ID <> 26
	--		ORDER BY d.ClaimHeaderGroup_id ASC	

	--		OFFSET @pIndexStart ROWS FETCH NEXT @pPageSize ROWS ONLY
	--	END
	--ELSE
	--	BEGIN
	--		-- Response อื่น ๆ
	--		SELECT d.ClaimHeaderGroup_id                                ClaimHeaderGroup_id
	--				, b.Detail                                             Branch
	--				, pg.ProductGroupDetail                                ProductGroup
	--				, CONCAT(eC.Code, ' ', eC.FirstName, ' ', eC.LastName) CreatedByName
	--				, d.CreatedDate                                        CreatedDate
	--				, gt.ClaimGroupType                                    ClaimGroupType
	--				, c.ItemCount                                          ItemCount
	--				, c.Amount                                             Amount
	--				, org.Organize_ID                                      InsuranceCompanyId
	--				, d.InsuranceCompany_Name                              InsuranceCompany
	--				, IIF(c.ItemCount <> ISNULL(doc.xCount, 0), 0, 1)      DocumentCount
	--				, COUNT(d.ClaimHeaderGroup_id) OVER ()                 TotalCount
	--		FROM
	--			(
	--				SELECT ClaimHeaderGroup_id
	--						, MIN(rwId) minId
	--				FROM @Tmplst
	--				GROUP BY ClaimHeaderGroup_id
	--			)                                       g
	--		INNER JOIN
	--			(
	--				SELECT *
	--						, @ClaimGroupTypeId ClaimGroupTypeId
	--				FROM @Tmplst
	--			)                                       d
	--			ON g.minId = d.rwId
	--		INNER JOIN
	--			(
	--				SELECT ClaimHeaderGroup_id
	--						, COUNT(ClaimHeader_id) ItemCount
	--						, SUM(Amount)           Amount
	--				FROM @TmpClaim
	--				GROUP BY ClaimHeaderGroup_id
	--			)                                       c
	--			ON g.ClaimHeaderGroup_id = c.ClaimHeaderGroup_id
	--		LEFT JOIN SSS.dbo.MT_Branch                 b
	--			ON d.Branch_id = b.Code
	--		LEFT JOIN SSS.dbo.DB_Employee               eC
	--			ON d.CreatedBy_id = eC.Code
	--		LEFT JOIN DataCenterV1.Product.ProductGroup pg
	--			ON d.ProductGroup_id = pg.ProductGroup_ID
	--		LEFT JOIN DataCenterV1.Organize.Organize    org
	--			ON d.InsuranceCompany_id = org.OrganizeCode
	--		LEFT JOIN dbo.ClaimGroupType                gt
	--			ON d.ClaimGroupTypeId = gt.ClaimGroupTypeId
	--		LEFT JOIN
	--			(
	--				SELECT ClaimHeaderGroup_id
	--						, COUNT(ClaimHeader_id) xCount
	--				FROM #TmpDoc 
	--				GROUP BY ClaimHeaderGroup_id
	--			)                                       doc
	--			ON g.ClaimHeaderGroup_id = doc.ClaimHeaderGroup_id
	--		WHERE (
	--					(
	--						@pIsShowDocumentLink = 1
	--						AND c.ItemCount = doc.xCount
	--					)
	--					OR
	--						(
	--							@pIsShowDocumentLink = 0
	--							AND
	--								(
	--									(c.ItemCount <> doc.xCount)
	--									OR (doc.xCount IS NULL)
	--								)
	--						)
	--					OR (@pIsShowDocumentLink IS NULL)
	--				)
	--				AND org.Organize_ID <> 26
	--		ORDER BY d.ClaimHeaderGroup_id ASC	
	--		OFFSET @pIndexStart ROWS FETCH NEXT @pPageSize ROWS ONLY

	--	END

	--IF OBJECT_ID('tempdb..@TmpClaim') IS NOT NULL  DELETE FROM @TmpClaim;	
	--IF OBJECT_ID('tempdb..#TmpDoc') IS NOT NULL  DROP TABLE #TmpDoc;	
	--IF OBJECT_ID('tempdb..#TmpT') IS NOT NULL  DROP TABLE #TmpT;
	--IF OBJECT_ID('tempdb..#TmpG') IS NOT NULL  DROP TABLE #TmpG;	
	--IF OBJECT_ID('tempdb..@Tmplst') IS NOT NULL  DELETE FROM @Tmplst;

	---------------------------------------------------------------------

	--DECLARE @DefaultDate AS DATETIME = '2021-10-08 08:22'
	--DECLARE @amount		AS DECIMAL

	-- SELECT 
	--			 N''						ClaimHeaderGroup_id
	--			,''							Branch
	--			,''							ProductGroup	
	--			,''							CreatedByName
	--			,@DefaultDate				CreatedDate
	--            ,''							ClaimGroupType
	--			,1							ItemCount
	--			,@amount					Amount
	--			,1							InsuranceCompanyId
	--			,''							InsuranceCompany
	--			,1							DocumentCount
	--			,@amount					TransferAmount
	--			,1							TotalCount
	--			,''							ProductTypeDetail

END



