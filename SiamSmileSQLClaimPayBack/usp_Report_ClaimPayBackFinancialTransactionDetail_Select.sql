USE [ClaimPayBack]
GO
/****** Object:  StoredProcedure [dbo].[usp_Report_ClaimPayBackFinancialTransactionDetail_Select]    Script Date: 24/12/2568 11:11:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		06588 Krekpon Dokkamklang Mind
-- Create date: 2024-06-24
-- Description:	รายงาน CL
-- Updated date: ปรับ Code ให้ทำการ Query ได้ไวเขึ้น 06588 Krekpon D. Mind
-- =============================================
ALTER PROCEDURE [dbo].[usp_Report_ClaimPayBackFinancialTransactionDetail_Select]
	-- Add the parameters for the stored procedure here
	 @DateFrom			DATE, 
	 @DateTo			DATE,
	 @InsuranceId		INT = NULL,
	 @ProductGroupId	INT = NULL,
	 @ClaimGroupTypeId	INT
AS
BEGIN -- ปรับ Code ใหม่จากก่อนหน้า

	 SELECT cpbdReports.HospitalName AS Hospital,
			cpbdReports.ClaimGroupCode AS ClaimGroupCode,
			cpbdReports.ClaimCode AS ClaimNo,
			cpbdReports.CustomerName AS CustomerName,
			cpbdReports.Amount AS Amount,
			cpbdReports.SendDate AS SendDate,
			cpbdReports.PaymentDate AS CreatedDate
			
	 FROM ClaimPayBackDetailReport cpbdReports
	 WHERE cpbdReports.ClaimGroupTypeId = @ClaimGroupTypeId  -- ตอนนี้รับเฉพาะที่เป็นเคลมโรงพยาบาล 2024-06-24
	 AND cpbdReports.IsActive = 1
	 AND ((cpbdReports.SendDate >= @DateFrom) AND (cpbdReports.SendDate <= @DateTo))

END
