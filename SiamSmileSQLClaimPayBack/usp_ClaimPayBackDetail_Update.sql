USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [Claim].[usp_ClaimPayBackDetail_Update]    Script Date: 9/21/2026 10:19:21 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		supattra
-- Create date: 2021-10-06
-- Update date: 2024-04-25 Kittisak.ph Add New Update [ClaimOnlineV2].[dbo].[ClaimWithdrawal].IsActive
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [Claim].[usp_ClaimPayBackDetail_Update]
 	 @ClaimPayBackDetailId 		INT 
	,@Remark					NVARCHAR(250)
	,@CreatedByUserId			INT
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @IsResult		BIT			  = 1
	DECLARE @Result			VARCHAR(100)  = ''
	DECLARE @Msg			NVARCHAR(255) = ''
	DECLARE @D				DATETIME = GETDATE();
	DECLARE @l_ClaimPayBackDetailId INT
	DECLARE @ClaimPayBackStatusId	INT  = 2	--รอดำเนินการ
    DECLARE @l_Amount				DECIMAL(16,2)
	DECLARE @l_ClaimPayBackId		INT 


	SELECT   @l_ClaimPayBackDetailId = d.ClaimPayBackDetailId
			,@l_Amount = ISNULL(d.Amount,0)
			,@l_ClaimPayBackId = back.ClaimPayBackId
	 FROM dbo.ClaimPayBackDetail  d
		INNER JOIN dbo.ClaimPayBack back
			ON d.ClaimPayBackId  = back.ClaimPayBackId
	WHERE (d.ClaimPayBackDetailId = @ClaimPayBackDetailId  )
	AND  (back.ClaimPayBackStatusId =  @ClaimPayBackStatusId  )
	AND (d.IsActive = 1	)

	--Kittisak.Ph 2024-04-25---------------------
	DECLARE @tmp_ClaimPayBackXClaim TABLE
	(ClaimPayBackXClaimId int, 
	ClaimCode NVARCHAR(50)
	)
   
   INSERT INTO @tmp_ClaimPayBackXClaim
   SELECT ClaimPayBackXClaimId,ClaimCode 
   FROM dbo.ClaimPayBackXClaim
   WHERE ClaimPayBackDetailId = @ClaimPayBackDetailId
	---------------------------------------------

 IF(@IsResult = 1)
  BEGIN
	IF(@l_ClaimPayBackDetailId IS NULL)
	BEGIN
	   SET @IsResult =0;
	   SET @Msg ='Data  not found'
END	END
	
  IF(@IsResult = 1)
  BEGIN
	 BEGIN TRY
		BEGIN TRANSACTION

						UPDATE dbo.ClaimPayBack 
							SET  Amount = IIF( (ISNULL(Amount,0) - @l_Amount) < 0 , 0 , (ISNULL(Amount,0) - @l_Amount) )
								,UpdatedByUserId = @CreatedByUserId
								,UpdatedDate	 = @D
						FROM dbo.ClaimPayBack 
						WHERE ClaimPayBackId  = @l_ClaimPayBackId 
					
						UPDATE dbo.ClaimPayBackDetail
						   SET   IsActive = 0
								,UpdatedDate =  @D	
								,UpdatedByUserId = @CreatedByUserId
								,CancelRemark =  @Remark
						FROM dbo.ClaimPayBackDetail
						WHERE ClaimPayBackDetailId = @l_ClaimPayBackDetailId

						UPDATE dbo.ClaimPayBackXClaim
						   SET   IsActive = 0
								,UpdatedByUserId = @CreatedByUserId
								,UpdatedDate  = @D
						FROM dbo.ClaimPayBackXClaim
						WHERE ClaimPayBackDetailId = @l_ClaimPayBackDetailId


						 UPDATE dbo.ClaimPayBack 
						 SET	 IsActive = 0
								,UpdatedByUserId = @CreatedByUserId
								,UpdatedDate = @D
						FROM dbo.ClaimPayBack   b
						WHERE NOT EXISTS (SELECT pb.ClaimPayBackDetailId , pb.ClaimPayBackId
											 FROM dbo.ClaimPayBackDetail pb 
												WHERE b.ClaimPayBackId = pb.ClaimPayBackId 
													AND pb.IsActive = 1)
						 AND (b.IsActive = 1 )

						----Kittisak.Ph 2024-04-25---------------------
						UPDATE wDrawal
						SET wDrawal.IsActive=0
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
END
