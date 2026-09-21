USE [ClaimPayBack]
GO
/* Id 7801 Amount 5901.00 */
DECLARE @ClaimPayBackId 		INT = 7801
	,@Remark					NVARCHAR(250) = 'แก้ไข ตรวจสอบเอกสาร (incident :T690900000813)'
	,@CreatedByUserId			INT = 1;
	
	DECLARE @IsResult		BIT			  = 1
	DECLARE @Result			VARCHAR(100)  = ''
	DECLARE @Msg			NVARCHAR(255) = ''	
	
	DECLARE @D				DATETIME = GETDATE();
	DECLARE @l_ClaimPayBackDetailId INT
	DECLARE @ClaimPayBackStatusId	INT  = 2	--รอดำเนินการ
    DECLARE @l_Amount				DECIMAL(16,2)
	DECLARE @l_ClaimPayBackId		INT 
	
	DECLARE @tmp_D TABLE
	(
	 ClaimPayBackDetailId INT
	 ,Amount DECIMAL(16,2)
	 ,ClaimPayBackId INT
	)

	INSERT INTO @tmp_D
	SELECT   d.ClaimPayBackDetailId
			,ISNULL(d.Amount,0)			Amount
			,back.ClaimPayBackId		ClaimPayBackId
	 FROM dbo.ClaimPayBackDetail  d
		INNER JOIN dbo.ClaimPayBack back
			ON d.ClaimPayBackId  = back.ClaimPayBackId
	WHERE (d.ClaimPayBackId = @ClaimPayBackId  )
	AND  (back.ClaimPayBackStatusId =  @ClaimPayBackStatusId  )
	AND (d.IsActive = 1	)

	--Kittisak.Ph 2024-04-25---------------------
	DECLARE @tmp_ClaimPayBackXClaim TABLE
	(ClaimPayBackXClaimId int, 
	ClaimCode NVARCHAR(50)
	)
   
   INSERT INTO @tmp_ClaimPayBackXClaim
   SELECT ClaimPayBackXClaimId,ClaimCode 
   FROM dbo.ClaimPayBackXClaim x
   INNER JOIN @tmp_D t
	ON x.ClaimPayBackDetailId = t.ClaimPayBackDetailId
	---------------------------------------------
	
  IF(@IsResult = 1)
  BEGIN
	 BEGIN TRY
		BEGIN TRANSACTION

						SELECT 
						b.Amount			, IIF( (ISNULL(b.Amount,0) - SUM(t.Amount)) < 0 , 0 , (ISNULL(b.Amount,0) - SUM(t.Amount)) )
						,b.UpdatedByUserId	, @CreatedByUserId
						,b.UpdatedDate		, @D
						--UPDATE dbo.ClaimPayBack 
						--	SET  Amount = IIF( (ISNULL(b.Amount,0) - SUM(t.Amount)) < 0 , 0 , (ISNULL(b.Amount,0) - SUM(t.Amount)) )
						--		,UpdatedByUserId = @CreatedByUserId
						--		,UpdatedDate	 = @D
						FROM dbo.ClaimPayBack b
						INNER JOIN @tmp_D t
							ON b.ClaimPayBackId = t.ClaimPayBackId
						GROUP BY b.Amount,b.UpdatedByUserId,b.UpdatedDate
					
						SELECT
						d.ClaimPayBackDetailId
						,d.IsActive			, 0
						,d.UpdatedDate 		,@D	
						,d.UpdatedByUserId 	,@CreatedByUserId
						,d.CancelRemark 	,@Remark
						--UPDATE dbo.ClaimPayBackDetail
						--   SET   IsActive = 0
						--		,UpdatedDate =  @D	
						--		,UpdatedByUserId = @CreatedByUserId
						--		,CancelRemark =  @Remark
						FROM dbo.ClaimPayBackDetail d
						INNER JOIN @tmp_D t
							ON d.ClaimPayBackDetailId = t.ClaimPayBackDetailId

						SELECT
						x.ClaimPayBackXClaimId	,x.ClaimPayBackDetailId, x.ClaimCode
						,x.IsActive			, 0
						,x.UpdatedByUserId	, @CreatedByUserId
						,x.UpdatedDate		, @D						
						--UPDATE dbo.ClaimPayBackXClaim
						--   SET   IsActive = 0
						--		,UpdatedByUserId = @CreatedByUserId
						--		,UpdatedDate  = @D
						FROM dbo.ClaimPayBackXClaim x
						INNER JOIN @tmp_D t
							ON x.ClaimPayBackDetailId = t.ClaimPayBackDetailId


						 SELECT
						  b.IsActive		, 0
						 ,b.UpdatedByUserId	, @CreatedByUserId
						 ,b.UpdatedDate		, @D						 
						 --UPDATE dbo.ClaimPayBack 
						 --SET	 IsActive = 0
							--	,UpdatedByUserId = @CreatedByUserId
							--	,UpdatedDate = @D
						FROM dbo.ClaimPayBack   b
						WHERE b.ClaimPayBackId = @ClaimPayBackId
						AND NOT EXISTS (SELECT pb.ClaimPayBackDetailId , pb.ClaimPayBackId
											 FROM dbo.ClaimPayBackDetail pb 
												WHERE b.ClaimPayBackId = pb.ClaimPayBackId 
													AND pb.IsActive = 1)
						 AND (b.IsActive = 1 )

						----Kittisak.Ph 2024-04-25---------------------
						SELECT
						wDrawal.IsActive	, 0
						--UPDATE wDrawal
						--SET wDrawal.IsActive=0
						FROM [ClaimOnlineV2].[dbo].[ClaimWithdrawal] wDrawal
						INNER JOIN @tmp_ClaimPayBackXClaim xClaim ON xClaim.ClaimPayBackXClaimId = wDrawal.ClaimPayBackXClaimId AND xClaim.ClaimCode = wDrawal.ClaimCode
						---------------------------------------------

		     	SET @IsResult = 1
				SET @Msg = 'บันทึก สำเร็จ' 
		COMMIT TRANSACTION
	
	END TRY
    BEGIN CATCH 
	  IF @@TRANCOUNT > 0 ROLLBACK
		SET @IsResult =0
		SET @Msg =	'บันทึก ไม่สำเร็จ'
	END CATCH
  END 

IF @IsResult = 1 BEGIN	SET @Result =  'Success' END	
ELSE BEGIN				SET @Result = 'Failure' END	

SELECT  @IsResult IsResult
		,@Result Result
		,@Msg	 Msg