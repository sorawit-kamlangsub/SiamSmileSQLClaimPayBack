USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_Report_ClaimPayBackFinancialTransaction_Select]    Script Date: 14/10/2568 14:42:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		06588 Krekpon Dokkamklang Mind
-- Create date: 2024-06-20
-- Description:	เอาไว้ใช้แยกประเภทของเคลม รายงานส่งการเงิน
-- Update date: 2025-05-15 Wetpisit.P
-- Description:	เพิ่ม Model AdmitDate
-- =============================================

ALTER PROCEDURE [dbo].[usp_Report_ClaimPayBackFinancialTransaction_Select]
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
	--			@DATETimes AS CreatedDate,
	--			@Value AS ApprovedUser ,
	--			@Value AS CteatedUser ,
	--			@Value AS ClaimAdmitType,
	--			@DATETimes AS RecordedDate
    -- Insert statements for procedure here
	IF @ClaimGroupTypeId <> 5 -- เอาข้อมูลที่ไม่ใช่เคลมโอนแยก
		BEGIN

		   EXECUTE [dbo].[usp_ClaimPayBackReportNonClaimCompensate_Select]
			  @DateFrom
			  ,@DateTo
			  ,@InsuranceId
			  ,@ProductGroupId
			  ,@ClaimGroupTypeId

		END
	ELSE
		BEGIN
		    
			 EXECUTE [dbo].[usp_ClaimPayBackReportCompensate_Select]
				@DateFrom
				,@DateTo
				,@InsuranceId
				,@ProductGroupId
				,@ClaimGroupTypeId

		END
END
