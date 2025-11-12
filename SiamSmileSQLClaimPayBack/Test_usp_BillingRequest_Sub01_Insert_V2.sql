USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequest_Sub01_Insert_V2]    Script Date: 10/10/2568 10:12:30 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
-- =============================================
-- Author:		Thayart Churlek
-- Create date: 2025-09-19 15:21
/* Updated date: Original From usp_BillingRequest_Sub01_Insert
				Add Parameter NewBillingDate
				Add Field @SftpId
				Add Check SFTP For Loop 
				Add WHILE LOOP
				Change BillingDate to NewBillingDate
	Update date: 2025-09-25 11:14
				เพิ่มการ insert ลง ClaimHeaderGroupImportCancel เพื่อลงประวัติการทำรายการ
*/	
-- Description:	<Description,,>
-- =============================================
--ALTER PROCEDURE [dbo].[usp_BillingRequest_Sub01_Insert_V2]
DECLARE
		@GroupTypeId				INT				= 2
		,@ClaimTypeCode				VARCHAR(20)		= '2000'
		,@InsuranceCompanyId		INT				= 389190
		,@CreatedByUserId			INT				= 6772
		,@BillingDate				DATE			= '2025-11-15'
		,@ClaimHeaderGroupTypeId	INT				= 3
		,@InsuranceCompanyName		NVARCHAR(300)	= 'บริษัท เออร์โกประกันภัย (ประเทศไทย) จำกัด (มหาชน)'
		,@NewBillingDate			DATE			= '2025-11-15'
		,@CreatedDateFrom			DATE			= '2025-11-12'
		,@CreatedDateTo				DATE			= '2025-11-12'
		;

--AS
--BEGIN
--	SET NOCOUNT ON;

--@GroupTypeId
--1 SSS + โอนแยก + PA30
--2 SSSPA
DECLARE @pGroupTypeId				INT				= @GroupTypeId;
DECLARE @pInsuranceCompanyId		INT				= @InsuranceCompanyId;
DECLARE @UserId						INT				= @CreatedByUserId;

DECLARE @D2							DATETIME2		= SYSDATETIME();

DECLARE @Date						DATE = @D2;

DECLARE @IsResult					BIT				= 1;
DECLARE @Result						VARCHAR(100)	= '';
DECLARE @Msg						NVARCHAR(500)	= '';

DECLARE	@BillindDueDate				DATE;
DECLARE @DaysToAdd					INT				= 15;
DECLARE @TransactionDetail			NVARCHAR(500)	= N'Generate Group เสร็จสิ้น';
DECLARE @SpecialInsuranceCompany	INT				= 389190;

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
		,ROW_NUMBER() OVER(ORDER BY ClaimHeaderGroupImportId ASC) rwId
	INTO #Tmplst
	FROM dbo.ClaimHeaderGroupImport i
		INNER JOIN dbo.ClaimHeaderGroupImportFile f
			ON i.ClaimGroupImportFileId = f.ClaimHeaderGroupImportFileId
	WHERE f.IsActive = 1
	AND i.IsActive = 1
	AND i.ClaimHeaderGroupImportStatusId = 2
	AND i.BillingRequestGroupId IS NULL
	AND i.InsuranceCompanyId = @pInsuranceCompanyId
	--AND (i.ClaimTypeCode = @ClaimTypeCode OR @ClaimTypeCode IS NULL)
	AND i.ClaimTypeCode = @ClaimTypeCode
	AND	i.CreatedDate >	@CreatedDateFrom
	AND	i.CreatedDate <=  @CreatedDateTo
	AND f.ClaimHeaderGroupTypeId = @ClaimHeaderGroupTypeId
	AND 
	(
		(
			--@pGroupTypeId = 1 AND f.ClaimHeaderGroupTypeId IN (2,4,5,6)
			@pGroupTypeId = 1 AND f.ClaimHeaderGroupTypeId IN (2,4,5)
		)
		OR	
		(
			@pGroupTypeId = 2 AND f.ClaimHeaderGroupTypeId IN (3)
		)
	);

/*SetUp TmpX*/
	SELECT	
		d.ClaimHeaderGroupImportDetailId
		,d.ClaimHeaderGroupImportId
		,d.ClaimCode
		,d.PaySS_Total
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

/*SetUp TmpDetail*/
	SELECT	
		d.ClaimHeaderGroupImportDetailId
		,d.ClaimHeaderGroupImportId
		,d.ClaimCode
		,d.PaySS_Total							 PaySS_Total
		,ISNULL(c.SumCover,0)					 SumCover
		,(d.PaySS_Total - ISNULL(c.SumCover,0))  TotalAmount
		,ROW_NUMBER() OVER(ORDER BY (ClaimHeaderGroupImportDetailId) ASC) rwId
	INTO #TmpDetail
	FROM #TmpX d
		LEFT JOIN 
		(
			SELECT ClaimCode
					,SUM(CoverAmount)	 SumCover
			FROM #TmpCover 
			GROUP BY ClaimCode
		) c
			ON d.ClaimCode = c.ClaimCode;

IF (@IsResult = 1)
BEGIN

	DECLARE @Code_G	VARCHAR(20);
	DECLARE @Code_D	VARCHAR(20);
	
	DECLARE @Last2numbersOfInsurance VARCHAR(2);
	DECLARE @ClaimHeaderGroupCodeIndex3 VARCHAR(1);
	DECLARE @ClaimType VARCHAR(1);
	DECLARE @InsuranceCompanyCode VARCHAR(30);
	DECLARE @SftpId INT = NULL;

	SELECT 
		@InsuranceCompanyCode = o.OrganizeCode 
		,@SftpId = c.SFTPConfigId
	FROM DataCenterV1.Organize.Organize o
		LEFT JOIN dbo.SFTPConfig c
			ON o.OrganizeCode = c.InsuranceCompanyCode
        AND c.IsActive = 1
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

	IF (@GroupTypeId = 1)
		BEGIN
			SET @Code_G = CONCAT('BQGPH', @Last2numbersOfInsurance, @ClaimType)
			SET @Code_D = 'BQIPH'
		END
	ELSE IF @GroupTypeId = 2
		BEGIN
			SET @Code_G = CONCAT('BQGPA', @Last2numbersOfInsurance, @ClaimType)
			SET @Code_D = 'BQIPA'
		END 
	ELSE
		BEGIN
			SET @Code_G = CONCAT('BQGPH', @Last2numbersOfInsurance, @ClaimType)
			SET @Code_D = 'BQIPH'
		END;
	
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
	IF @SftpId IS NULL
	BEGIN 
		SET @TotalRows = @D_Total;
		SET @BatchSize = 2;
	END

/* Check Ergo */
	IF @InsuranceCompanyId = @SpecialInsuranceCompany AND @ClaimHeaderGroupTypeId IN (3,5)
	BEGIN 
		SET @TotalRows = @D_Total;
		SET @BatchSize = 2;
	END
	ELSE IF @InsuranceCompanyId = @SpecialInsuranceCompany AND @ClaimHeaderGroupTypeId NOT IN (3,5)
	BEGIN 
		SET @TotalRows = 1;
		SET @BatchSize = @D_Total;
	END
	
/* Generate Code */
		EXECUTE dbo.usp_GenerateCode_FromTo 
				 @D_TT
				,@D_Total
				,@D_YY OUTPUT
				,@D_MM OUTPUT
				,@D_RunningFrom OUTPUT
				,@D_RunningTo OUTPUT

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
			--INSERT INTO dbo.BillingRequestGroup
			--        (BillingRequestGroupCode
			--        ,InsuranceCompanyId
			--        ,ItemCount
			--        ,PaySS_Total
			--        ,CoverAmount
			--        ,TotalAmount
			--        ,BillingRequestGroupStatusId
			--        ,BillingDate
			--        ,IsActive
			--        ,CreatedDate
			--        ,CreatedByUserId
			--        ,UpdatedDate
			--        ,UpdatedByUserId
			--		,ClaimTypeCode
			--		,BillingDueDate
			--		,ClaimHeaderGroupTypeId
			--		,InsuranceCompanyName)
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
			--INSERT INTO dbo.BillingRequestItem
			--        (BillingRequestItemCode
			--        ,BillingRequestGroupId
			--        ,ClaimHeaderGroupImportDetailId
			--        ,PaySS_Total
			--        ,CoverAmount
			--        ,AmountTotal
			--        ,IsActive
			--        ,CreatedDate
			--        ,CreatedByUserId
			--        ,UpdatedDate
			--        ,UpdatedByUserId)
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
			SELECT *
			--UPDATE	m 
			--	SET m.ClaimHeaderGroupImportStatusId	= 3
				--,m.BillingRequestGroupId				= @BillingRequestGroupId
				--,m.UpdatedDate						= @D2
				--,m.UpdatedByUserId					= @UserId
				--,m.BillingDate						= @NewBillingDate
			FROM dbo.ClaimHeaderGroupImport m
				INNER JOIN #Tmplst u
					ON m.ClaimHeaderGroupImportId = u.ClaimHeaderGroupImportId
			WHERE u.rwId > @Offset 
				AND u.rwId <= @Offset + @BatchSize ;
				
/* Insert BillingRequestGroupXResultDetail */
			--INSERT INTO dbo.BillingRequestGroupXResultDetail
			--		(BillingRequestGroupId
			--		,BillingRequestResultDetailId)
			SELECT	
				@BillingRequestGroupId			BillingRequestGroupId
				,i.BillingRequestResultDetailId
			FROM #TmpCover i;

/* Insert BillingExport */
			--INSERT INTO ClaimPayBack.dbo.BillingExport
			--		(BillingDate
			--		,BillingDueDate
			--		,BranchCode
			--		,Branch
			--		,ClaimHeaderGroupCode
			--		,PolicyNo
			--		,ApplicationCode
			--		,ClaimCode
			--		,Province
			--		,SchoolName
			--		,CustomerDetailCode
			--		,IdentityCard
			--		,CustName
			--		,SchoolLevel
			--		,DateHappen
			--		,Accident
			--		,ChiefComplain
			--		,Orgen
			--		,Pay
			--		,Compensate_Include
			--		,Compensate_Out
			--		,Amount_Pay
			--		,Amount_Dead
			--		,Pay_Total
			--		,ClaimAdmitType
			--		,HospitalId
			--		,HospitalName
			--		,ICD10_1Code
			--		,ICD10
			--		,Remark
			--		,DateIn
			--		,DateOut
			--		,ClaimType
			--		,BillingRequestGroupCode
			--		,BillingRequestItemCode
			--		,DocumentLink
			--		,InsuranceCompanyId
			--		,InsuranceCompanyName
			--		,StartCoverDate
			--		,IPDCount
			--		,ICUCount
			--		,ClaimHeaderGroupTypeId
			--		,ProductId
			--		,[Product]
			--		,CreatedByUserId
			--		,CreatedDate
			--		,BillingBankId
			--		,BankAccountNumber)
			SELECT 
				@NewBillingDate
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
			--INSERT INTO [dbo].[ClaimHeaderGroupImportCancel]
			--      ([ClaimHeaderGroupImportId]
			--      ,[CancelDetail]
			--      ,[IsActive]
			--      ,[CreatedByUserId]
			--      ,[CreatedDate])
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

--END