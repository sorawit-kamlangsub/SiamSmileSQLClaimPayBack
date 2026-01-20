USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequest_ClaimMisc_Insert]    Script Date: 20/1/2569 14:34:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Sorawit Kamlangsub
-- Create date: 2025-12-16  15:43
-- Description:
-- =============================================
ALTER PROCEDURE [dbo].[usp_BillingRequest_ClaimMisc_Insert]
		@GroupTypeId				INT
		,@ClaimTypeCode				VARCHAR(20)
		,@InsuranceCompanyId		INT
		,@CreatedByUserId			INT
		,@BillingDate				DATE
		,@ClaimHeaderGroupTypeId	INT
		,@InsuranceCompanyName		NVARCHAR(300)
		,@NewBillingDate			DATE
		,@CreatedDateFrom			DATE
		,@CreatedDateTo				DATE
		,@ProductTypeShortName		VARCHAR(20)
		,@ProductTypeId				INT

AS
BEGIN
	SET NOCOUNT ON;

--DECLARE
--		@GroupTypeId				INT				= 3
--		,@ClaimTypeCode				VARCHAR(20)		= '2000'
--		,@InsuranceCompanyId		INT				= 18
--		,@CreatedByUserId			INT				= 6772
--		,@BillingDate				DATE			= '2025-12-16'
--		,@ClaimHeaderGroupTypeId	INT				= 6
--		,@InsuranceCompanyName		NVARCHAR(300)	= 'บริษัท ชับบ์สามัคคีประกันภัย จำกัด (มหาชน)'
--		,@NewBillingDate			DATE			= '2025-12-16'
--		,@CreatedDateFrom			DATE			= '2025-12-16'
--		,@CreatedDateTo				DATE			= '2025-12-16'
--		,@ProductTypeShortName		VARCHAR(20)		= 'SP'
--		,@ProductTypeId				INT				= 32	
--		;


DECLARE @IsResult	BIT			 = 1;
DECLARE @Result		VARCHAR(100) = '';
DECLARE @Msg		NVARCHAR(500)= '';

IF (@IsResult = 0) SET @Msg = N'ปิดใช้งาน';

DECLARE @productShortName VARCHAR(20)			= @ProductTypeShortName;
DECLARE @productId VARCHAR(20)					= @ProductTypeId;
DECLARE @pGroupTypeId			INT				= @GroupTypeId;
DECLARE @pInsuranceCompanyId	INT				= @InsuranceCompanyId;
DECLARE @UserId					INT				= @CreatedByUserId;

DECLARE @D2						DATETIME2		= SYSDATETIME();

DECLARE @Date					DATE = @D2;

DECLARE	@BillindDueDate			DATE;
DECLARE @DaysToAdd				INT				= 15;
DECLARE @TransactionDetail		NVARCHAR(500)	= N'Generate Group เสร็จสิ้น';

IF @CreatedDateTo IS NOT NULL SET @CreatedDateTo = DATEADD(DAY,1,@CreatedDateTo);

SET @BillindDueDate = DATEADD(	DAY
								,@DaysToAdd + ((@DaysToAdd - 1) / 5) * 2 
								+ CASE 
									WHEN DATEPART(WEEKDAY, @NewBillingDate) + (@DaysToAdd - 1) % 5 >= 7 THEN 1
									WHEN DATEPART(WEEKDAY, @NewBillingDate) = 6 AND (@DaysToAdd - 1) % 5 = 0 THEN 1
									ELSE 0 
									END
								,@NewBillingDate);

IF (@IsResult = 0) SET @Msg = N'ปิดใช้งาน';

/*SetUp Tmplst*/
	SELECT	
		i.ClaimHeaderGroupImportId
		,i.ClaimHeaderGroupCode
		,i.ClaimHeaderGroupImportStatusId
		,i.InsuranceCompanyId
		,i.BillingRequestGroupId
		,f.ClaimHeaderGroupTypeId
		,cm.ProductTypeId
		,ROW_NUMBER() OVER(ORDER BY ClaimHeaderGroupImportId ASC) rwId
	INTO #Tmplst
	FROM dbo.ClaimHeaderGroupImport i
		INNER JOIN dbo.ClaimHeaderGroupImportFile f
			ON i.ClaimGroupImportFileId = f.ClaimHeaderGroupImportFileId
		INNER JOIN 
		(
			SELECT
				cm.ClaimHeaderGroupCode
				,cm.ProductTypeId
				,pt.ProductTypeShortName
			FROM [ClaimMiscellaneous].[misc].[ClaimMisc] cm
				LEFT JOIN [ClaimMiscellaneous].[misc].[ProductType] pt
					ON pt.ProductTypeId = cm.ProductTypeId
			WHERE cm.IsActive = 1
		) cm
			ON cm.ClaimHeaderGroupCode = i.ClaimHeaderGroupCode
	WHERE f.IsActive = 1
	AND i.IsActive = 1
	AND i.ClaimHeaderGroupImportStatusId = 2
	AND i.BillingRequestGroupId IS NULL
	AND i.InsuranceCompanyId = @pInsuranceCompanyId
	AND (i.ClaimTypeCode = @ClaimTypeCode)
	AND	i.CreatedDate >	@CreatedDateFrom
	AND	i.CreatedDate <=  @CreatedDateTo
	AND f.ClaimHeaderGroupTypeId = @ClaimHeaderGroupTypeId
	AND cm.ProductTypeId = @productId

/*SetUp TmpX*/
	SELECT	
		d.ClaimHeaderGroupImportDetailId
		,d.ClaimHeaderGroupImportId
		,d.ClaimCode
		,d.PaySS_Total
		,d.ClaimHeaderGroupCode
	INTO #TmpX
	FROM dbo.ClaimHeaderGroupImportDetail d
		INNER JOIN #Tmplst lst
			ON d.ClaimHeaderGroupImportId = lst.ClaimHeaderGroupImportId
	WHERE d.IsActive = 1;

/*SetUp TmpCover*/
	SELECT	
		d.BillingRequestResultDetailId
		,d.ClaimCode
		,d.CoverAmount
	INTO #TmpCover
	FROM dbo.BillingRequestResultDetail d
		INNER JOIN dbo.BillingRequestResultHeader h
			ON d.BillingRequestResultHeaderId = h.BillingRequestResultHeaderId
		LEFT JOIN 
		(
			SELECT cs.ClaimCompensateCode
				,cs.ClaimHeaderCode
			FROM SSS.dbo.ClaimCompensate cs
			WHERE cs.IsActive = 1	
		)cs
			ON d.ClaimCode = cs.ClaimHeaderCode
		INNER JOIN #TmpX x
			ON d.ClaimCode = x.ClaimCode
	WHERE h.IsActive = 1
		AND	d.IsActive = 1
		AND	cs.ClaimCompensateCode IS NULL;

/*SetUp Sort*/
SELECT 
	d.*
    ,''	P1
    ,0	P2
    ,0	P3
    ,0	P4
INTO #TmpX2
FROM #TmpX d;

/*SetUp TmpDetail*/
	SELECT	
		d.ClaimHeaderGroupImportDetailId
		,d.ClaimHeaderGroupImportId
		,d.ClaimCode
		,d.PaySS_Total							 PaySS_Total
		,ISNULL(c.SumCover,0)					 SumCover
		,(d.PaySS_Total - ISNULL(c.SumCover,0))  TotalAmount
		,ROW_NUMBER() OVER (ORDER BY d.P1, d.P2, d.P3, d.P4) AS rwId
		,d.ClaimHeaderGroupCode
	INTO #TmpDetail
	FROM #TmpX2 d
		LEFT JOIN 
		(
			SELECT ClaimCode
					,SUM(CoverAmount)	 SumCover
			FROM #TmpCover 
			GROUP BY ClaimCode
		) c
			ON d.ClaimCode = c.ClaimCode
	ORDER BY
		d.P1, d.P2, d.P3, d.P4;

IF (@IsResult = 1)
BEGIN

	DECLARE @Code_G	VARCHAR(20);
	DECLARE @Code_D	VARCHAR(20);
	
	DECLARE @Last2numbersOfInsurance VARCHAR(2);
	DECLARE @ClaimHeaderGroupCodeIndex3 VARCHAR(1);
	DECLARE @ClaimType VARCHAR(1);
	DECLARE @InsuranceCompanyCode VARCHAR(30);
	DECLARE @IsSFTP BIT = 0;

	SELECT 
		@InsuranceCompanyCode = o.OrganizeCode 
		,@IsSFTP = 0
	FROM DataCenterV1.Organize.Organize o
			LEFT JOIN (
				SELECT
					InsuranceCompanyCode
					,SFTPConfigId
				FROM dbo.SFTPConfig 
				WHERE IsActive = 1
			)sfd
				ON sfd.InsuranceCompanyCode = o.OrganizeCode
			LEFT JOIN (
				SELECT 
					InsuranceCompanyCode
					,ProductTypeId
					,IsSFTP
				FROM dbo.SFTPConfigProduct
				WHERE IsActive = 1
				AND ProductTypeId = @ClaimHeaderGroupTypeId
			) p
				ON p.InsuranceCompanyCode = o.OrganizeCode
	WHERE o.Organize_ID = @InsuranceCompanyId

	SET @Last2numbersOfInsurance = RIGHT(@InsuranceCompanyCode,2);

	SELECT @ClaimHeaderGroupCodeIndex3 = (SELECT TOP(1) RIGHT(LEFT(ClaimHeaderGroupCode, 4) ,1) FROM #Tmplst);

	IF (@ClaimHeaderGroupCodeIndex3 = 'H' or @ClaimHeaderGroupTypeId = 4)
	BEGIN
		SET @ClaimType= 'H'
	END
	ELSE
	BEGIN
		SET @ClaimType= 'B'
	END;

	SET @Code_G = CONCAT('BQG',@productShortName, @Last2numbersOfInsurance, @ClaimType)
	SET @Code_D = CONCAT('BQI',@productShortName)
	
	DECLARE @G_RunningLenght			INT			= 3
	DECLARE @G_TT						VARCHAR(8)	= @Code_G;
	DECLARE @BillingRequestGroupCode	VARCHAR(20)
	
	DECLARE @D_Lenght					INT			= 6;
	DECLARE @D_TT						VARCHAR(6)	= @Code_D;
	DECLARE @D_Total					INT			= (SELECT MAX(rwId) FROM #TmpDetail);
	DECLARE @D_YY						VARCHAR(2)
	DECLARE @D_MM						VARCHAR(2)
	DECLARE @D_RunningFrom				INT
	DECLARE @D_RunningTo				INT
	
	DECLARE @Offset INT = 0;
	DECLARE @BatchSize INT = @D_Total;
	DECLARE @TotalRows INT = 1;

/*Check SFTP For Loop */
	IF @IsSFTP = 0
	BEGIN 
		SET @TotalRows = @D_Total;
		SET @BatchSize = 20;
		SET @G_RunningLenght = 5;
	END
	
/* Generate Code */
		IF @IsSFTP = 0
		BEGIN 
			
			EXECUTE dbo.usp_GenerateCodeV2 
					 @G_TT
					,@G_RunningLenght
					,@BillingRequestGroupCode OUTPUT;

		END
		ELSE
		BEGIN
			EXECUTE dbo.usp_GenerateCode 
					 @G_TT
					,@G_RunningLenght
					,@BillingRequestGroupCode OUTPUT;
		END

			--EXECUTE dbo.usp_GenerateCode 
			--		 @G_TT
			--		,@G_RunningLenght
			--		,@BillingRequestGroupCode OUTPUT;

			SELECT	
				CONCAT(@D_TT, @D_YY, @D_MM, dbo.func_ConvertIntToString((@D_RunningFrom + rwId - 1), @D_Lenght))	BillingRequestItemCode
				,*
			INTO #TmpDt_
			FROM #TmpDetail;

		SET @D2 = GETDATE();
	-----------------------------------
	BEGIN TRY
		Begin TRANSACTION

	WHILE @Offset < @TotalRows
	BEGIN
		DECLARE @ItemCount		INT = NULL;
		DECLARE @PaySS_Total	DECIMAL(16,2);
		DECLARE @CoverAmount	DECIMAL(16,2);

		SELECT	@ItemCount		= COUNT(ClaimHeaderGroupImportDetailId)
				,@PaySS_Total	= SUM(PaySS_Total)
				,@CoverAmount	= SUM(SumCover)
		FROM	#TmpDetail	
		WHERE rwId > @Offset 
			AND rwId <= @Offset + @BatchSize;

		SET @BillingRequestGroupCode = NULL;
		DECLARE @BillingRequestGroupId INT = NULL;

/* Generate Code */
		EXECUTE dbo.usp_GenerateCode 
				 @G_TT
				,@G_RunningLenght
				,@BillingRequestGroupCode OUTPUT;

/* Insert BillingRequestGroup*/
			INSERT INTO dbo.BillingRequestGroup
			        (BillingRequestGroupCode
			        ,InsuranceCompanyId
			        ,ItemCount
			        ,PaySS_Total
			        ,CoverAmount
			        ,TotalAmount
			        ,BillingRequestGroupStatusId
			        ,BillingDate
			        ,IsActive
			        ,CreatedDate
			        ,CreatedByUserId
			        ,UpdatedDate
			        ,UpdatedByUserId
					,ClaimTypeCode
					,BillingDueDate
					,ClaimHeaderGroupTypeId
					,InsuranceCompanyName)
			SELECT @BillingRequestGroupCode				BillingRequestGroupCode
					,@InsuranceCompanyId				InsuranceCompanyId
					,@ItemCount							ItemCount
					,@PaySS_Total						PaySS_Total
					,@CoverAmount						CoverAmount
					,(@PaySS_Total - @CoverAmount)		TotalAmount
					,2									BillingRequestGroupStatusId
					,@NewBillingDate					BillingDate
					,1									IsActive
					,@D2								CreatedDate
					,@UserId							CreatedByUserId
					,@D2								UpdatedDate
					,@UserId							UpdatedByUserId
					,@ClaimTypeCode						ClaimTypeCode
					,@BillindDueDate					BillindDueDate
					,@ClaimHeaderGroupTypeId			ClaimHeaderGroupTypeId
					,@InsuranceCompanyName	
				
			SET @BillingRequestGroupId = SCOPE_IDENTITY();				
			
/* Insert BillingRequestItem */
			INSERT INTO dbo.BillingRequestItem
			        (BillingRequestItemCode
			        ,BillingRequestGroupId
			        ,ClaimHeaderGroupImportDetailId
			        ,PaySS_Total
			        ,CoverAmount
			        ,AmountTotal
			        ,IsActive
			        ,CreatedDate
			        ,CreatedByUserId
			        ,UpdatedDate
			        ,UpdatedByUserId)
			SELECT	
				i.BillingRequestItemCode
				,@BillingRequestGroupId				BillingRequestGroupId
				,i.ClaimHeaderGroupImportDetailId
				,i.PaySS_Total						PaySS_Total
				,i.SumCover							CoverAmount
				,i.TotalAmount						AmountTotal
				,1									IsActive
				,@D2								CreatedDate
				,@UserId							CreatedByUserId
				,@D2								UpdatedDate
				,@UserId							UpdatedByUserId
			FROM #TmpDt_ i
			WHERE i.rwId > @Offset 
				AND i.rwId <= @Offset + @BatchSize;
	
/* Update ClaimHeaderGroupImport */
			--SELECT *
			UPDATE	m 
				SET m.ClaimHeaderGroupImportStatusId	= 3
				,m.BillingRequestGroupId			= @BillingRequestGroupId
				,m.UpdatedDate						= @D2
				,m.UpdatedByUserId					= @UserId
				,m.BillingDate						= @NewBillingDate
			FROM dbo.ClaimHeaderGroupImport m
				INNER JOIN #Tmplst u
					ON m.ClaimHeaderGroupImportId = u.ClaimHeaderGroupImportId
			WHERE u.rwId > @Offset 
				AND u.rwId <= @Offset + @BatchSize ;
				
/* Insert BillingRequestGroupXResultDetail */
			INSERT INTO dbo.BillingRequestGroupXResultDetail
					(BillingRequestGroupId
					,BillingRequestResultDetailId)
			SELECT	
				@BillingRequestGroupId			BillingRequestGroupId
				,i.BillingRequestResultDetailId
			FROM #TmpCover i;

/* Insert BillingExport */
			INSERT INTO ClaimPayBack.dbo.BillingExport
					(BillingDate
					,BillingDueDate
					,BranchCode
					,Branch
					,ClaimHeaderGroupCode
					,PolicyNo
					,ApplicationCode
					,ClaimCode
					,Province
					,SchoolName
					,CustomerDetailCode
					,IdentityCard
					,CustName
					,SchoolLevel
					,DateHappen
					,Accident
					,ChiefComplain
					,Orgen
					,Pay
					,Compensate_Include
					,Compensate_Out
					,Amount_Pay
					,Amount_Dead
					,Pay_Total
					,ClaimAdmitType
					,HospitalId
					,HospitalName
					,ICD10_1Code
					,ICD10
					,Remark
					,DateIn
					,DateOut
					,ClaimType
					,BillingRequestGroupCode
					,BillingRequestItemCode
					,DocumentLink
					,InsuranceCompanyId
					,InsuranceCompanyName
					,StartCoverDate
					,IPDCount
					,ICUCount
					,ClaimHeaderGroupTypeId
					,ProductId
					,[Product]
					,CreatedByUserId
					,CreatedDate
					,BillingBankId
					,BankAccountNumber)
			SELECT 
				@NewBillingDate		BillingDate
				,g.BillingDueDate
				,c.CreatedByBranchId BranchCode
				,br.BranchDetail Branch
				,c.ClaimHeaderGroupCode		
				,c.PolicyNo				
				,c.ApplicationCode	
				,c.ClaimCode	
				,c.Province									
				,c.SchoolName									
				,c.CustomerDetailCode
				,c.IdentityCard	
				,c.CustName		
				,c.SchoolLevel		
				,c.DateHappen
				,c.Accident		
				,c.ChiefComplain	
				,c.Orgen	
				,(c.Pay	- ISNULL(b.CoverAmount,0))			Pay
				,c.Amount_Compensate_in						Compensate_Include		
				,c.Amount_Compensate_out					Compensate_Out	
				,c.Amount_Pay	
				,c.Amount_Dead	
				,(c.PaySS_Total - ISNULL(b.CoverAmount,0))	Pay_Total 	
				,c.ClaimAdmitType
				,c.HospitalId
				,c.HospitalName		
				,c.ICD10_1Code		
				,c.ICD10				
				,c.Remark
				,c.DateIn										
				,c.DateOut	
				,c.ClaimType	
				,g.BillingRequestGroupCode
				,b.BillingRequestItemCode
				,''							DocumentLink	
				,@pInsuranceCompanyId	
				,@InsuranceCompanyName
				,c.StartCoverDate
				,c.IPDCount
				,c.ICUCount
				,g.ClaimHeaderGroupTypeId
				,c.ProductId
				,c.[Product]
				,@CreatedByUserId
				,@D2
				,bb.BillingBankId
				,bb.BankAccountNumber
			FROM dbo.BillingRequestItem AS b	
				LEFT JOIN dbo.ClaimHeaderGroupImportDetail AS c	
					ON b.ClaimHeaderGroupImportDetailId = c.ClaimHeaderGroupImportDetailId
				LEFT JOIN dbo.BillingRequestGroup AS g	
					ON b.BillingRequestGroupId = g.BillingRequestGroupId
				LEFT JOIN dbo.BillingRequestResultDetail rrd 
					ON c.ClaimHeaderGroupImportDetailId = rrd.ClaimHeaderGroupImportDetailId
				LEFT JOIN dbo.ClaimHeaderGroupImport i	
					ON c.ClaimHeaderGroupImportId = i.ClaimHeaderGroupImportId
				LEFT JOIN [DataCenterV1].[Address].[Branch] br
					ON C.CreatedByBranchId = br.Branch_ID
				LEFT JOIN dbo.BillingBank bb
					ON i.ClaimTypeCode = bb.ClaimTypeCode	
			WHERE c.IsActive = 1
				AND i.IsActive = 1
				AND (g.BillingRequestGroupId = @BillingRequestGroupId);
				 
			/* Insert ClaimHeaderGroupImportCancel */
			INSERT INTO [dbo].[ClaimHeaderGroupImportCancel]
			      ([ClaimHeaderGroupImportId]
			      ,[CancelDetail]
			      ,[IsActive]
			      ,[CreatedByUserId]
			      ,[CreatedDate])
			SELECT 
				i.ClaimHeaderGroupImportId	ClaimHeaderGroupImportId
				,@TransactionDetail			CancelDetail
				,1							IsActive
				,@UserId					CreatedByUserId
				,@D2						CreatedDate
			FROM #Tmplst i;

 /* Move to next batch */
		SET @Offset = @Offset + @BatchSize;

	END
		
		SET @IsResult	= 1;
		SET @Msg		= 'บันทึก สำเร็จ';
	
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
	
		SET @IsResult	= 0;
		SET @Msg		= 'บันทึก ไม่สำเร็จ';
	
		IF @@Trancount > 0 ROLLBACK;
	END CATCH
	-----------------------------------
END;

RESULT:

IF OBJECT_ID('tempdb..#TmpX') IS NOT NULL  DROP TABLE #TmpX;	
IF OBJECT_ID('tempdb..#TmpDetail') IS NOT NULL  DROP TABLE #TmpDetail;	
IF OBJECT_ID('tempdb..#TmpCover') IS NOT NULL  DROP TABLE #TmpCover;	
IF OBJECT_ID('tempdb..#Tmplst') IS NOT NULL  DROP TABLE #Tmplst;
IF OBJECT_ID('tempdb..#TmpDt_') IS NOT NULL  DROP TABLE #TmpDt_;
IF OBJECT_ID('tempdb..#TmpX2') IS NOT NULL  DROP TABLE #TmpX2;
IF OBJECT_ID('tempdb..#TmpDt_Group') IS NOT NULL  DROP TABLE #TmpDt_Group;


IF (@IsResult = 1) 
	BEGIN	
		SET @Result = 'Success';
	END	
ELSE
	BEGIN
		SET @Result = 'Failure';
	END;	

SELECT @IsResult IsResult
		,@Result Result
		,@Msg	 Msg;

END;


