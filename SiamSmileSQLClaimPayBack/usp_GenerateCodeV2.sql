USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_GenerateCodeV2]    Script Date: 8/1/2569 8:51:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Bunchuai Chaiket
-- Create date:	2026-01-06 12:00
-- Description:	Function สำหรับ Run เลขที่ BQG บริษัทประกันที่ไม่มี SFTP เพื่อแก้ปัญหาจำนวนเลข Run ไม่เพียงพอของแต่ละเดือน
-- =============================================
ALTER PROCEDURE [dbo].[usp_GenerateCodeV2]
	-- Add the parameters for the stored procedure here
	@TransactionCodeControlTypeDetail	VARCHAR(8)
	,@RunningLenght						INT
	,@Result							VARCHAR(20) OUTPUT
AS

BEGIN
	SET NOCOUNT ON;

	Declare @CurrentDate	Date
	Declare @YearText		Varchar(2)
	Declare @MonthText		Varchar(2)
	Declare @CodeText		Varchar(10)
	Declare @RunningString	Varchar(10)
--	Declare @RunningLenght	INT
--	Declare @Result			varchar(20)
	
	----Set Running Lenght----------------------
--	SET @RunningLenght = 8 -- 8 หน่วย Running
	--------------------------------------------

	--SET CurrentDate
	SET @CurrentDate = GETDATE();

	--SET Year Text
	SET @YearText = RIGHT(Convert(Varchar(4),(Year(@CurrentDate)+543)),2);

	--Set Month
	SET @MonthText = dbo.func_ConvertIntToString(Month(@CurrentDate),2);

	IF @TransactionCodeControlTypeDetail IS NULL 
		OR @TransactionCodeControlTypeDetail = '' 
		BEGIN
			SET @TransactionCodeControlTypeDetail = 'XXX';
		END	



	DECLARE @TrCodeControlTypeID	INT = (	SELECT	TOP(1)TransactionCodeControlType_ID
											FROM	dbo.TransactionCodeControlType 
	 										WHERE	TransactionCodeControlTypeDetail = @TransactionCodeControlTypeDetail);
								
							
	IF @TrCodeControlTypeID IS NULL
		BEGIN
			--Insert
			INSERT INTO dbo.TransactionCodeControlType(TransactionCodeControlTypeDetail)
			SELECT		@TransactionCodeControlTypeDetail
						
			SET @TrCodeControlTypeID = SCOPE_IDENTITY();
		END

	DECLARE @TrCCId	INT = (	SELECT	TransactionCodeControl_ID
							FROM	dbo.TransactionCodeControl
							WHERE	(TransactionCodeControlType_ID = @TrCodeControlTypeID) 
							AND		(Year = @YearText)
							AND		(Month = @MonthText));


	DECLARE @Tmp TABLE (nextId	INT)

	IF @TrCCId IS NULL
		BEGIN
 			INSERT INTO dbo.TransactionCodeControl WITH(TABLOCKX)
			( TransactionCodeControlType_ID,TransactionCode,Year,Month,Running)
			OUTPUT Inserted.Running INTO @Tmp
			SELECT	@TrCodeControlTypeID,@TransactionCodeControlTypeDetail,@YearText,@MonthText,1;   

		END	
	ELSE
		BEGIN
				
			UPDATE dbo.TransactionCodeControl WITH(TABLOCKX)
			SET Running = Running + 1
			OUTPUT Inserted.Running INTO @Tmp
			FROM dbo.TransactionCodeControl
			WHERE TransactionCodeControl_ID = @TrCCId;
		END	
	

	DECLARE @Running INT = (SELECT MAX(nextId) FROM @Tmp);

	SET @Result = CONCAT(@TransactionCodeControlTypeDetail,@YearText,dbo.func_ConvertIntToString(@Running,@RunningLenght))
END;




