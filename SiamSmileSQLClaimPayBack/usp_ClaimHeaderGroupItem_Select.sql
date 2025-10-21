USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [Claim].[usp_ClaimHeaderGroupItem_Select]    Script Date: 21/10/2568 9:26:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		supattra
-- Create date: 2021-10-07
-- Update date: 2023-09-21 golffy Add ClaomCompensate
--				2025-10-21 Add ClaimMisc Sorawit kamlangsub
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [Claim].[usp_ClaimHeaderGroupItem_Select] 
	 @ClaimGroupCode		NVARCHAR(255)
	,@ProductGroupId		INT
	,@ClaimGroupTypeId		INT

	,@IndexStart					INT = NULL 
	,@PageSize						INT = NULL 
	,@SortField						NVARCHAR(MAX) = NULL
	,@OrderType						NVARCHAR(MAX) = NULL
	,@SearchDetail					NVARCHAR(MAX) = NULL
AS
BEGIN
	
	SET NOCOUNT ON;

	 ----------------------------------------------------------------------------
	IF @IndexStart IS NULL			BEGIN	SET @IndexStart			= 0		END	;
	IF @PageSize IS NULL			BEGIN	SET @PageSize			= 10	END	;
	IF @SearchDetail IS NULL		BEGIN	SET @SearchDetail		= ''	END	;
	----------------------------------------------------------------------------
 	
--Get URL in ProgramConfig
DECLARE @SSSURL			NVARCHAR(250);
DECLARE @SSSPAURL		NVARCHAR(250);
DECLARE @ClaimMiscURL	NVARCHAR(250);

DECLARE @SSSPath	NVARCHAR(250) = 'SSS_URL'
DECLARE @SSSPAPath	NVARCHAR(250) = 'SSSPA_URL'

SELECT @SSSURL = ValueString
FROM dbo.ProgramConfig 
WHERE ParameterName = @SSSPath

SELECT @SSSPAURL = ValueString
FROM dbo.ProgramConfig 
WHERE ParameterName = @SSSPAPath

-- Set URL
SET @SSSURL =	CONCAT(@SSSURL,'Modules/Claim/frmClaimApproveOverview.aspx?clm=');
SET @SSSPAURL = CONCAT(@SSSPAURL,'Modules/Claim/frmClaimPA_New.aspx?clm=');
SET @ClaimMiscURL = 'https://uatclaimmisc.siamsmile.co.th/viewclaimdetails?id=';


DECLARE @tmpClg TABLE (
	ClaimHeaderGroup_id VARCHAR(20),
	ClaimHeader_id VARCHAR(20)
);

DECLARE @tmpCliamMisc TABLE 
(
	ClaimCode			VARCHAR(255)
	,URLLink			VARCHAR(255)
	,Product_Id			VARCHAR(255)
	,[Product]			VARCHAR(255)
	,Hospital_Id		VARCHAR(255)
	,Hospital			VARCHAR(255)
	,ClaimAdmitType_Id	VARCHAR(255)
	,ClaimAdmitType		VARCHAR(255)
	,ChiefComplain_id	VARCHAR(255)
	,ChiefComplain		VARCHAR(255)
	,ICD10				VARCHAR(255)
	,ICD10_Detail		VARCHAR(255)
)
	
	-- Compenstate
	IF @ProductGroupId = 2 AND @ClaimGroupTypeId = 5
		BEGIN
		    
			INSERT INTO @tmpClg -- 20230921
			(
			    ClaimHeaderGroup_id
			  , ClaimHeader_id
			)
			SELECT ccg.ClaimCompensateGroupCode
				, cc.ClaimHeaderCode
			FROM sss.dbo.ClaimCompensateGroup ccg
			LEFT JOIN sss.dbo.ClaimCompensate cc
				ON ccg.ClaimCompensateGroupId = cc.ClaimCompensateGroupId
			WHERE ccg.ClaimCompensateGroupCode = @ClaimGroupCode

		END

	IF @ProductGroupId IN (4,5,6,7,8,9,10,11) AND @ClaimGroupTypeId = 7
		BEGIN
			INSERT INTO @tmpCliamMisc
			(
				ClaimCode			
				,URLLink			
				,Product_Id			
				,[Product]			
				,Hospital_Id		
				,Hospital			
				,ClaimAdmitType_Id	
				,ClaimAdmitType		
				,ChiefComplain_id	
				,ChiefComplain		
				,ICD10				
				,ICD10_Detail					
			)
			SELECT
				cm.ClaimMiscNo														ClaimCode
				,CONCAT(@ClaimMiscURL,cm.ClaimMiscId)								URLLink
				,CAST(cm.ProductTypeId AS VARCHAR(20))								Product_Id
				,pt.ProductTypeName													[Product]
				,CAST(cm.HospitalId AS VARCHAR(20))									Hospital_Id
				,cm.HospitalName													Hospital
				,NULL																ClaimAdmitType_Id
				,STUFF((
					SELECT DISTINCT
						   ',' + cat.ClaimAdmitTypeName
					FROM [ClaimMiscellaneous].[misc].[ClaimMiscXClaimAdmitType] cxt
					LEFT JOIN 
					(
						SELECT 
							ClaimAdmitTypeId
							,ClaimAdmitTypeName
						FROM [ClaimMiscellaneous].[misc].[ClaimAdmitType] 
						WHERE IsActive = 1
					) cat
					  ON cat.ClaimAdmitTypeId = cxt.ClaimAdmitTypeId
					WHERE cxt.IsActive = 1
					  AND cxt.ClaimMiscId = cm.ClaimMiscId
					FOR XML PATH(''), TYPE
				).value('.','nvarchar(max)'), 1, 1, '')									ClaimAdmitType 
				,CAST(cm.ChiefComplainId AS VARCHAR(20))								ChiefComplain_id
				,chf.ChiefComplainName													ChiefComplain
				,NULL																	ICD10
				,NULL																	ICD10_Detail			
			FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
				LEFT JOIN 
				(
					SELECT
						ProductTypeId
						,ProductTypeName
					FROM [ClaimMiscellaneous].[misc].[ProductType] 
					WHERE IsActive = 1
				) pt
				ON pt.ProductTypeId = cm.ProductTypeId
				LEFT JOIN
				(
					SELECT
						ChiefComplainId
						,ChiefComplainName
					FROM [ClaimMiscellaneous].[misc].[ChiefComplain]
					WHERE IsActive = 1
				) chf
				ON chf.ChiefComplainId = cm.ChiefComplainId

			WHERE cm.IsActive = 1
			AND cm.ClaimHeaderGroupCode = @ClaimGroupCode



		END
	
	-- Ph And Pa
	ELSE
		BEGIN
		    
			INSERT INTO @tmpClg
			(
			    ClaimHeaderGroup_id
			  , ClaimHeader_id
			)
			SELECT 
					A.ClaimHeaderGroup_id
					,A.ClaimHeader_id
			FROM (
					SELECT t.ClaimHeaderGroup_id
						,t.ClaimHeader_id
					FROM  sss.dbo.DB_ClaimHeaderGroupItem t
					WHERE (t.ClaimHeaderGroup_id = @ClaimGroupCode)
				UNION  
					SELECT 	 item.ClaimHeaderGroup_id
							,item.ClaimHeader_id
					FROM ssspa.dbo.DB_ClaimHeaderGroupItem item
					WHERE (item.ClaimHeaderGroup_id = @ClaimGroupCode)
				)A 	

		END


		
   SELECT * INTO #tmpDetal
	  FROM (
			 SELECT  
				   Cl.Code ClaimCode
				  ,CONCAT(@SSSURL,dbo.uFnStringToBase64(Cl.Code))  URLLink
				  ,Cl.Product_Id
				  ,Cl.Product
				  ,Cl.Hospital_Id
				  ,Cl.Hospital
				  ,Cl.ClaimAdmitType_Id
				  ,Cl.ClaimAdmitType
				  ,Cl.ChiefComplain_id
				  ,Cl.ChiefComplain
				  ,Cl.ICD10
				  ,Cl.ICD10_Detail
				FROM sss.[dbo].[rpt_ClaimBenefit_NetAndPay]	 Cl
					INNER JOIN @tmpClG t
						ON 	cl.Code = t.ClaimHeader_id
		UNION
		   SELECT 
		   		 vw.Code ClaimCode
				,CONCAT(@SSSPAURL,dbo.uFnStringToBase64(vw.Code))	 URLLink
		   		,vw.ClaimProduct_Id
		   		,vw.ClaimProduct
		   		,vw.Hospital_Id
		   		,vw.Hospital
		   		,vw.ClaimType_Id
		   		,vw.ClaimType
		   		,vw.AccidentCause_Id
		   		,vw.AccidentCause
		   		,vw.ICD10
		   		,vw.ICD10Detail
		    FROM sssPA.dbo.vw_ClaimHeaderDetail_For_DataExport  vw
		   	INNER JOIN @tmpClG t
				ON vw.Code = t.ClaimHeader_id
		UNION
			SELECT
				*
			FROM @tmpCliamMisc
	)#tmpDetal
		

	 SELECT 
			 ClaimCode
			,Product_Id
			,Product
			,Hospital_Id
			,Hospital
			,ClaimAdmitType_Id
			,ClaimAdmitType
			,ChiefComplain_id
			,ChiefComplain
			,ICD10
			,ICD10_Detail
			,URLLink
			,COUNT(ClaimCode) OVER() TotalCount
	 FROM #tmpDetal		
	   ORDER BY CASE WHEN @SortField IS NULL AND @OrderType IS NULL THEN ClaimCode END DESC 
		 OFFSET @IndexStart ROWS FETCH NEXT @PageSize ROWS ONLY
	
	DELETE FROM @tmpClG
	DROP TABLE #tmpDetal	

	 --SELECT 
		--	 N''					ClaimCode
		--	,N''					Product_Id
		--	,N''					Product
		--	,N''					Hospital_Id
		--	,N''					Hospital
		--	,N''					ClaimAdmitType_Id
		--	,N''					ClaimAdmitType
		--	,N''					ChiefComplain_id
		--	,N''					ChiefComplain
		--	,N''					ICD10
		--	,N''					ICD10_Detail
		--	,N''					URLLink
		--	,1						TotalCount




 
END



