USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_BillingRequestResultManual_Insert]    Script Date: 21/1/2569 14:51:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Siriphong Narkphung
-- Create date: 2022-12-14
-- UpdatedDate: /*20230901 1212 bell เพิ่มเงื่อนไข validate*/
-- UpdatedDate: /*20230913 1708 bell เพิ่มเงื่อนไข validate ไม่ให้เกินยอด*/
-- UpdatedDate: /*20230920 1543 Chanadol เพิ่ม type*/
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[usp_BillingRequestResultManual_Insert]
 
	@ClaimHeaderGroupImportDetailId	INT
	,@CoverAmount					DECIMAL (16,2)
	,@IsCheckManual					INT
	,@CreatedByUserId				INT 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @D				DATETIME2 = SYSDATETIME();
	DECLARE @UnCover		DECIMAL(16,2) = 0
	DECLARE @Chk			VARCHAR(20);
	DECLARE @IsResult		BIT             = 1;	
	DECLARE @Result			VARCHAR(100) = '';	
	DECLARE @Msg			NVARCHAR(500)= '';
	DECLARE @chkBilling		INT; 
	DECLARE @IsManual		BIT;
	DECLARE @IsManualNPL	BIT = 0;  --Update 2023-09-20 chanadol
	DECLARE @IsUpdate		BIT = 0;
	DECLARE @Count			INT;
	DECLARE @BillingRequestResultDetailId	INT;
	DECLARE @ChkCoverAmount	DECIMAL (16,2);
	-------------------------------------------------------------------
	DECLARE @BillingRequestResultHeaderId	INT;
	DECLARE @Code							VARCHAR(20)		= 'BQGR';
	DECLARE @RunningLenght					INT				= 6;	
	DECLARE @BillingRequestResultHeaderCode VARCHAR(20);
	-------------------------------------------------------------------
	
	IF(@IsResult = 1)
		BEGIN
			IF (@ClaimHeaderGroupImportDetailId IS NULL OR @CreatedByUserId IS NULL OR @CoverAmount IS NULL)
				BEGIN
					SET @IsResult = 0;
					SET @Msg = N'กรุณากรอกข้อมูลให้ครบถ้วน';
				END
		END
	
	IF @IsCheckManual = 1 SET @IsManualNPL = 0
	IF @IsCheckManual = 2 SET @IsManualNPL = 1 --Update 2023-09-20 chanadol

	DECLARE @ClaimCode				VARCHAR(20);
	DECLARE @BillingRequestGroupId	INT;

	SELECT @ClaimCode = d.ClaimCode
			,@BillingRequestGroupId = g.BillingRequestGroupId
	FROM dbo.ClaimHeaderGroupImportDetail d
		LEFT JOIN ClaimHeaderGroupImport h
			ON d.ClaimHeaderGroupImportId = h.ClaimHeaderGroupImportId
		LEFT JOIN 
			(
				SELECT * 
				FROM dbo.BillingRequestGroup 
				WHERE IsActive = 1
			)g
			ON h.BillingRequestGroupId = g.BillingRequestGroupId
	WHERE d.ClaimHeaderGroupImportDetailId = @ClaimHeaderGroupImportDetailId
	AND d.IsActive = 1
	AND h.IsActive = 1;

	
	--SELECT @Chk = cgid.ClaimCode 
	--FROM dbo.ClaimHeaderGroupImportDetail cgid
	--	LEFT JOIN dbo.ClaimHeaderGroupImport cgi
	--		ON cgid.ClaimHeaderGroupImportId = cgi.ClaimHeaderGroupImportId
	--WHERE cgi.IsActive = 1
	--AND cgid.ClaimCode = @ClaimCode
	--AND cgi.BillingRequestGroupId IS NULL;
	
	IF(@IsResult = 1)
		BEGIN
			IF @ClaimCode IS NULL
				BEGIN
					SET @IsResult = 0;
					SET @Msg = N'ยังไม่มีรายการ Claim Import';
				END
			ELSE IF (@BillingRequestGroupId IS NOT NULL)
				BEGIN
					SET @IsResult = 0;
					SET @Msg = N'มีการ BillingRequestGroup แล้ว';
				END
		END;
	---------------------------------------------------------------------------
	SELECT @chkBilling = d.BillingRequestResultDetailId
		,@IsManual = h.IsManual
		,@ChkCoverAmount = d.CoverAmount
	FROM dbo.BillingRequestResultDetail d
		LEFT JOIN dbo.BillingRequestResultHeader h
			ON d.BillingRequestResultHeaderId = h.BillingRequestResultHeaderId
	WHERE d.ClaimHeaderGroupImportDetailId = @ClaimHeaderGroupImportDetailId;
	---------------------------------------------------------------------------
	SELECT @Count = COUNT(x.Id)
	FROM dbo.BillingRequestGroupXResultDetail x
		INNER JOIN dbo.BillingRequestGroup g
			ON x.BillingRequestGroupId = g.BillingRequestGroupId
	WHERE x.BillingRequestResultDetailId = @chkBilling
	AND g.IsActive = 1;

	IF @Count IS NULL SET @Count = 0;
	---------------------------------------------------------------------------
	IF(@IsResult = 1)
		BEGIN
			IF(@chkBilling IS NULL)--ถ้า BillingRequestResultDetailId ไม่มี ให้ Insert ข้อมูล 
				BEGIN
					SET @IsUpdate = 0;--ไม่อัพเดท
					SET @Msg = N'Insert ข้อมูล';
				END
			ELSE
				BEGIN
					IF(@IsManual = 0)--เช็คข้อมูลที่มีอยู่ถ้าเป็นการนำเข้าข้อมูลรีเคลมที่ไม่ใช่ Manual จะไม่สามารถแก้ไขข้อมูลได้
						BEGIN
							SET @IsResult = 0;
							SET @Msg = N'ห้ามแก้ไข';
						END
					ELSE 
						BEGIN
							IF (@Count > 0)--เช็คข้อมูล BillingRequestGroupXResultDetail ถ้ามีข้อมูลจะไม่สามารถ Update ได้เนื่องจากข้อมูลนี้ถูกส่งไปแล้ว
								BEGIN
									SET @IsResult = 0;
									SET @Msg = N'ห้าม Update';
								END
							ELSE 
								BEGIN
									SET @IsUpdate = 1;
									
									IF(@IsUpdate = 1)
										BEGIN
											IF(@ChkCoverAmount = @CoverAmount)
												BEGIN
													SET @IsResult = 0;
													SET @Msg = N'ข้อมูลที่แก้ไขต้องไม่ตรงกับค่าเดิม'
												END
										END
								END
						END
				
				END
		END;


--/*20230901 1212 bell เพิ่มเงื่อนไข validate*/
--IF @IsResult = 1
--	BEGIN
--		DECLARE @CountChkResult INT;

--		SELECT @CountChkResult = COUNT(ClaimHeaderGroupImportDetailId)
--		FROM dbo.BillingRequestResultDetail
--		WHERE IsActive = 1
--		AND ClaimCode = @ClaimCode
--		AND BillingRequestItemCode IS NOT NULL;

--		IF @CountChkResult IS NULL SET @CountChkResult = 0;


--		IF @CountChkResult <> 0
--			BEGIN
--				SET @IsResult = 0;
--				SET @Msg = N'รายการนี้ มีผลตอบกลับจาก ftp แล้ว'
--			END
--	END

/*20230913 1708 bell เพิ่มเงื่อนไข validate ไม่ให้เกินยอด*/
IF @IsResult = 1
	BEGIN
    
		DECLARE @a_Receive DECIMAL(16,2);
		DECLARE @a_Total DECIMAL(16,2);

	
		SELECT @a_Receive = SUM(d.CoverAmount)
		FROM dbo.BillingRequestResultDetail d
			INNER JOIN dbo.BillingRequestResultHeader h
				ON d.BillingRequestResultHeaderId = h.BillingRequestResultHeaderId
		WHERE d.claimCode = @ClaimCode
		AND d.IsActive = 1
		AND h.IsActive = 1
		AND d.ClaimHeaderGroupImportDetailId <> @ClaimHeaderGroupImportDetailId;

		SELECT @a_Total = PaySS_Total
		FROM dbo.ClaimHeaderGroupImportDetail
		WHERE ClaimHeaderGroupImportDetailId = @ClaimHeaderGroupImportDetailId

		IF @a_Receive IS NULL SET @a_Receive = 0;
		IF @a_Total IS NULL SET @a_Total = 0;

		IF @CoverAmount >= (@a_Total - @a_Receive)
			BEGIN
				SET @IsResult = 0;
				SET @Msg = N'กรุณาตรวจสอบยอดเงิน'
			END

	END


		--มีการบันทึกเข้ามาแล้วหรือยัง ?
			--ไม่มี  Insert เข้าตามปกติ
			--มี 
				--CheckHeader .IsManual ?
					-- IsManual = 0 ห้ามแก้ไข
					-- IsManual = 1
						--IsCalculate ?
							--IsCalculate = 0 Update
							--IsCalculate = 1 ห้าม Update


		IF @IsResult = 1			
			BEGIN
				IF(@IsUpdate = 0)
					BEGIN
						EXECUTE dbo.usp_GenerateCode @Code  
							,@RunningLenght	
							,@BillingRequestResultHeaderCode OUTPUT;
					END;
	
				BEGIN TRY			
					BEGIN TRANSACTION
	
					--Insert BillingRequestResultHeader--
					IF(@IsUpdate = 0)
						BEGIN
							INSERT INTO dbo.BillingRequestResultHeader
									 (
										 FileName
										 ,BillingRequestResultHeaderCode
										 ,IsActive
										 ,CreatedDate
										 ,CreatedByUserId
										 ,UpdatedDate
										 ,UpdatedByUserId
										 ,IsManual
										 ,IsManualNPL  --update 2023-09-20 chanaodl
									 )
							
							SELECT ''
								,@BillingRequestResultHeaderCode 
								,1
								,@D
								,@CreatedByUserId
								,@D
								,@CreatedByUserId
								,1
								,@IsManualNPL
							SET @BillingRequestResultHeaderId = SCOPE_IDENTITY();
	
							INSERT INTO dbo.BillingRequestResultDetail
									 (
										 BillingRequestResultHeaderId
										 ,BillingRequestItemCode
										 ,PaymentReferenceId
										 ,CoverAmount
										 ,UncoverAmount
										 ,UnCoverRemark
										 ,DecisionStatus
										 ,RejectResult
										 ,DecisionDate
										 ,EstimatePaymentDate
										 ,Remark
										 ,ClaimCode
										 ,IsActive
										 ,CreatedDate
										 ,CreatedByUserId
										 ,UpdatedDate
										 ,UpdatedByUserId
										 ,ClaimHeaderGroupImportDetailId
									 )
							SELECT @BillingRequestResultHeaderId
								,NULL
								,NULL 
								,@CoverAmount
								,@UnCover
								,''
								,NULL 
								,NULL 
								,NULL 
								,NULL 
								,''
								,@ClaimCode
								,1 
								,@D 
								,@CreatedByUserId 
								,@D 
								,@CreatedByUserId
								,@ClaimHeaderGroupImportDetailId

						SET @BillingRequestResultDetailId = SCOPE_IDENTITY();

					--Insert BillingRequestResultDetailLog
						INSERT INTO dbo.BillingRequestResultDetailLog
									 (
										 BillingRequestResultDetailId
										 ,CoverAmount
										 ,IsManualNPL
										 ,IsActive
										 ,CreatedDate
										 ,CreatedByUserId
									 )
							SELECT @BillingRequestResultDetailId
								,@CoverAmount
								,@IsManualNPL
								,1
								,@D
								,@CreatedByUserId
						END ;

					--Update BillingRequestResultHeader--
					IF(@IsUpdate = 1)
						BEGIN
							UPDATE rd
							SET rd.CoverAmount = @CoverAmount
								,rd.UpdatedDate = @D
								,rd.UpdatedByUserId = @CreatedByUserId
							FROM BillingRequestResultDetail rd
							WHERE rd.BillingRequestResultDetailId = @chkBilling;

							--update 2023-09-20 chanadol
							UPDATE h
							SET h.IsManualNPL = @IsManualNPL
							FROM dbo.BillingRequestResultDetail d
								LEFT JOIN dbo.BillingRequestResultHeader h
									ON d.BillingRequestResultHeaderId = h.BillingRequestResultHeaderId
							WHERE d.BillingRequestResultDetailId = @chkBilling;

							INSERT INTO dbo.BillingRequestResultDetailLog
									 (
										 BillingRequestResultDetailId
										 ,CoverAmount
										 ,IsManualNPL
										 ,IsActive
										 ,CreatedDate
										 ,CreatedByUserId
									 )
							SELECT BillingRequestResultDetailId
								,@CoverAmount
								,@IsManualNPL
								,1
								,@D
								,@CreatedByUserId
							FROM dbo.BillingRequestResultDetail
							WHERE ClaimHeaderGroupImportDetailId = @ClaimHeaderGroupImportDetailId;
						END;

					SET @IsResult = 1;			  					
					SET @Msg = N'บันทึก สำเร็จ';	 						
												  					
					COMMIT TRANSACTION			  					
				END TRY							  					
				BEGIN CATCH						  					
												  					
					SET @IsResult = 0;			  					
					SET @Msg = N'บันทึก ไม่สำเร็จ';						
												  					
					IF @@TRANCOUNT > 0 ROLLBACK	  					
				END CATCH											
																	
		--IF OBJECT_ID('tempdb..#Tmp') IS NOT NULL  DROP TABLE #Tmp;
																	
			END;									  					
												  					
		IF @IsResult = 1 BEGIN	SET @Result = 'Success'; END;	
		ELSE BEGIN	SET @Result = 'Failure'; END ;				
									  								
		            							  					
		       SELECT @IsResult IsResult		  					
				,@Result Result					  					
				,@Msg	 Msg 	
				,@ClaimCode
END
