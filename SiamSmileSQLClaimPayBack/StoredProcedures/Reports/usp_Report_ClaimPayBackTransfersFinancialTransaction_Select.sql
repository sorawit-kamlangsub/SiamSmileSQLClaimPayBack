USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_Report_ClaimPayBackTransfersFinancialTransaction_Select]    Script Date: 3/9/2026 9:12:45 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		06588 Krekpon Dokkamklang Mind
-- Create date: 2024-06-21
-- Description:	เอาไว้ใช้แยกประเภทของเคลม รายงานหหลังส่งการเงิน
-- =============================================
ALTER PROCEDURE [dbo].[usp_Report_ClaimPayBackTransfersFinancialTransaction_Select]
-- Add the parameters for the stored procedure here
	 @DateFrom			DATE 
	,@DateTo			DATE 
	,@InsuranceId		INT = NULL
	,@ProductGroupId	INT = NULL	
	,@ClaimGroupTypeId	INT = NULL
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--DECLARE @Value NVARCHAR(Max) = NULL
	--DECLARE @IntVal INT = NULL
	--DECLARE @DeciVal Decimal = NULL
	--DeCLARE @DATETimes DATETIME = NULL
	--SELECT @Value AS InsuranceCompany_Name,
	--			@Value AS Branch,
	--			@Value AS Hospital,
	--			@Value AS ProductGroupDetailName,
	--			@Value AS ClaimGroupType,
	--			@Value AS ClaimGroupCode,
	--			@IntVal AS ItemCount,
	--			@DeciVal AS Amount,
	--			@Value AS ClaimCompensate,
	--			@Value AS ClaimNo,
	--			@Value AS COL,
	--			@Value AS Province,
	--			@Value AS CustomerName,
	--			@Value As BankName,
	--			@Value AS BankAccountName,
	--			@Value AS BankAccountNo,
	--			@Value AS PhoneNo,
	--			@DATETimes AS SendDate,
	--			@DATETimes AS CreatedDate,
	--			@Value AS ApprovedUser ,
	--			@Value AS CteatedUser ,
	--			@Value AS ClaimAdmitType,
	--			@Value AS ClaimPaymentTypeName,
	--			@Value AS ClaimPaymentTypeDetail

     --Insert statements for procedure here

	IF @ClaimGroupTypeId <> 5 -- เอาข้อมูลที่ไม่ใช่เคลมโอนแยก
		BEGIN

		   EXECUTE [dbo].[usp_ClaimPayBackTransferNonClaimCompensateReport_Select]
			  @DateFrom
			  ,@DateTo
			  ,@InsuranceId
			  ,@ProductGroupId
			  ,@ClaimGroupTypeId

		END
	ELSE
		BEGIN
		    
			 EXECUTE [dbo].[usp_ClaimPayBackTrasferReport_Select]
				@DateFrom
				,@DateTo
				,@InsuranceId
				,@ProductGroupId
				,@ClaimGroupTypeId

		END
END
